/// 收藏歌曲模型（用于数据库存储）
class FavoriteSong {
  final String id; // 歌曲ID
  final String title;
  final String artist;
  final String album;
  final String coverUrl;
  final String? localAudioPath; // 本地音频文件路径
  final String? localCoverPath; // 本地封面文件路径
  final String? r2AudioUrl; // R2存储的音频URL
  final String? r2CoverUrl; // R2存储的封面URL
  final int? duration; // 时长（秒）
  final String? platform; // 来源平台
  final String? lyricsLrc; // LRC 格式歌词
  final DateTime createdAt; // 收藏时间
  final DateTime? syncedAt; // 最后同步时间

  FavoriteSong({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.coverUrl,
    this.localAudioPath,
    this.localCoverPath,
    this.r2AudioUrl,
    this.r2CoverUrl,
    this.duration,
    this.platform,
    this.lyricsLrc,
    DateTime? createdAt,
    this.syncedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory FavoriteSong.fromJson(Map<String, dynamic> json) {
    return FavoriteSong(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      artist: json['artist'] ?? '',
      album: json['album'] ?? '',
      coverUrl: json['original_cover_url'] ?? json['cover_url'] ?? '',
      localAudioPath: json['local_audio_path'],
      localCoverPath: json['local_cover_path'],
      r2AudioUrl: json['r2_audio_url'],
      r2CoverUrl: json['r2_cover_url'],
      duration: json['duration'] ?? 0,
      platform: json['platform'],
      lyricsLrc: json['lyrics_lrc'],
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      syncedAt: json['synced_at'] != null 
          ? DateTime.parse(json['synced_at']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'original_cover_url': coverUrl,
      'local_audio_path': localAudioPath,
      'local_cover_path': localCoverPath,
      'r2_audio_url': r2AudioUrl,
      'r2_cover_url': r2CoverUrl,
      'duration': duration,
      'platform': platform,
      'lyrics_lrc': lyricsLrc,
      'sync_status': 'synced',
      'play_count': 0,
      'created_at': createdAt.toIso8601String(),
      'synced_at': syncedAt?.toIso8601String(),
    };
  }

  FavoriteSong copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    String? coverUrl,
    String? localAudioPath,
    String? localCoverPath,
    String? r2AudioUrl,
    String? r2CoverUrl,
    int? duration,
    String? platform,
    String? lyricsLrc,
    DateTime? createdAt,
    DateTime? syncedAt,
  }) {
    return FavoriteSong(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      coverUrl: coverUrl ?? this.coverUrl,
      localAudioPath: localAudioPath ?? this.localAudioPath,
      localCoverPath: localCoverPath ?? this.localCoverPath,
      r2AudioUrl: r2AudioUrl ?? this.r2AudioUrl,
      r2CoverUrl: r2CoverUrl ?? this.r2CoverUrl,
      duration: duration ?? this.duration,
      platform: platform ?? this.platform,
      lyricsLrc: lyricsLrc ?? this.lyricsLrc,
      createdAt: createdAt ?? this.createdAt,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }
}
