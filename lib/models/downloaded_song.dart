enum SongSource {
  downloaded,
  local,
  recovered,
}

extension SongSourceExtension on SongSource {
  String get label {
    switch (this) {
      case SongSource.downloaded:
        return 'downloaded';
      case SongSource.local:
        return 'local';
      case SongSource.recovered:
        return 'recovered';
    }
  }

  bool get isLocal => this == SongSource.local;
  bool get isDownloaded => this == SongSource.downloaded;
  bool get isRecovered => this == SongSource.recovered;
  bool get hasLocalFile => this == SongSource.local || this == SongSource.recovered;
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
  final int? audioQualityValue;
  final String? contentUri;
  final int? fileSize;

  DownloadedSong({
    required this.id,
    required this.title,
    required this.artist,
    required this.localAudioPath,
    required this.downloadedAt,
    this.album = '',
    this.coverUrl = '',
    this.localCoverPath,
    this.localLyricsPath,
    this.localTransPath,
    this.duration,
    this.platform,
    this.source = SongSource.downloaded,
    this.audioQualityValue,
    this.contentUri,
    this.fileSize,
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
      downloadedAt: DateTime.tryParse(json['downloadedAt'] as String? ?? '') ?? DateTime.now(),
      source: DownloadedSong.parseSource(json['source']),
      audioQualityValue: json['audioQualityValue'] as int?,
      contentUri: json['contentUri'] as String?,
      fileSize: json['fileSize'] as int?,
    );
  }

  static SongSource parseSource(dynamic value) {
    final str = value?.toString() ?? '';
    switch (str) {
      case 'local':
        return SongSource.local;
      case 'recovered':
        return SongSource.recovered;
      default:
        return SongSource.downloaded;
    }
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
      'source': source.label,
      'audioQualityValue': audioQualityValue,
      if (contentUri != null) 'contentUri': contentUri,
      if (fileSize != null) 'fileSize': fileSize,
    };
  }

  DownloadedSong copyWith({
    String? localAudioPath,
    String? localCoverPath,
    String? localLyricsPath,
    String? localTransPath,
    int? audioQualityValue,
    String? contentUri,
    int? fileSize,
    int? duration,
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
      duration: duration ?? this.duration,
      platform: platform,
      downloadedAt: downloadedAt,
      source: source,
      audioQualityValue: audioQualityValue ?? this.audioQualityValue,
      contentUri: contentUri ?? this.contentUri,
      fileSize: fileSize ?? this.fileSize,
    );
  }
}
