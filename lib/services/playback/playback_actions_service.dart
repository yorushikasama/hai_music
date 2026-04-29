import 'dart:async';

import '../../models/play_mode.dart';
import '../../models/song.dart';
import '../../utils/logger.dart';
import 'desktop_playback_backend.dart';
import 'mobile_playback_backend.dart';
import 'playback_backend.dart';
import 'playlist_manager_service.dart';
import '../cache/cache.dart';
import 'song_url_service.dart';

/// 播放动作服务，封装播放控制的核心业务逻辑
class PlaybackActionsService {
  final PlaybackBackend _backend;
  final PlaylistManagerService _playlistManager;
  final SongUrlService _urlService;
  final SmartCacheService _cacheService = SmartCacheService();

  int _playRequestVersion = 0;
  int _consecutiveFailures = 0;
  static const int _maxConsecutiveFailures = 3;

  /// 当前播放请求版本号，用于取消过期的播放请求
  int get playRequestVersion => _playRequestVersion;

  PlaybackActionsService({
    required PlaybackBackend backend,
    required PlaylistManagerService playlistManager,
    required SongUrlService urlService,
  }) : _backend = backend,
       _playlistManager = playlistManager,
       _urlService = urlService;

  /// 播放歌曲列表，从指定索引开始
  Future<void> playSongs(List<Song> songs, {int startIndex = 0}) async {
    if (songs.isEmpty) return;

    Logger.info('播放歌曲列表: ${songs.length} 首，起始索引: $startIndex', 'PlaybackActions');
    _playlistManager.setPlaylist(songs, startIndex: startIndex);

    if (_backend is MobilePlaybackBackend) {
      await _backend.playSongsFromList(songs, startIndex);
      return;
    }

    await playCurrentSong();
  }

  /// 播放单首歌曲，可选指定播放列表
  Future<void> playSong(Song song, {List<Song>? playlist}) async {
    final songs = playlist ?? [song];
    int index = 0;

    if (playlist != null) {
      index = playlist.indexWhere((s) => s.id == song.id);
      if (index == -1) index = 0;
    }

    await playSongs(songs, startIndex: index);
  }

  /// 更新播放列表，保持当前歌曲不变
  Future<void> updatePlaylist(List<Song> songs) async {
    if (songs.isEmpty) return;
    final currentSong = _playlistManager.currentSong;
    if (currentSong == null) return;

    final currentIndex = songs.indexWhere((s) => s.id == currentSong.id);
    if (currentIndex == -1) return;

    _playlistManager.updatePlaylist(songs, currentIndex);
  }

  /// 递增播放请求版本号，用于取消过期的异步播放请求
  Future<int> incrementPlayRequestVersion() async {
    _playRequestVersion++;
    return _playRequestVersion;
  }

  /// 播放当前歌曲，返回播放结果
  Future<PlayResult> playCurrentSong() async {
    final currentSong = _playlistManager.currentSong;
    if (currentSong == null) return PlayResult.failed;

    final currentVersion = await incrementPlayRequestVersion();

    try {
      final audioUrl = await _urlService.getSongUrl(currentSong);

      if (currentVersion != _playRequestVersion) {
        return PlayResult.cancelled;
      }

      if (audioUrl == null || audioUrl.isEmpty) {
        throw Exception('获取播放链接失败: ${currentSong.title}');
      }

      final songWithUrl = _createSongWithUrl(currentSong, audioUrl);

      await _backend.playSong(songWithUrl);

      unawaited(_cacheService.cacheOnPlay(songWithUrl).catchError((Object e) {
        Logger.error('缓存歌曲失败: ${songWithUrl.title}', e, null, 'PlaybackActions');
      }));

      await _backend.updateMediaItem(songWithUrl);

      Logger.success('播放成功: ${currentSong.title}', 'PlaybackActions');
      _consecutiveFailures = 0;
      return PlayResult.success;
    } catch (e) {
      Logger.error('播放失败: ${currentSong.title}', e, null, 'PlaybackActions');
      _consecutiveFailures++;
      if (currentVersion == _playRequestVersion &&
          _consecutiveFailures < _maxConsecutiveFailures) {
        return PlayResult.shouldRetry;
      } else if (_consecutiveFailures >= _maxConsecutiveFailures) {
        Logger.warning(
          '连续 $_maxConsecutiveFailures 首播放失败，停止重试',
          'PlaybackActions',
        );
        return PlayResult.maxRetriesReached;
      }
      return PlayResult.failed;
    }
  }

  /// 以新音质重新加载当前歌曲
  Future<PlayResult> reloadWithNewQuality({
    required Song currentSong,
    required Duration savedPosition,
    required bool wasPlaying,
    required bool isDesktop,
  }) async {
    final currentVersion = await incrementPlayRequestVersion();

    try {
      if (isDesktop) {
        try {
          await _backend.stop();
        } catch (e) {
          Logger.warning('音质切换停止播放失败: $e', 'PlaybackActions');
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }

      final audioUrl = await _urlService.getSongUrl(
        currentSong,
        forceRefresh: true,
      );
      if (currentVersion != _playRequestVersion) {
        return PlayResult.cancelled;
      }
      if (audioUrl == null || audioUrl.isEmpty) {
        return PlayResult.failed;
      }

      final songWithUrl = _createSongWithUrl(currentSong, audioUrl);

      await _backend.playSong(songWithUrl);

      if (savedPosition.inMilliseconds > 0) {
        try {
          await _backend.seek(savedPosition);
        } catch (e) {
          Logger.warning('音质切换恢复位置失败: $e', 'PlaybackActions');
        }
      }

      if (!wasPlaying) {
        try {
          await _backend.pause();
        } catch (e) {
          Logger.warning('音质切换暂停失败: $e', 'PlaybackActions');
        }
      }

      await _backend.updateMediaItem(songWithUrl);

      Logger.success('音质切换成功', 'PlaybackActions');
      return PlayResult.success;
    } catch (e, stack) {
      Logger.error('音质切换重载失败', e, stack, 'PlaybackActions');
      return PlayResult.failed;
    }
  }

  /// 根据播放模式处理播放完成事件
  Future<void> handlePlaybackCompleted(PlayMode playMode) async {
    if (_backend is DesktopPlaybackBackend) {
      switch (playMode) {
        case PlayMode.single:
          await _backend.seek(Duration.zero);
          await _backend.resume();
          break;
        case PlayMode.sequence:
        case PlayMode.shuffle:
          await _tryPlayNext();
          break;
      }
    }
  }

  /// 尝试播放下一首歌曲
  Future<void> tryPlayNext() async {
    await _tryPlayNext();
  }

  Future<void> _tryPlayNext() async {
    if (_backend is MobilePlaybackBackend) {
      await _backend.skipToNext();
      return;
    }

    if (_playlistManager.moveToNext()) {
      await playCurrentSong();
    }
  }

  Song _createSongWithUrl(Song song, String audioUrl) {
    return Song(
      id: song.id,
      title: song.title,
      artist: song.artist,
      album: song.album,
      coverUrl: song.coverUrl,
      audioUrl: audioUrl,
      duration: song.duration,
      platform: song.platform,
      r2CoverUrl: song.r2CoverUrl,
      lyricsLrc: song.lyricsLrc,
      lyricsTrans: song.lyricsTrans,
      localCoverPath: song.localCoverPath,
      localLyricsPath: song.localLyricsPath,
      localTransPath: song.localTransPath,
    );
  }
}

/// 播放操作结果枚举
enum PlayResult {
  /// 播放成功
  success,

  /// 播放失败
  failed,

  /// 请求被取消（有更新的播放请求）
  cancelled,

  /// 播放失败，应尝试下一首
  shouldRetry,

  /// 连续失败次数达到上限
  maxRetriesReached,
}
