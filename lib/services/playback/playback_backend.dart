import '../../models/song.dart';

/// 播放后端抽象接口，定义统一的播放控制协议
abstract class PlaybackBackend {
  /// 播放状态流
  Stream<bool> get playingStream;

  /// 播放位置流
  Stream<Duration> get positionStream;

  /// 总时长流
  Stream<Duration?> get durationStream;

  /// 播放完成流
  Stream<void> get completionStream;

  /// 当前媒体项流
  Stream<PlaybackMediaItem?> get mediaItemStream;

  /// 当前是否正在播放
  bool get isPlaying;

  /// 当前播放位置
  Duration get currentPosition;

  /// 播放指定歌曲
  Future<void> playSong(Song song);

  /// 暂停播放
  Future<void> pause();

  /// 恢复播放
  Future<void> resume();

  /// 跳转到指定位置
  Future<void> seek(Duration position);

  /// 停止播放
  Future<void> stop();

  /// 设置音量（0.0-1.0）
  Future<void> setVolume(double volume);

  /// 设置播放速度
  Future<void> setSpeed(double speed);

  /// 从列表中播放指定索引的歌曲
  Future<void> playSongsFromList(List<Song> songs, int startIndex);

  /// 跳到下一首
  Future<void> skipToNext();

  /// 跳到上一首
  Future<void> skipToPrevious();

  /// 跳到指定索引的歌曲
  Future<void> skipToQueueItem(int index);

  /// 更新媒体项通知信息
  Future<void> updateMediaItem(Song song);

  /// 更新播放列表
  void updatePlaylist(List<Song> songs, {int initialIndex = 0, Duration? initialPosition,});

  /// 释放资源
  void dispose();
}

/// 播放媒体项数据模型，用于后端与控制器之间的数据传递
class PlaybackMediaItem {
  final String id;
  final String title;
  final String artist;
  final String album;
  final Duration? duration;
  final String? coverUrl;
  final String? audioUrl;
  final String? platform;
  final String? r2CoverUrl;
  final String? lyricsLrc;
  final String? lyricsTrans;
  final String? localCoverPath;
  final String? localLyricsPath;
  final String? localTransPath;

  const PlaybackMediaItem({
    required this.id,
    required this.title,
    required this.artist,
    this.album = '',
    this.duration,
    this.coverUrl,
    this.audioUrl,
    this.platform,
    this.r2CoverUrl,
    this.lyricsLrc,
    this.lyricsTrans,
    this.localCoverPath,
    this.localLyricsPath,
    this.localTransPath,
  });

  /// 转换为 Song 模型
  Song toSong() {
    return Song(
      id: id,
      title: title,
      artist: artist,
      album: album,
      duration: duration?.inSeconds,
      coverUrl: coverUrl ?? '',
      audioUrl: audioUrl ?? '',
      platform: platform,
      r2CoverUrl: r2CoverUrl,
      lyricsLrc: lyricsLrc,
      lyricsTrans: lyricsTrans,
      localCoverPath: localCoverPath,
      localLyricsPath: localLyricsPath,
      localTransPath: localTransPath,
    );
  }
}
