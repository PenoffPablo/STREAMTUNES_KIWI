import 'dart:async';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:streamtunes/domain/models/song.dart';

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
  StreamSubscription? _indexSub;

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
        // Con la cola cargada en el reproductor, `completed` llega recién al
        // terminar el ÚLTIMO tema: el paso entre temas lo hace el reproductor.
        _playbackStateController.add(CustomPlaybackState.completed);
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

    // Cuando el reproductor avanza solo al tema siguiente de la cola.
    _indexSub = _player.currentIndexStream.listen((index) {
      if (_isDisposed || index == null) return;
      _setCurrent(index);
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

  /// Carga la cola completa en el reproductor y empieza por [song].
  ///
  /// "El túnel": la cola entera se entrega al MISMO `AudioPlayer` con
  /// `setAudioSources`. El reproductor nativo (ExoPlayer / AVQueuePlayer)
  /// precarga el tema siguiente mientras suena el actual, sin cortes.
  /// Antes se creaba un segundo `AudioPlayer` para precargar, pero
  /// just_audio_background admite una sola instancia: fallaba siempre en el
  /// celular y el error quedaba escondido.
  Future<void> playSong(Song song, {List<Song>? queue}) async {
    try {
      _queue = (queue != null && queue.isNotEmpty) ? List.of(queue) : [song];
      var index = _queue.indexWhere((s) => s.id == song.id);
      if (index == -1) {
        _queue.insert(0, song);
        index = 0;
      }
      // Volver a reproducir el MISMO tema también cuenta como escucha nueva
      // (_setCurrent no reinicia el registro si la canción no cambió).
      _hasLoggedCurrentPlay = false;
      _setCurrent(index);

      await _player.setAudioSources(
        [for (final s in _queue) _sourceFor(s)],
        initialIndex: index,
      );
      await _player.play();
    } catch (e) {
      debugPrint('[AudioPlayerService] Error al reproducir audio: $e');
    }
  }

  /// Fuente con `MediaItem`: título, banda y portada para la notificación
  /// multimedia y los controles de la pantalla bloqueada.
  AudioSource _sourceFor(Song song) => AudioSource.uri(
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

  /// Actualiza la canción actual (al empezar o cuando el reproductor avanza
  /// solo al tema siguiente de la cola) y reinicia el registro de escucha.
  void _setCurrent(int index) {
    if (index < 0 || index >= _queue.length) return;
    final song = _queue[index];
    if (_currentIndex == index && _currentSong?.id == song.id) return;
    _currentIndex = index;
    _currentSong = song;
    _hasLoggedCurrentPlay = false;
    if (!_isDisposed && !_currentSongController.isClosed) {
      _currentSongController.add(song);
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

  /// Pasa al tema siguiente de la cola (ya precargado por el reproductor).
  Future<void> skipToNext() async {
    if (_queue.isEmpty) return;
    if (_player.hasNext) {
      await _player.seekToNext();
    } else {
      await _player.stop();
      if (!_isDisposed && !_playbackStateController.isClosed) {
        _playbackStateController.add(CustomPlaybackState.stopped);
      }
    }
  }

  Future<void> skipToPrevious() async {
    if (_queue.isEmpty) return;
    if (_player.hasPrevious) {
      await _player.seekToPrevious();
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
    _indexSub?.cancel();

    _currentSongController.close();
    _playbackStateController.close();
    _positionController.close();
    _durationController.close();
    _bufferedPositionController.close();

    _player.dispose();
  }
}
