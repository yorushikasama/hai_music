enum SongSource {
  downloaded,
  local,
}

class DownloadedSong {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String coverUrl;
  final String localAudioPath;
  final String? localCoverPath;
  final String? localLyricsPath;
  final String? localTransPath;
  final int? duration;
  final String? platform;
  final DateTime downloadedAt;
  final SongSource source;

  DownloadedSong({
    required this.id,
    required this.title,
    required this.artist,
    required this.localAudioPath, required this.downloadedAt, this.album = '',
    this.coverUrl = '',
    this.localCoverPath,
    this.localLyricsPath,
    this.localTransPath,
    this.duration,
    this.platform,
    this.source = SongSource.downloaded,
  });

  factory DownloadedSong.fromJson(Map<String, dynamic> json) {
    return DownloadedSong(
      id: (json['id'] ?? '') as String,
      title: (json['title'] ?? '') as String,
      artist: (json['artist'] ?? '') as String,
      album: (json['album'] ?? '') as String,
      coverUrl: (json['coverUrl'] ?? '') as String,
      localAudioPath: (json['localAudioPath'] ?? '') as String,
      localCoverPath: json['localCoverPath'] as String?,
      localLyricsPath: json['localLyricsPath'] as String?,
      localTransPath: json['localTransPath'] as String?,
      duration: json['duration'] as int?,
      platform: json['platform'] as String?,
      downloadedAt: DateTime.parse(json['downloadedAt'] as String),
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
      'localTransPath': localTransPath,
      'duration': duration,
      'platform': platform,
      'downloadedAt': downloadedAt.toIso8601String(),
      'source': source == SongSource.local ? 'local' : 'downloaded',
    };
  }

  DownloadedSong copyWith({
    String? localAudioPath,
    String? localCoverPath,
    String? localLyricsPath,
    String? localTransPath,
  }) {
    return DownloadedSong(
      id: id,
      title: title,
      artist: artist,
      album: album,
      coverUrl: coverUrl,
      localAudioPath: localAudioPath ?? this.localAudioPath,
      localCoverPath: localCoverPath ?? this.localCoverPath,
      localLyricsPath: localLyricsPath ?? this.localLyricsPath,
      localTransPath: localTransPath ?? this.localTransPath,
      duration: duration,
      platform: platform,
      downloadedAt: downloadedAt,
      source: source,
    );
  }
}
