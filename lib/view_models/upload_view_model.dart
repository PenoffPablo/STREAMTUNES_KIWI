import 'package:flutter/foundation.dart';
import 'package:streamtunes/models/album.dart';
import 'package:streamtunes/models/song.dart';
import 'package:streamtunes/repositories/config_repository.dart';
import 'package:streamtunes/repositories/songs_repository.dart';
import 'package:streamtunes/services/audio_analyzer_service.dart';
import 'package:streamtunes/services/background_upload_service.dart';
import 'package:streamtunes/services/device_capabilities_service.dart';

class UploadViewModel extends ChangeNotifier {
  final SongsRepository songsRepo;
  final ConfigRepository configRepo;
  final DeviceCapabilitiesService deviceService;

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
  });

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

  Future<void> loadBandQuota(String bandId) async {
    try {
      final config = await configRepo.getConfig();
      _maxSongs = config.maxSongsPerBand;
      _maxAlbums = config.maxAlbumsPerBand;
    } catch (e) {
      debugPrint('[UploadViewModel] Error leyendo config: $e');
    }

    try {
      _songCount = await songsRepo.getBandSongCount(bandId);
    } catch (e) {
      debugPrint('[UploadViewModel] Error contando canciones: $e');
    }

    try {
      _albumCount = await songsRepo.getBandAlbumCount(bandId);
    } catch (e) {
      debugPrint('[UploadViewModel] Error contando álbumes: $e');
    }

    try {
      _bandAlbums = await songsRepo.getBandAlbums(bandId);
    } catch (e) {
      debugPrint('[UploadViewModel] Error cargando álbumes: $e');
    }

    notifyListeners();
  }

  Future<void> pickCoverPhoto({bool fromCamera = false}) async {
    final path = await deviceService.pickCoverPhoto(fromCamera: fromCamera);
    if (path != null) {
      _selectedCoverPath = path;
      notifyListeners();
    }
  }

  /// Selecciona el archivo de audio y ejecuta el análisis pesado en Isolate.run (Criterio D3)
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

    try {
      // Invocación al Isolate pesado
      final result = await AudioAnalyzerService.analyzeAudio(
        filePath: audioFile.path.isNotEmpty ? audioFile.path : null,
        rawBytes: audioFile.bytes,
      );

      // Verificación de duplicado SHA-256
      final isDup = await songsRepo.isSha256Duplicate(result.sha256);
      if (isDup) {
        _errorMessage = 'Este archivo de audio ya fue subido previamente a StreamTunes (SHA-256 duplicado).';
        _selectedAudio = null;
        _analysisResult = null;
      } else {
        _analysisResult = result;
      }
    } catch (e) {
      _errorMessage = 'Error al analizar el audio: $e';
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
      _errorMessage = 'Cupo alcanzado: La banda ya tiene $_songCount/$_maxSongs canciones. Elimina una para subir una nueva.';
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
        audioPath: currentAudio.path.isNotEmpty
            ? currentAudio.path
            : 'https://streamtunes.storage/audio/${currentAnalysis.sha256}.${currentAnalysis.format}',
        coverUrl: _selectedCoverPath ??
            'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4',
        durationSeconds: durationSeconds,
        lyricsLrc: lyricsLrc?.trim(),
        audioSha256: currentAnalysis.sha256,
        waveformPeaks: currentAnalysis.waveformPeaks,
        createdAt: DateTime.now(),
        bandName: bandName,
      );

      final uploaded = await songsRepo.uploadSong(song);
      _songCount++;

      // Soporte de Workmanager en segundo plano y notificación nativa (Criterios E1, E2)
      if (runInBackground) {
        await BackgroundUploadService.scheduleSongUpload(
          taskId: 'upload-${uploaded.id}',
          songTitle: uploaded.title,
          bandName: bandName,
        );
      } else {
        await BackgroundUploadService.showUploadSuccessNotification(
          songTitle: uploaded.title,
          bandName: bandName,
        );
      }

      _successMessage = '¡"$title" fue publicado exitosamente!';
      _selectedAudio = null;
      _analysisResult = null;
      _selectedCoverPath = null;
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isUploading = false;
      notifyListeners();
    }
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
