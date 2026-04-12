import '../utils/format_utils.dart';

const Object _sentinel = Object();

class FavoriteSong {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String coverUrl;
  final String? localAudioPath;
  final String? localCoverPath;
  final String? r2AudioUrl;
  final String? r2CoverUrl;
  final int? duration;
  final String? platform;
  final String? lyricsLrc;
  final DateTime createdAt;
  final DateTime? syncedAt;

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
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      artist: json['artist']?.toString() ?? '',
      album: json['album']?.toString() ?? '',
      // 兼容不同字段名: original_cover_url > cover_url > coverUrl
      coverUrl: (json['original_cover_url'] ?? json['cover_url'] ?? json['coverUrl'])?.toString() ?? '',
      localAudioPath: json['local_audio_path']?.toString(),
      localCoverPath: json['local_cover_path']?.toString(),
      r2AudioUrl: json['r2_audio_url']?.toString(),
      r2CoverUrl: json['r2_cover_url']?.toString(),
      duration: FormatUtils.parseIntSafe(json['duration']),
      platform: json['platform']?.toString(),
      lyricsLrc: json['lyrics_lrc']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      syncedAt: json['synced_at'] != null
          ? DateTime.tryParse(json['synced_at'].toString())
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
      'duration': duration ?? 0,
      'platform': platform,
      'lyrics_lrc': lyricsLrc,
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
    Object? localAudioPath = _sentinel,
    Object? localCoverPath = _sentinel,
    Object? r2AudioUrl = _sentinel,
    Object? r2CoverUrl = _sentinel,
    int? duration,
    Object? platform = _sentinel,
    Object? lyricsLrc = _sentinel,
    DateTime? createdAt,
    Object? syncedAt = _sentinel,
  }) {
    return FavoriteSong(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      coverUrl: coverUrl ?? this.coverUrl,
      localAudioPath: localAudioPath == _sentinel ? this.localAudioPath : localAudioPath as String?,
      localCoverPath: localCoverPath == _sentinel ? this.localCoverPath : localCoverPath as String?,
      r2AudioUrl: r2AudioUrl == _sentinel ? this.r2AudioUrl : r2AudioUrl as String?,
      r2CoverUrl: r2CoverUrl == _sentinel ? this.r2CoverUrl : r2CoverUrl as String?,
      duration: duration ?? this.duration,
      platform: platform == _sentinel ? this.platform : platform as String?,
      lyricsLrc: lyricsLrc == _sentinel ? this.lyricsLrc : lyricsLrc as String?,
      createdAt: createdAt ?? this.createdAt,
      syncedAt: syncedAt == _sentinel ? this.syncedAt : syncedAt as DateTime?,
    );
  }
}
