import '../models/favorite_song.dart';
import '../models/song.dart';

/// FavoriteSong 扩展方法
extension FavoriteSongExtension on FavoriteSong {
  /// 转换为 Song 对象
  Song toSong() {
    return Song(
      id: id,
      title: title,
      artist: artist,
      album: album,
      coverUrl: r2CoverUrl ?? coverUrl,
      audioUrl: r2AudioUrl ?? '',
      duration: duration,
      platform: platform,
      r2CoverUrl: r2CoverUrl,
      lyricsLrc: lyricsLrc, // 包含歌词
    );
  }
}

/// FavoriteSong 列表扩展
extension FavoriteSongListExtension on List<FavoriteSong> {
  /// 批量转换为 Song 列表
  List<Song> toSongList() {
    return map((f) => f.toSong()).toList();
  }
}
