class Song {
  final String id;
  final String bandId;
  final String? albumId;
  final String title;
  final String genre;
  final String audioPath;
  final String? coverUrl;
  final int durationSeconds; // >= 60s
  final String? lyricsLrc; // [mm:ss.xx]
  final String audioSha256;
  final List<int> waveformPeaks; // 40 muestras de amplitud normalizadas (0 a 100)
  final int playCount;
  final bool hidden;
  final DateTime createdAt;
  final String? bandName;

  const Song({
    required this.id,
    required this.bandId,
    this.albumId,
    required this.title,
    this.genre = 'Indie',
    required this.audioPath,
    this.coverUrl,
    required this.durationSeconds,
    this.lyricsLrc,
    required this.audioSha256,
    this.waveformPeaks = const [],
    this.playCount = 0,
    this.hidden = false,
    required this.createdAt,
    this.bandName,
  });

  String get formattedDuration {
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Song copyWith({
    String? id,
    String? bandId,
    String? albumId,
    String? title,
    String? genre,
    String? audioPath,
    String? coverUrl,
    int? durationSeconds,
    String? lyricsLrc,
    String? audioSha256,
    List<int>? waveformPeaks,
    int? playCount,
    bool? hidden,
    DateTime? createdAt,
    String? bandName,
  }) {
    return Song(
      id: id ?? this.id,
      bandId: bandId ?? this.bandId,
      albumId: albumId ?? this.albumId,
      title: title ?? this.title,
      genre: genre ?? this.genre,
      audioPath: audioPath ?? this.audioPath,
      coverUrl: coverUrl ?? this.coverUrl,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      lyricsLrc: lyricsLrc ?? this.lyricsLrc,
      audioSha256: audioSha256 ?? this.audioSha256,
      waveformPeaks: waveformPeaks ?? this.waveformPeaks,
      playCount: playCount ?? this.playCount,
      hidden: hidden ?? this.hidden,
      createdAt: createdAt ?? this.createdAt,
      bandName: bandName ?? this.bandName,
    );
  }

  factory Song.fromJson(Map<String, dynamic> json, {String? bandName}) {
    List<int> peaks = [];
    if (json['waveform_peaks'] is List) {
      peaks = (json['waveform_peaks'] as List).map((e) => (e as num).toInt()).toList();
    }

    final rawAudio = json['audio_path'] as String? ?? '';
    final fullAudioPath = (rawAudio.isNotEmpty &&
            !rawAudio.startsWith('http') &&
            !rawAudio.startsWith('file:') &&
            !rawAudio.startsWith('asset:'))
        ? 'https://fajwcwabcdxetuffoiuh.supabase.co/storage/v1/object/public/audio/$rawAudio'
        : rawAudio;

    final rawCover = json['cover_url'] as String?;
    final fullCoverUrl = (rawCover != null &&
            rawCover.isNotEmpty &&
            !rawCover.startsWith('http') &&
            !rawCover.startsWith('file:'))
        ? 'https://fajwcwabcdxetuffoiuh.supabase.co/storage/v1/object/public/covers/$rawCover'
        : rawCover;

    return Song(
      id: json['id'] as String,
      bandId: json['band_id'] as String,
      albumId: json['album_id'] as String?,
      title: json['title'] as String,
      genre: json['genre'] as String? ?? 'Indie',
      audioPath: fullAudioPath,
      coverUrl: fullCoverUrl,
      durationSeconds: (json['duration_s'] as num?)?.toInt() ?? 60,
      lyricsLrc: json['lyrics_lrc'] as String?,
      audioSha256: json['audio_sha256'] as String? ?? '',
      waveformPeaks: peaks,
      playCount: (json['play_count'] as num?)?.toInt() ?? 0,
      hidden: json['hidden'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      bandName: bandName ?? json['bands']?['name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'band_id': bandId,
      'album_id': albumId,
      'title': title,
      'genre': genre,
      'audio_path': audioPath,
      'cover_url': coverUrl,
      'duration_s': durationSeconds,
      'lyrics_lrc': lyricsLrc,
      'audio_sha256': audioSha256,
      'waveform_peaks': waveformPeaks,
      'play_count': playCount,
      'hidden': hidden,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

