class Song {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String coverUrl;
  final String audioUrl;
  final int? duration; // 时长（秒）
  final String? platform; // 音乐平台：netease, qq, kugou等
  final String? r2CoverUrl; // R2对象存储的封面URL
  final String? lyricsLrc; // LRC 格式歌词
  final String? lyricsTrans; // 歌词翻译

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
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      artist: json['artist'] ?? '',
      album: json['album'] ?? '',
      coverUrl: json['coverUrl'] ?? '',
      audioUrl: json['audioUrl'] ?? '',
      duration: json['duration'] as int?,
      platform: json['platform'],
      r2CoverUrl: json['r2CoverUrl'],
      lyricsLrc: json['lyricsLrc'],
      lyricsTrans: json['lyricsTrans'],
    );
  }

  /// 从音乐API返回的数据创建Song对象
  factory Song.fromApiJson(Map<String, dynamic> json, String platform) {
    // 解析时长（可能是秒数或字符串格式）
    int durationSeconds = 0;
    if (json['time'] != null) {
      if (json['time'] is int) {
        durationSeconds = json['time'];
      } else if (json['time'] is String) {
        durationSeconds = int.tryParse(json['time']) ?? 0;
      }
    }

    return Song(
      id: json['id']?.toString() ?? '',
      title: json['name'] ?? json['title'] ?? '',
      artist: json['artist']?.toString().split(',').first ?? '',
      album: json['album'] ?? '',
      coverUrl: json['pic'] ?? json['cover'] ?? '',
      audioUrl: json['url'] ?? '',
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
