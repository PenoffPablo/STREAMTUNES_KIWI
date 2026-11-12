import 'dart:async';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:streamtunes/models/song.dart';

enum CustomPlaybackState {
  stopped,
  playing,
  paused,
  buffering,
  completed,
}

typedef PlayEventCallback = Future<void> Function(
    String songId, String bandId, int seconds);

class AudioPlayerService {
  final AudioPlayer _player;
  AudioPlayer? _preloader; // Para la precarga en segundo plano ("El túnel")
  final PlayEventCallback? onPlayLogged;

  Song? _currentSong;
  List<Song> _queue = [];
  int _currentIndex = -1;
  bool _hasLoggedCurrentPlay = false;
  bool _wasPlayingBeforeInterruption = false;
  bool _isDisposed = false;

  final _currentSongController = StreamController<Song?>.broadcast();
  final _playbackStateController =
      StreamController<CustomPlaybackState>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration>.broadcast();
  final _bufferedPositionController = StreamController<Duration>.broadcast();

  StreamSubscription? _playerStateSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _bufferedPositionSub;
  StreamSubscription? _interruptionSub;

  AudioPlayerService({
    AudioPlayer? player,
    this.onPlayLogged,
  })  : _player = player ?? AudioPlayer() {
    _init();
  }

  Song? get currentSong => _currentSong;
  List<Song> get queue => List.unmodifiable(_queue);
  int get currentIndex => _currentIndex;
  bool get isPlaying => _player.playing;

  Stream<Song?> get currentSongStream => _currentSongController.stream;
  Stream<CustomPlaybackState> get playbackStateStream =>
      _playbackStateController.stream;
  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration> get durationStream => _durationController.stream;
  Stream<Duration> get bufferedPositionStream =>
      _bufferedPositionController.stream;

  Future<void> _init() async {
    try {
      // Configuración nativa de foco de audio
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());

      _interruptionSub = session.interruptionEventStream.listen((event) {
        if (_isDisposed) return;
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.duck:
              _player.setVolume(0.3);
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              _wasPlayingBeforeInterruption = _player.playing;
              _player.pause();
              break;
          }
        } else {
          switch (event.type) {
            case AudioInterruptionType.duck:
              _player.setVolume(1.0);
              break;
            case AudioInterruptionType.pause:
              if (_wasPlayingBeforeInterruption) {
                _player.play();
              }
              break;
            case AudioInterruptionType.unknown:
              break;
          }
        }
      });
    } catch (e) {
      debugPrint('[AudioPlayerService] AudioSession no soportada en este entorno: $e');
    }

    _playerStateSub = _player.playerStateStream.listen((state) {
      if (_isDisposed || _playbackStateController.isClosed) return;

      if (state.processingState == ProcessingState.loading ||
          state.processingState == ProcessingState.buffering) {
        _playbackStateController.add(CustomPlaybackState.buffering);
      } else if (state.processingState == ProcessingState.completed) {
        _playbackStateController.add(CustomPlaybackState.completed);
        skipToNext();
      } else if (state.playing) {
        _playbackStateController.add(CustomPlaybackState.playing);
      } else {
        _playbackStateController.add(CustomPlaybackState.paused);
      }
    });

    _positionSub = _player.positionStream.listen((pos) {
      if (_isDisposed || _positionController.isClosed) return;

      _positionController.add(pos);

      // Regla de Negocio: Al escuchar al menos 5 segundos, registrar evento
      if (!_hasLoggedCurrentPlay && pos.inSeconds >= 5 && _currentSong != null) {
        _hasLoggedCurrentPlay = true;
        onPlayLogged?.call(
          _currentSong!.id,
          _currentSong!.bandId,
          pos.inSeconds,
        );
      }
    });

    _durationSub = _player.durationStream.listen((dur) {
      if (_isDisposed || _durationController.isClosed) return;

      if (dur != null) {
        _durationController.add(dur);
      }
    });

    _bufferedPositionSub = _player.bufferedPositionStream.listen((buf) {
      if (_isDisposed || _bufferedPositionController.isClosed) return;

      _bufferedPositionController.add(buf);
    });
  }

  /// Carga y reproduce una canción. Configura la cola y activa "El túnel".
  Future<void> playSong(Song song, {List<Song>? queue}) async {
    try {
      _currentSong = song;
      if (!_isDisposed && !_currentSongController.isClosed) {
        _currentSongController.add(_currentSong);
      }
      _hasLoggedCurrentPlay = false;

      if (queue != null && queue.isNotEmpty) {
        _queue = List.from(queue);
        _currentIndex = _queue.indexWhere((s) => s.id == song.id);
        if (_currentIndex == -1) {
          _queue.insert(0, song);
          _currentIndex = 0;
        }
      } else {
        _queue = [song];
        _currentIndex = 0;
      }

      // Soporte de segundo plano con MediaItem para notificación multimedia
      final audioSource = AudioSource.uri(
        Uri.parse(song.audioPath),
        tag: MediaItem(
          id: song.id,
          album: song.genre,
          title: song.title,
          artist: song.bandName ?? 'Banda Independiente',
          artUri: song.coverUrl != null ? Uri.tryParse(song.coverUrl!) : null,
          duration: Duration(seconds: song.durationSeconds),
        ),
      );

      await _player.setAudioSource(audioSource);
      await _player.play();

      // "El Túnel": Precarga automática de la siguiente canción
      _preloadNextSong();
    } catch (e) {
      debugPrint('[AudioPlayerService] Error al reproducir audio: $e');
    }
  }

  /// "El túnel": Precarga el tema i+1 en buffer en segundo plano
  void _preloadNextSong() {
    if (_queue.isEmpty || _currentIndex < 0) return;
    final nextIndex = _currentIndex + 1;
    if (nextIndex < _queue.length) {
      final nextSong = _queue[nextIndex];
      debugPrint('[El Túnel] Precargando siguiente pista en buffer: "${nextSong.title}"');
      _preloader?.dispose();
      _preloader = AudioPlayer();
      _preloader!.setUrl(nextSong.audioPath).catchError((e) {
        debugPrint('[El Túnel] Precarga tolerante a fallos: $e');
        return null;
      });
    }
  }

  Future<void> togglePlayPause() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> resume() async {
    await _player.play();
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  Future<void> skipToNext() async {
    if (_queue.isEmpty) return;
    if (_currentIndex + 1 < _queue.length) {
      _currentIndex++;
      await playSong(_queue[_currentIndex], queue: _queue);
    } else {
      await _player.stop();
      if (!_isDisposed && !_playbackStateController.isClosed) {
        _playbackStateController.add(CustomPlaybackState.stopped);
      }
    }
  }

  Future<void> skipToPrevious() async {
    if (_queue.isEmpty) return;
    if (_currentIndex > 0) {
      _currentIndex--;
      await playSong(_queue[_currentIndex], queue: _queue);
    } else {
      await seek(Duration.zero);
    }
  }

  void dispose() {
    _isDisposed = true;
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _bufferedPositionSub?.cancel();
    _interruptionSub?.cancel();

    _currentSongController.close();
    _playbackStateController.close();
    _positionController.close();
    _durationController.close();
    _bufferedPositionController.close();

    _preloader?.dispose();
    _player.dispose();
  }
}
