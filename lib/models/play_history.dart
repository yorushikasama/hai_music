/// 播放历史记录模型
class PlayHistory {
  final String id; // 歌曲ID
  final String title;
  final String artist;
  final String album;
  final String coverUrl;
  final int? duration; // 时长（秒）
  final String? platform;
  final DateTime playedAt; // 播放时间

  PlayHistory({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.coverUrl,
    this.duration,
    this.platform,
    DateTime? playedAt,
  }) : playedAt = playedAt ?? DateTime.now();

  factory PlayHistory.fromJson(Map<String, dynamic> json) {
    return PlayHistory(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      artist: json['artist'] ?? '',
      album: json['album'] ?? '',
      coverUrl: json['coverUrl'] ?? '',
      duration: json['duration'] ?? 0,
      platform: json['platform'],
      playedAt: json['playedAt'] != null 
          ? DateTime.parse(json['playedAt']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'coverUrl': coverUrl,
      'duration': duration,
      'platform': platform,
      'playedAt': playedAt.toIso8601String(),
    };
  }
}
