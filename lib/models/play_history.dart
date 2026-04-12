import '../utils/format_utils.dart';

class PlayHistory {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String coverUrl;
  final int? duration;
  final String? platform;
  final DateTime playedAt;

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
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      artist: json['artist']?.toString() ?? '',
      album: json['album']?.toString() ?? '',
      coverUrl: json['coverUrl']?.toString() ?? '',
      duration: FormatUtils.parseIntSafe(json['duration']),
      platform: json['platform']?.toString(),
      playedAt: json['playedAt'] != null
          ? DateTime.tryParse(json['playedAt'].toString()) ?? DateTime.now()
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
