import 'package:flutter/foundation.dart';
import 'package:streamtunes/ui/core/view_model.dart';
import 'package:streamtunes/utils/async_utils.dart';
import 'package:streamtunes/domain/models/album.dart';
import 'package:streamtunes/domain/models/app_config.dart';
import 'package:streamtunes/domain/models/song.dart';
import 'package:streamtunes/data/repositories/config/config_repository.dart';
import 'package:streamtunes/data/repositories/songs/songs_repository.dart';
import 'package:streamtunes/data/services/audio/audio_analyzer_service.dart';
import 'package:streamtunes/data/services/notifications/background_upload_service.dart';
import 'package:streamtunes/data/services/device/device_capabilities_service.dart';

class UploadViewModel extends ViewModel {
  final SongsRepository songsRepo;
  final ConfigRepository configRepo;
  final DeviceCapabilitiesService deviceService;
  final AudioAnalyzerService audioAnalyzer;
  final BackgroundUploadService notifications;

  int _songCount = 0;
  int _albumCount = 0;
  int _maxSongs = 20;
  int _maxAlbums = 2;
  List<Album> _bandAlbums = [];

  bool _isAnalyzing = false;
  bool _isUploading = false;
  AudioAnalysisResult? _analysisResult;
  AudioFileSelection? _selectedAudio;
  String? _selectedCoverPath;
  String? _errorMessage;
  String? _successMessage;

  UploadViewModel({
    required this.songsRepo,
    required this.configRepo,
    required this.deviceService,
    AudioAnalyzerService? audioAnalyzer,
    BackgroundUploadService? notifications,
  }) : _ownsAnalyzer = audioAnalyzer == null,
       audioAnalyzer = audioAnalyzer ?? AudioAnalyzerService(),
       notifications = notifications ?? BackgroundUploadService();

  /// Si el analizador lo creó este ViewModel, también lo libera.
  final bool _ownsAnalyzer;
  double _analysisProgress = 0;
  String _analysisStage = '';
  bool _cancelRequested = false;

  double get analysisProgress => _analysisProgress;
  String get analysisStage => _analysisStage;

  bool get hasCamera => deviceService.hasCamera;

  int get songCount => _songCount;
  int get albumCount => _albumCount;
  int get maxSongs => _maxSongs;
  int get maxAlbums => _maxAlbums;
  List<Album> get bandAlbums => List.unmodifiable(_bandAlbums);

  bool get isAnalyzing => _isAnalyzing;
  bool get isUploading => _isUploading;
  AudioAnalysisResult? get analysisResult => _analysisResult;
  AudioFileSelection? get selectedAudio => _selectedAudio;
  String? get selectedCoverPath => _selectedCoverPath;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  bool get hasReachedSongLimit => _songCount >= _maxSongs;
  bool get hasReachedAlbumLimit => _albumCount >= _maxAlbums;

  /// Las 4 consultas son independientes: se lanzan en paralelo y cada una
  /// tiene su valor de respaldo, así un fallo parcial no bloquea la pantalla.
  Future<void> loadBandQuota(String bandId) async {
    Future<T> orElse<T>(Future<T> future, T fallback, String what) =>
        future.withNetworkTimeout().catchError((Object e) {
          debugPrint('[UploadViewModel] Error $what: $e');
          return fallback;
        });

    final (config, songCount, albumCount, albums) = await (
      orElse(configRepo.getConfig().then<AppConfig?>((c) => c), null, 'leyendo config'),
      orElse(songsRepo.getBandSongCount(bandId), _songCount, 'contando canciones'),
      orElse(songsRepo.getBandAlbumCount(bandId), _albumCount, 'contando álbumes'),
      orElse(songsRepo.getBandAlbums(bandId), _bandAlbums, 'cargando álbumes'),
    ).wait;

    if (config != null) {
      _maxSongs = config.maxSongsPerBand;
      _maxAlbums = config.maxAlbumsPerBand;
    }
    _songCount = songCount;
    _albumCount = albumCount;
    _bandAlbums = albums;
    notifyListeners();
  }

  Future<void> pickCoverPhoto({bool fromCamera = false}) async {
    final path = await deviceService.pickCoverPhoto(fromCamera: fromCamera);
    if (path != null) {
      _selectedCoverPath = path;
      notifyListeners();
    }
  }

  /// Selecciona el archivo de audio y ejecuta el análisis pesado en Isolate.run
  Future<void> pickAndAnalyzeAudio() async {
    _errorMessage = null;
    notifyListeners();

    final audioFile = await deviceService.pickAudioFile();
    if (audioFile == null) return;

    // Validación estricta de tamaño máximo: 50 MB (52.428.800 bytes)
    const int maxBytes = 50 * 1024 * 1024;
    if (audioFile.sizeInBytes > maxBytes) {
      final mb = (audioFile.sizeInBytes / (1024 * 1024)).toStringAsFixed(1);
      _errorMessage =
          'El archivo supera los 50 MB (tamaño: $mb MB). Por favor, exporta en MP3 o M4A a 320kbps; un archivo WAV crudo de gran tamaño sobrecarga el almacenamiento y ancho de banda del colectivo under.';
      _selectedAudio = null;
      _analysisResult = null;
      notifyListeners();
      return;
    }

    _selectedAudio = audioFile;
    _isAnalyzing = true;
    notifyListeners();

    _analysisProgress = 0;
    _analysisStage = 'Preparando análisis';
    _cancelRequested = false;

    try {
      // El análisis corre en el isolate worker y emite progreso por Stream.
      AudioAnalysisResult? result;
      await for (final event in audioAnalyzer.analyzeWithProgress(
        filePath: audioFile.path.isNotEmpty ? audioFile.path : null,
        rawBytes: audioFile.path.isEmpty ? audioFile.bytes : null,
      )) {
        // `break` cancela la suscripción -> el servicio avisa al worker que corte.
        if (_cancelRequested || isDisposed) break;
        switch (event) {
          case AnalysisProgress(:final fraction, :final stage):
            _analysisProgress = fraction;
            _analysisStage = stage;
            notifyListeners();
          case AnalysisDone(result: final done):
            result = done;
        }
      }
      if (result == null) {
        _selectedAudio = null;
        _errorMessage = _cancelRequested ? null : 'No se pudo leer el archivo de audio. Probá con otro archivo.';
        return;
      }

      // Verificación de duplicado SHA-256
      final isDup = await songsRepo.isSha256Duplicate(result.sha256).withNetworkTimeout();
      if (isDup) {
        _errorMessage = 'Este audio ya está publicado en StreamTunes. Elegí otro archivo.';
        _selectedAudio = null;
        _analysisResult = null;
      } else {
        _analysisResult = result;
      }
    } catch (e) {
      _errorMessage = 'No se pudo analizar el audio. ${describeError(e)}';
      _selectedAudio = null;
      _analysisResult = null;
    } finally {
      _isAnalyzing = false;
      notifyListeners();
    }
  }

  /// Publica la canción verificando límites de negocio (60s mín, cupo de 20 temas)
  Future<bool> publishSong({
    required String bandId,
    required String bandName,
    required String title,
    required String genre,
    String? albumId,
    String? lyricsLrc,
    required int durationSeconds,
    bool runInBackground = false,
  }) async {
    _errorMessage = null;
    _successMessage = null;

    final currentAnalysis = analysisResult;
    final currentAudio = selectedAudio;

    if (currentAnalysis == null || currentAudio == null) {
      _errorMessage = 'Debes seleccionar y analizar un archivo de audio válido antes de publicar.';
      notifyListeners();
      return false;
    }

    // Validación de duración mínima: 60 segundos
    if (durationSeconds < 60) {
      _errorMessage = 'La canción debe durar al menos 60 segundos (duración actual: $durationSeconds s).';
      notifyListeners();
      return false;
    }

    // Validación de cupo de 20 canciones
    if (hasReachedSongLimit) {
      _errorMessage =
          'Cupo alcanzado: La banda ya tiene $_songCount/$_maxSongs canciones. Elimina una para subir una nueva.';
      notifyListeners();
      return false;
    }

    _isUploading = true;
    notifyListeners();

    try {
      final song = Song(
        id: '',
        bandId: bandId,
        albumId: albumId,
        title: title.trim(),
        genre: genre,
        // Ruta local: el repositorio la sube a Storage. En web no hay ruta y se
        // envían los bytes. Nunca se inventa una URL que no existe.
        audioPath: currentAudio.path,
        coverUrl: _selectedCoverPath ?? 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4',
        durationSeconds: durationSeconds,
        lyricsLrc: lyricsLrc?.trim(),
        audioSha256: currentAnalysis.sha256,
        waveformPeaks: currentAnalysis.waveformPeaks,
        createdAt: DateTime.now(),
        bandName: bandName,
      );

      final uploaded = await songsRepo.uploadSong(
        song,
        audioBytes: currentAudio.path.isEmpty ? currentAudio.bytes : null,
        audioExtension: currentAnalysis.format,
      );
      _songCount++;

      // Soporte de Workmanager en segundo plano y notificación nativa
      if (runInBackground) {
        await notifications.scheduleSongUpload(
          taskId: 'upload-${uploaded.id}',
          songTitle: uploaded.title,
          bandName: bandName,
        );
      } else {
        await notifications.showUploadSuccessNotification(songTitle: uploaded.title, bandName: bandName);
      }

      _successMessage = '¡"$title" fue publicado exitosamente!';
      _selectedAudio = null;
      _analysisResult = null;
      _selectedCoverPath = null;
      return true;
    } catch (e) {
      _errorMessage = describeError(e);
      return false;
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  /// Cancela el análisis en curso (el worker deja de procesar en el próximo bloque).
  void cancelAnalysis() {
    if (!_isAnalyzing) return;
    _cancelRequested = true;
  }

  @override
  void dispose() {
    _cancelRequested = true;
    if (_ownsAnalyzer) audioAnalyzer.dispose();
    super.dispose();
  }

  void reset() {
    _selectedAudio = null;
    _analysisResult = null;
    _selectedCoverPath = null;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }
}
