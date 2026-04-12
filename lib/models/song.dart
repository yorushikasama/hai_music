class Song {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String coverUrl;
  final String audioUrl;
  final int? duration;
  final String? platform;
  final String? r2CoverUrl;
  final String? lyricsLrc;
  final String? lyricsTrans;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    this.album = '',
    this.coverUrl = '',
    this.audioUrl = '',
    this.duration,
    this.platform,
    this.r2CoverUrl,
    this.lyricsLrc,
    this.lyricsTrans,
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: (json['id'] ?? '') as String,
      title: (json['title'] ?? '') as String,
      artist: (json['artist'] ?? '') as String,
      album: (json['album'] ?? '') as String,
      coverUrl: (json['coverUrl'] ?? '') as String,
      audioUrl: (json['audioUrl'] ?? '') as String,
      duration: json['duration'] as int?,
      platform: json['platform'] as String?,
      r2CoverUrl: json['r2CoverUrl'] as String?,
      lyricsLrc: json['lyricsLrc'] as String?,
      lyricsTrans: json['lyricsTrans'] as String?,
    );
  }

  factory Song.fromApiJson(Map<String, dynamic> json, String platform) {
    int durationSeconds = 0;
    if (json['time'] != null) {
      if (json['time'] is int) {
        durationSeconds = json['time'] as int;
      } else if (json['time'] is String) {
        durationSeconds = int.tryParse(json['time'] as String) ?? 0;
      }
    }

    return Song(
      id: (json['id'] ?? '').toString(),
      title: (json['name'] ?? json['title'] ?? '') as String,
      artist: json['artist']?.toString().split(',').first ?? '',
      album: (json['album'] ?? '') as String,
      coverUrl: (json['pic'] ?? json['cover'] ?? '') as String,
      audioUrl: (json['url'] ?? '') as String,
      duration: durationSeconds,
      platform: platform,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'coverUrl': coverUrl,
      'audioUrl': audioUrl,
      'duration': duration,
      'platform': platform,
      'r2CoverUrl': r2CoverUrl,
      'lyricsLrc': lyricsLrc,
      'lyricsTrans': lyricsTrans,
    };
  }
}
