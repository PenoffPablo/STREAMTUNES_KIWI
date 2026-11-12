import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:streamtunes/models/parsed_lrc.dart';
import 'package:streamtunes/models/song.dart';
import 'package:streamtunes/services/audio_player_service.dart';
import 'package:streamtunes/services/lrc_parser_service.dart';

class PlayerViewModel extends ChangeNotifier {
  final AudioPlayerService playerService;

  Song? _currentSong;
  CustomPlaybackState _playbackState = CustomPlaybackState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration _bufferedPosition = Duration.zero;
  List<LrcLine> _lyrics = [];
  int _currentLyricIndex = -1;

  StreamSubscription? _songSub;
  StreamSubscription? _stateSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _bufferedSub;

  PlayerViewModel({required this.playerService}) {
    _init();
  }

  Song? get currentSong => _currentSong;
  CustomPlaybackState get playbackState => _playbackState;
  Duration get position => _position;
  Duration get duration => _duration;
  Duration get bufferedPosition => _bufferedPosition;
  List<LrcLine> get lyrics => List.unmodifiable(_lyrics);
  int get currentLyricIndex => _currentLyricIndex;
  List<Song> get queue => playerService.queue;
  bool get isPlaying => _playbackState == CustomPlaybackState.playing;
  bool get hasSong => _currentSong != null;

  void _init() {
    _songSub = playerService.currentSongStream.listen((song) {
      _currentSong = song;
      if (song != null) {
        _lyrics = LrcParserService.parse(song.lyricsLrc);
        _duration = Duration(seconds: song.durationSeconds);
      } else {
        _lyrics = [];
        _duration = Duration.zero;
      }
      _currentLyricIndex = -1;
      notifyListeners();
    });

    _stateSub = playerService.playbackStateStream.listen((state) {
      _playbackState = state;
      notifyListeners();
    });

    _positionSub = playerService.positionStream.listen((pos) {
      _position = pos;
      if (_lyrics.isNotEmpty) {
        final newIndex = LrcParserService.getCurrentLineIndex(_lyrics, pos);
        if (newIndex != _currentLyricIndex) {
          _currentLyricIndex = newIndex;
        }
      }
      notifyListeners();
    });

    _durationSub = playerService.durationStream.listen((dur) {
      _duration = dur;
      notifyListeners();
    });

    _bufferedSub = playerService.bufferedPositionStream.listen((buf) {
      _bufferedPosition = buf;
      notifyListeners();
    });
  }

  Future<void> playSong(Song song, {List<Song>? queue}) async {
    await playerService.playSong(song, queue: queue);
  }

  Future<void> togglePlayPause() async {
    await playerService.togglePlayPause();
  }

  Future<void> seek(Duration pos) async {
    await playerService.seek(pos);
  }

  Future<void> skipToNext() async {
    await playerService.skipToNext();
  }

  Future<void> skipToPrevious() async {
    await playerService.skipToPrevious();
  }

  @override
  void dispose() {
    _songSub?.cancel();
    _stateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _bufferedSub?.cancel();
    super.dispose();
  }
}
