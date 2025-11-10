/// 歌曲来源类型
enum SongSource {
  downloaded,  // 应用内下载
  local,       // 本地扫描
}

/// 下载的歌曲模型
class DownloadedSong {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String coverUrl;
  final String localAudioPath; // 本地音频文件路径
  final String? localCoverPath; // 本地封面文件路径
  final String? localLyricsPath; // 本地歌词文件路径
  final int? duration;
  final String? platform;
  final DateTime downloadedAt;
  final SongSource source; // 歌曲来源

  DownloadedSong({
    required this.id,
    required this.title,
    required this.artist,
    this.album = '',
    this.coverUrl = '',
    required this.localAudioPath,
    this.localCoverPath,
    this.localLyricsPath,
    this.duration,
    this.platform,
    required this.downloadedAt,
    this.source = SongSource.downloaded, // 默认为应用下载
  });

  factory DownloadedSong.fromJson(Map<String, dynamic> json) {
    return DownloadedSong(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      artist: json['artist'] ?? '',
      album: json['album'] ?? '',
      coverUrl: json['coverUrl'] ?? '',
      localAudioPath: json['localAudioPath'] ?? '',
      localCoverPath: json['localCoverPath'],
      localLyricsPath: json['localLyricsPath'],
      duration: json['duration'] as int?,
      platform: json['platform'],
      downloadedAt: DateTime.parse(json['downloadedAt']),
      source: json['source'] == 'local' ? SongSource.local : SongSource.downloaded,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'coverUrl': coverUrl,
      'localAudioPath': localAudioPath,
      'localCoverPath': localCoverPath,
      'localLyricsPath': localLyricsPath,
      'duration': duration,
      'platform': platform,
      'downloadedAt': downloadedAt.toIso8601String(),
      'source': source == SongSource.local ? 'local' : 'downloaded',
    };
  }
}
