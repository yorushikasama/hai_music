import '../models/song.dart';

/// Song 扩展方法
extension SongExtension on Song {
  /// 格式化时长为 "mm:ss" 格式
  String get formattedDuration {
    if (duration == null) return '00:00';
    final minutes = duration! ~/ 60;
    final seconds = duration! % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// 获取艺术家和专辑信息
  String get artistAndAlbum {
    if (album.isNotEmpty && album != '未知专辑') {
      return '$artist · $album';
    }
    return artist;
  }

  /// 是否有有效的音频URL
  bool get hasAudioUrl => audioUrl.isNotEmpty && audioUrl.startsWith('http');

  /// 是否有有效的封面URL
  bool get hasCoverUrl => coverUrl.isNotEmpty && coverUrl.startsWith('http');

  /// 是否有R2对象存储URL
  bool get hasR2Url => r2CoverUrl != null && r2CoverUrl!.isNotEmpty;

  /// 获取最佳封面URL（优先R2）
  String get bestCoverUrl => r2CoverUrl ?? coverUrl;

  /// 获取最佳音频URL（优先R2）
  String get bestAudioUrl => (audioUrl.isNotEmpty && audioUrl.startsWith('http')) ? audioUrl : '';

  /// 是否为有效歌曲
  bool get isValid => id.isNotEmpty && title.isNotEmpty && artist.isNotEmpty;

  /// 复制并更新字段
  Song copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    String? coverUrl,
    String? audioUrl,
    int? duration,
    String? platform,
    String? r2CoverUrl,
    String? lyricsLrc,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      coverUrl: coverUrl ?? this.coverUrl,
      audioUrl: audioUrl ?? this.audioUrl,
      duration: duration ?? this.duration,
      platform: platform ?? this.platform,
      r2CoverUrl: r2CoverUrl ?? this.r2CoverUrl,
      lyricsLrc: lyricsLrc ?? this.lyricsLrc,
    );
  }
}

/// Song 列表扩展
extension SongListExtension on List<Song> {
  /// 过滤有效歌曲
  List<Song> get validSongs => where((song) => song.isValid).toList();

  /// 按标题排序
  List<Song> sortByTitle() {
    final sorted = List<Song>.from(this);
    sorted.sort((a, b) => a.title.compareTo(b.title));
    return sorted;
  }

  /// 按艺术家排序
  List<Song> sortByArtist() {
    final sorted = List<Song>.from(this);
    sorted.sort((a, b) => a.artist.compareTo(b.artist));
    return sorted;
  }

  /// 按时长排序
  List<Song> sortByDuration() {
    final sorted = List<Song>.from(this);
    sorted.sort((a, b) => (a.duration ?? 0).compareTo(b.duration ?? 0));
    return sorted;
  }

  /// 获取总时长（秒）
  int get totalDuration {
    return fold(0, (total, song) => total + (song.duration ?? 0));
  }

  /// 格式化总时长
  String get formattedTotalDuration {
    final hours = totalDuration ~/ 3600;
    final minutes = (totalDuration % 3600) ~/ 60;
    if (hours > 0) {
      return '$hours小时$minutes分钟';
    }
    return '$minutes分钟';
  }
}
