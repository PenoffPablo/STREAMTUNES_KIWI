import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:streamtunes/data/services/audio/audio_player_service.dart';
import 'package:streamtunes/data/services/audio/lrc_parser_service.dart';
import 'package:streamtunes/domain/models/parsed_lrc.dart';
import 'package:streamtunes/domain/models/song.dart';
import 'package:streamtunes/ui/core/view_model.dart';

/// Snapshot inmutable del progreso de reproducción.
@immutable
class PlaybackProgress {
  final Duration position;
  final Duration duration;
  final Duration buffered;

  const PlaybackProgress({
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.buffered = Duration.zero,
  });

  double get fraction => duration.inMilliseconds > 0
      ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
      : 0.0;

  PlaybackProgress copyWith({Duration? position, Duration? duration, Duration? buffered}) =>
      PlaybackProgress(
        position: position ?? this.position,
        duration: duration ?? this.duration,
        buffered: buffered ?? this.buffered,
      );
}

/// ViewModel del reproductor global.
///
/// Dos canales de salida, según la frecuencia del dato:
///  * `notifyListeners()` -> cambios "lentos" (canción, play/pausa, línea de letra).
///  * [progressStream]    -> la posición (varias veces por segundo). La UI lo
///    consume con `StreamBuilder`, así un tick NO reconstruye toda la app.
class PlayerViewModel extends ViewModel {
  final AudioPlayerService playerService;

  Song? _currentSong;
  CustomPlaybackState _playbackState = CustomPlaybackState.stopped;
  List<LrcLine> _lyrics = const [];
  Future<List<LrcLine>> _lyricsFuture = Future.value(const []);
  int _currentLyricIndex = -1;
  PlaybackProgress _progress = const PlaybackProgress();

  final _progressController = StreamController<PlaybackProgress>.broadcast();
  final List<StreamSubscription<dynamic>> _subs = [];
  bool _started = false;

  PlayerViewModel({required this.playerService});

  Song? get currentSong => _currentSong;
  CustomPlaybackState get playbackState => _playbackState;
  List<LrcLine> get lyrics => List.unmodifiable(_lyrics);

  /// Future de la letra de la canción actual, para `FutureBuilder`.
  /// Se crea UNA vez por canción en el ViewModel (nunca dentro de `build`,
  /// porque se relanzaría el trabajo en cada reconstrucción).
  Future<List<LrcLine>> get lyricsFuture => _lyricsFuture;
  int get currentLyricIndex => _currentLyricIndex;
  List<Song> get queue => playerService.queue;
  bool get isPlaying => _playbackState == CustomPlaybackState.playing;
  bool get hasSong => _currentSong != null;

  PlaybackProgress get progress => _progress;
  Duration get position => _progress.position;
  Duration get duration => _progress.duration;
  Duration get bufferedPosition => _progress.buffered;

  /// Stream de progreso para `StreamBuilder`. `distinct` evita emitir el mismo
  /// segundo dos veces (menos reconstrucciones).
  Stream<PlaybackProgress> get progressStream => _progressController.stream.distinct(
        (a, b) =>
            a.position.inMilliseconds ~/ 250 == b.position.inMilliseconds ~/ 250 &&
            a.duration == b.duration &&
            a.buffered.inSeconds == b.buffered.inSeconds,
      );

  /// Se suscribe a los streams del servicio. Lo llama el dueño en `initState`.
  void init() {
    if (_started) return;
    _started = true;

    _subs.add(playerService.currentSongStream.listen(_onSongChanged));

    _subs.add(playerService.playbackStateStream.listen((state) {
      if (state == _playbackState) return;
      _playbackState = state;
      notifyListeners();
    }));

    _subs.add(playerService.positionStream.listen((pos) {
      _emitProgress(_progress.copyWith(position: pos));
      _updateLyricIndex(pos);
    }));

    _subs.add(playerService.durationStream.listen(
      (dur) => _emitProgress(_progress.copyWith(duration: dur)),
    ));

    _subs.add(playerService.bufferedPositionStream.listen(
      (buf) => _emitProgress(_progress.copyWith(buffered: buf)),
    ));
  }

  Future<void> _onSongChanged(Song? song) async {
    _currentSong = song;
    _currentLyricIndex = -1;
    _lyrics = const [];
    _emitProgress(PlaybackProgress(
      duration: song != null ? Duration(seconds: song.durationSeconds) : Duration.zero,
    ));
    notifyListeners();

    final lrc = song?.lyricsLrc;
    if (song == null || lrc == null || lrc.trim().isEmpty) {
      _lyricsFuture = Future.value(const []);
      return;
    }

    // El parseo de la letra corre en otro isolate con `compute`.
    final future = _lyricsFuture = compute(LrcParserService.parse, lrc);
    final parsed = await future;
    // Si el usuario cambió de canción mientras tanto, el resultado viejo se descarta.
    if (isDisposed || _currentSong?.id != song.id) return;
    _lyrics = parsed;
    _updateLyricIndex(_progress.position);
    notifyListeners();
  }

  void _emitProgress(PlaybackProgress next) {
    _progress = next;
    if (!_progressController.isClosed) _progressController.add(next);
  }

  void _updateLyricIndex(Duration pos) {
    if (_lyrics.isEmpty) return;
    final newIndex = LrcParserService.getCurrentLineIndex(_lyrics, pos);
    if (newIndex != _currentLyricIndex) {
      _currentLyricIndex = newIndex;
      notifyListeners(); // solo cuando cambia la línea, no en cada tick
    }
  }

  Future<void> playSong(Song song, {List<Song>? queue}) =>
      playerService.playSong(song, queue: queue);

  /// Reproduce una lista: en orden o mezclada.
  Future<void> playAll(List<Song> songs, {bool shuffle = false}) async {
    if (songs.isEmpty) return;
    final queue = shuffle ? (List<Song>.of(songs)..shuffle()) : songs;
    await playerService.playSong(queue.first, queue: queue);
  }

  /// Play/pausa si es la canción actual; si no, la reproduce con la cola dada.
  Future<void> playOrToggle(Song song, {required List<Song> queue}) {
    if (_currentSong?.id == song.id) return togglePlayPause();
    return playSong(song, queue: queue);
  }

  Future<void> togglePlayPause() => playerService.togglePlayPause();
  Future<void> seek(Duration pos) => playerService.seek(pos);
  Future<void> skipToNext() => playerService.skipToNext();
  Future<void> skipToPrevious() => playerService.skipToPrevious();

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _progressController.close();
    super.dispose();
  }
}
