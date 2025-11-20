import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';
import '../models/song.dart';
import '../models/play_mode.dart';
import '../utils/logger.dart';
import '../utils/platform_utils.dart';
import 'audio_player_interface.dart';
import 'audio_player_factory.dart';
import 'audio_service_manager.dart';
import 'playlist_manager_service.dart';
import 'song_url_service.dart';

/// 播放控制服务
/// 负责音频播放控制和状态管理
class PlaybackControllerService extends ChangeNotifier {
  // 核心服务
  late final AudioPlayerInterface _audioPlayer;
  final PlaylistManagerService _playlistManager;
  final SongUrlService _urlService;
  
  // 播放状态
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  double _volume = 1.0;
  double _speed = 1.0;
  
  // 当前播放的歌曲
  Song? _currentPlayingSong;
  
  // 并发控制
  int _playRequestVersion = 0;
  
  // 订阅管理
  final List<StreamSubscription> _subscriptions = [];
  
  PlaybackControllerService({
    required PlaylistManagerService playlistManager,
    required SongUrlService urlService,
  }) : _playlistManager = playlistManager,
       _urlService = urlService {
    _initializeAudioPlayer();
    _setupPlaylistListener();
  }
  
  // Getters
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  Duration get currentPosition => _currentPosition;
  Duration get totalDuration => _totalDuration;
  double get volume => _volume;
  double get speed => _speed;
  Song? get currentPlayingSong => _currentPlayingSong;
  
  /// 初始化音频播放器
  void _initializeAudioPlayer() {
    Logger.info('初始化播放控制服务', 'PlaybackController');
    
    // 移动端：通过 MusicAudioHandler 的状态来驱动 UI
    if (!PlatformUtils.isDesktop) {
      Logger.info('移动端：PlaybackController 不直接管理播放器，改由 MusicAudioHandler 负责', 'PlaybackController');

      final handler = AudioServiceManager.instance.audioHandler;
      if (handler == null) {
        Logger.warning('AudioHandler 为空，无法监听播放状态', 'PlaybackController');
        return;
      }

      // 监听播放状态（播放/暂停、进度等）
      _subscriptions.add(handler.playbackState.listen((state) {
        // 更新播放状态
        _isPlaying = state.playing;

        // 仅在播放中时，才用 AudioHandler 的 position 覆盖当前位置，
        // 避免某些播放器在暂停时上报 position=0 导致进度条跳回起点。
        if (state.playing) {
          _currentPosition = state.position;
        }

        notifyListeners();
      }));

      // 监听当前媒体项（用于更新当前歌曲和总时长，并同步播放列表索引）
      _subscriptions.add(handler.mediaItem.listen((item) {
        if (item != null) {
          final song = Song(
            id: item.id,
            title: item.title,
            artist: item.artist ?? '',
            album: item.album ?? '',
            duration: item.duration?.inSeconds,
            coverUrl: item.artUri?.toString() ?? '',
            audioUrl: item.extras?['audioUrl'] ?? '',
            platform: item.extras?['platform'],
            r2CoverUrl: item.extras?['r2CoverUrl'],
            lyricsLrc: item.extras?['lyricsLrc'],
          );

          _currentPlayingSong = song;
          _totalDuration = item.duration ?? Duration.zero;

          // 根据当前媒体项的 ID 在播放列表中同步索引
          try {
            _playlistManager.jumpToSong(song);
          } catch (_) {
            // 如果当前播放列表里找不到对应歌曲，则忽略索引同步
          }
        } else {
          _currentPlayingSong = null;
          _totalDuration = Duration.zero;
          _currentPosition = Duration.zero;
        }
        notifyListeners();
      }));

      return;
    }

    // 桌面端：使用本地播放器
    _audioPlayer = AudioPlayerFactory.createPlayer();

    // 监听播放状态变化
    _subscriptions.add(_audioPlayer.playingStream.listen((playing) {
      if (_isPlaying != playing) {
        _isPlaying = playing;
        Logger.debug('播放状态变化: $playing', 'PlaybackController');
        notifyListeners();
      }
    }));

    // 监听播放位置变化
    _subscriptions.add(_audioPlayer.positionStream.listen((position) {
      _currentPosition = position;
      notifyListeners();
    }));

    // 监听总时长变化
    _subscriptions.add(_audioPlayer.durationStream.listen((duration) {
      _totalDuration = duration ?? Duration.zero;
      notifyListeners();
    }));

    // 监听播放完成
    _subscriptions.add(_audioPlayer.completionStream.listen((_) {
      _handlePlaybackCompleted();
    }));
  }
  
  /// 设置播放列表监听器
  void _setupPlaylistListener() {
    _playlistManager.addListener(() {
      // 播放列表变化时的处理逻辑可以在这里添加
    });
  }
  
  /// 播放歌曲列表
  Future<void> playSongs(List<Song> songs, {int startIndex = 0}) async {
    if (songs.isEmpty) {
      Logger.warning('歌曲列表为空', 'PlaybackController');
      return;
    }

    Logger.info('播放歌曲列表: ${songs.length} 首，起始索引: $startIndex', 'PlaybackController');
    final preview = songs
        .take(5)
        .map((s) => '${s.id}:${s.title}')
        .join(', ');
    Logger.debug('播放列表预览(前5首): $preview', 'PlaybackController');

    // 桌面端：沿用本地播放器逻辑
    if (PlatformUtils.isDesktop) {
      // 设置播放列表
      _playlistManager.setPlaylist(songs, startIndex: startIndex);

      // 播放当前歌曲
      await _playCurrentSong();
      return;
    }

    // 移动端：通过 MusicAudioHandler 播放
    final handler = AudioServiceManager.instance.audioHandler;
    if (handler == null) {
      Logger.warning('AudioHandler 为空，无法通过系统服务播放', 'PlaybackController');
      return;
    }

    try {
      // 更新内部播放列表管理（用于 UI 同步）
      _playlistManager.setPlaylist(songs, startIndex: startIndex);

      // 更新 AudioHandler 的播放列表并设置起始索引
      await handler.updatePlaylist(songs, initialIndex: startIndex);

      // 立即跳转到指定索引并开始播放，避免因播放器当前已在播放而忽略 play() 调用
      await handler.skipToQueueItem(startIndex);
      await handler.play();

      Logger.info('✅ 已通过 AudioHandler 播放列表（移动端）', 'PlaybackController');
    } catch (e, stack) {
      Logger.error('通过 AudioHandler 播放列表失败', e, stack, 'PlaybackController');
    }
  }
  
  /// 播放单首歌曲
  Future<void> playSong(Song song, {List<Song>? playlist}) async {
    final songs = playlist ?? [song];
    int index = 0;
    
    if (playlist != null) {
      // 先尝试通过对象引用查找
      index = playlist.indexOf(song);
      
      // 如果没找到，尝试通过 ID 查找
      if (index == -1) {
        index = playlist.indexWhere((s) => s.id == song.id);
      }
      
      // 如果还是没找到，使用默认值 0
      if (index == -1) {
        Logger.warning('在播放列表中找不到歌曲: ${song.title}，使用索引 0', 'PlaybackController');
        index = 0;
      }
    }

    Logger.debug(
      '单曲播放请求: songId=${song.id}, fromPlaylist=${playlist != null}, playlistLen=${songs.length}, resolvedIndex=$index',
      'PlaybackController',
    );
    
    await playSongs(songs, startIndex: index);
  }
  
  /// 更新当前播放列表（不改变当前播放的歌曲）
  Future<void> updatePlaylist(List<Song> songs) async {
    if (songs.isEmpty) return;
    
    final currentSong = _currentPlayingSong;
    if (currentSong == null) return;
    
    // 在新的播放列表中找到当前播放的歌曲
    final currentIndex = songs.indexWhere((s) => s.id == currentSong.id);
    if (currentIndex == -1) {
      Logger.warning('当前播放的歌曲不在新播放列表中', 'PlaybackController');
      return;
    }
    
    // 更新播放列表
    _playlistManager.updatePlaylist(songs, currentIndex);
    
    Logger.info('✅ 播放列表已更新: ${songs.length} 首歌曲，当前索引: $currentIndex', 'PlaybackController');
    notifyListeners();
  }
  
  /// 播放当前歌曲
  Future<void> _playCurrentSong() async {
    final currentSong = _playlistManager.currentSong;
    if (currentSong == null) {
      Logger.warning('没有当前歌曲可播放', 'PlaybackController');
      return;
    }
    
    Logger.debug('🎵 开始播放当前歌曲: ${currentSong.title}', 'PlaybackController');
    
    _playRequestVersion++;
    final currentVersion = _playRequestVersion;
    
    _isLoading = true;
    notifyListeners();
    
    try {
      // 获取播放链接
      final audioUrl = await _urlService.getSongUrl(currentSong);
      
      // 检查请求是否已过期
      if (currentVersion != _playRequestVersion) {
        Logger.debug('播放请求已过期', 'PlaybackController');
        return;
      }
      
      if (audioUrl == null || audioUrl.isEmpty) {
        throw Exception('获取播放链接失败: ${currentSong.title}');
      }
      
      Logger.info('获取到播放链接: ${audioUrl.length > 100 ? audioUrl.substring(0, 100) + "..." : audioUrl}', 'PlaybackController');
      
      // 创建带播放链接的歌曲对象
      final songWithUrl = _createSongWithUrl(currentSong, audioUrl);
      _currentPlayingSong = songWithUrl;
      
      // 播放歌曲
      await _audioPlayer.play(songWithUrl);
      
      // 更新系统媒体通知 (仅移动端)
      Logger.debug('🔄 准备更新系统媒体通知...', 'PlaybackController');
      await _updateMediaItem(songWithUrl);
      
      Logger.success('播放成功: ${currentSong.title}', 'PlaybackController');
      
    } catch (e) {
      Logger.error('播放失败: ${currentSong.title}', e, null, 'PlaybackController');
      
      // 播放失败时尝试下一首
      if (currentVersion == _playRequestVersion) {
        await _tryPlayNext();
      }
    } finally {
      if (currentVersion == _playRequestVersion) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }
  
  /// 播放/暂停切换
  Future<void> togglePlayPause() async {
    try {
      // 桌面端：直接控制本地播放器
      if (PlatformUtils.isDesktop) {
        if (_isPlaying) {
          await _audioPlayer.pause();
          Logger.debug('暂停播放', 'PlaybackController');
        } else {
          if (_currentPlayingSong != null) {
            await _audioPlayer.resume();
            Logger.debug('继续播放', 'PlaybackController');
          } else {
            // 没有当前播放歌曲时，播放播放列表中的当前歌曲
            await _playCurrentSong();
          }
        }
        return;
      }

      // 移动端：通过 AudioHandler 控制
      final handler = AudioServiceManager.instance.audioHandler;
      if (handler == null) {
        Logger.warning('AudioHandler 为空，无法切换播放状态', 'PlaybackController');
        return;
      }

      if (handler.isPlaying) {
        await handler.pause();
        Logger.debug('暂停播放（AudioHandler）', 'PlaybackController');
      } else {
        await handler.play();
        Logger.debug('继续播放（AudioHandler）', 'PlaybackController');
      }
    } catch (e, stack) {
      Logger.error('播放/暂停切换失败', e, stack, 'PlaybackController');
    }
  }

  /// 强制暂停（不依赖当前播放状态，用于定时关闭等场景）
  Future<void> pauseDirect() async {
    try {
      if (PlatformUtils.isDesktop) {
        await _audioPlayer.pause();
        Logger.debug('强制暂停播放（桌面端）', 'PlaybackController');
      } else {
        final handler = AudioServiceManager.instance.audioHandler;
        if (handler != null) {
          await handler.pause();
          Logger.debug('强制暂停播放（AudioHandler）', 'PlaybackController');
        } else {
          Logger.warning('AudioHandler 为空，无法强制暂停', 'PlaybackController');
        }
      }
    } catch (e, stack) {
      Logger.error('强制暂停失败', e, stack, 'PlaybackController');
    }
  }
  
  /// 播放下一首
  Future<void> playNext() async {
    // 桌面端：本地逻辑
    if (PlatformUtils.isDesktop) {
      if (_playlistManager.moveToNext()) {
        await _playCurrentSong();
      } else {
        Logger.info('已到达播放列表末尾', 'PlaybackController');
        await stop();
      }
      return;
    }

    // 移动端：统一走 AudioHandler 的播放路径，让手动/自动下一首使用同一套播放模式逻辑
    final handler = AudioServiceManager.instance.audioHandler;
    if (handler == null) {
      Logger.warning('AudioHandler 为空，无法播放下一首', 'PlaybackController');
      return;
    }

    await handler.skipToNext();
  }
  
  /// 播放上一首
  Future<void> playPrevious() async {
    // 桌面端：本地逻辑
    if (PlatformUtils.isDesktop) {
      if (_playlistManager.moveToPrevious()) {
        await _playCurrentSong();
      } else {
        Logger.info('已到达播放列表开头', 'PlaybackController');
      }
      return;
    }

    // 移动端：统一走 AudioHandler 的播放路径
    final handler = AudioServiceManager.instance.audioHandler;
    if (handler == null) {
      Logger.warning('AudioHandler 为空，无法播放上一首', 'PlaybackController');
      return;
    }

    await handler.skipToPrevious();
  }
  
  /// 跳转到指定歌曲
  Future<void> jumpToSong(Song song) async {
    if (PlatformUtils.isDesktop) {
      if (_playlistManager.jumpToSong(song)) {
        await _playCurrentSong();
      }
      return;
    }

    final handler = AudioServiceManager.instance.audioHandler;
    if (handler == null) {
      Logger.warning('AudioHandler 为空，无法跳转到指定歌曲', 'PlaybackController');
      return;
    }

    // 在当前列表中找到索引
    final currentList = _playlistManager.playlist;
    final index = currentList.indexWhere((s) => s.id == song.id);
    if (index == -1) {
      Logger.warning('在当前播放列表中找不到歌曲: ${song.title}', 'PlaybackController');
      return;
    }

    _playlistManager.jumpToIndex(index);
    await handler.skipToQueueItem(index);
    await handler.play();
  }
  
  /// 跳转到指定索引
  Future<void> jumpToIndex(int index) async {
    if (PlatformUtils.isDesktop) {
      if (_playlistManager.jumpToIndex(index)) {
        await _playCurrentSong();
      }
      return;
    }

    final handler = AudioServiceManager.instance.audioHandler;
    if (handler == null) {
      Logger.warning('AudioHandler 为空，无法跳转到指定索引', 'PlaybackController');
      return;
    }

    if (_playlistManager.jumpToIndex(index)) {
      await handler.skipToQueueItem(index);
      await handler.play();
    }
  }
  
  /// 停止播放
  Future<void> stop() async {
    try {
      if (PlatformUtils.isDesktop) {
        await _audioPlayer.stop();
        _currentPlayingSong = null;
        _currentPosition = Duration.zero;
        _totalDuration = Duration.zero;
        Logger.debug('停止播放', 'PlaybackController');
        notifyListeners();
      } else {
        final handler = AudioServiceManager.instance.audioHandler;
        if (handler != null) {
          await handler.stop();
          Logger.debug('停止播放（AudioHandler）', 'PlaybackController');
        }
      }
    } catch (e, stack) {
      Logger.error('停止播放失败', e, stack, 'PlaybackController');
    }
  }
  
  /// 跳转到指定位置
  Future<void> seekTo(Duration position) async {
    try {
      if (PlatformUtils.isDesktop) {
        await _audioPlayer.seek(position);
        Logger.debug('跳转到位置: ${position.inSeconds}s', 'PlaybackController');
      } else {
        final handler = AudioServiceManager.instance.audioHandler;
        if (handler != null) {
          await handler.seek(position);
          Logger.debug('跳转到位置（AudioHandler）: ${position.inSeconds}s', 'PlaybackController');
        }
      }

      // 无论平台，都立即更新本地当前位置，确保暂停状态下拖动进度条也能生效
      _currentPosition = position;
      notifyListeners();
    } catch (e, stack) {
      Logger.error('跳转失败', e, stack, 'PlaybackController');
    }
  }
  
  /// 设置音量
  Future<void> setVolume(double volume) async {
    try {
      _volume = volume.clamp(0.0, 1.0);

      if (PlatformUtils.isDesktop) {
        await _audioPlayer.setVolume(_volume);
        Logger.debug('设置音量: $_volume', 'PlaybackController');
      } else {
        final handler = AudioServiceManager.instance.audioHandler;
        if (handler != null) {
          await handler.setVolume(_volume);
          Logger.debug('设置音量（AudioHandler）: $_volume', 'PlaybackController');
        }
      }

      notifyListeners();
    } catch (e, stack) {
      Logger.error('设置音量失败', e, stack, 'PlaybackController');
    }
  }
  
  /// 设置播放速度
  Future<void> setSpeed(double speed) async {
    try {
      _speed = speed.clamp(0.25, 3.0);

      if (PlatformUtils.isDesktop) {
        await _audioPlayer.setSpeed(_speed);
        Logger.debug('设置播放速度: $_speed', 'PlaybackController');
      } else {
        final handler = AudioServiceManager.instance.audioHandler;
        if (handler != null) {
          await handler.setSpeed(_speed);
          Logger.debug('设置播放速度（AudioHandler）: $_speed', 'PlaybackController');
        }
      }

      notifyListeners();
    } catch (e, stack) {
      Logger.error('设置播放速度失败', e, stack, 'PlaybackController');
    }
  }
  
  /// 处理播放完成
  void _handlePlaybackCompleted() {
    Logger.info('播放完成: ${_currentPlayingSong?.title}', 'PlaybackController');
    
    // 防止在加载过程中处理播放完成事件
    if (_isLoading) {
      Logger.debug('正在加载中，忽略播放完成事件', 'PlaybackController');
      return;
    }
    
    // 根据播放模式处理
    switch (_playlistManager.playMode) {
      case PlayMode.single:
        // 单曲循环：重新播放
        _audioPlayer.seek(Duration.zero);
        _audioPlayer.resume();
        break;
        
      case PlayMode.sequence:
      case PlayMode.shuffle:
        // 顺序播放或随机播放：播放下一首
        _tryPlayNext();
        break;
    }
  }
  
  /// 尝试播放下一首
  Future<void> _tryPlayNext() async {
    if (_playlistManager.moveToNext()) {
      await _playCurrentSong();
    } else {
      Logger.info('播放列表结束', 'PlaybackController');
      await stop();
    }
  }
  
  /// 创建带播放链接的歌曲对象
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
    );
  }
  
  /// 更新系统媒体通知
  Future<void> _updateMediaItem(Song song) async {
    // 仅在移动端更新媒体通知
    if (PlatformUtils.isDesktop) {
      Logger.debug('🖥️ 桌面端，跳过媒体通知更新', 'PlaybackController');
      return;
    }
    
    try {
      final audioServiceManager = AudioServiceManager.instance;
      Logger.debug('🔍 检查 AudioService 可用性...', 'PlaybackController');
      
      if (audioServiceManager.isAvailable) {
        Logger.debug('✅ AudioService 可用，创建 MediaItem...', 'PlaybackController');
        
        final mediaItem = MediaItem(
          id: song.id,
          album: song.album,
          title: song.title,
          artist: song.artist,
          duration: song.duration != null ? Duration(seconds: song.duration!) : null,
          artUri: song.coverUrl.isNotEmpty ? Uri.parse(song.coverUrl) : null,
          extras: {
            'audioUrl': song.audioUrl,
            'platform': song.platform ?? 'unknown',
          },
        );
        
        Logger.debug('📱 MediaItem 创建完成: ${mediaItem.title} - ${mediaItem.artist}', 'PlaybackController');
        Logger.debug('🎨 封面URL: ${mediaItem.artUri}', 'PlaybackController');
        
        // 通过 AudioServiceManager 更新媒体项
        audioServiceManager.updateMediaItem(mediaItem);
        
        Logger.success('✅ 系统媒体通知已更新: ${song.title}', 'PlaybackController');
      } else {
        Logger.warning('⚠️ AudioService 不可用，跳过媒体通知更新', 'PlaybackController');
        Logger.debug('🔍 AudioService 状态: handler=${audioServiceManager.audioHandler != null}', 'PlaybackController');
      }
    } catch (e, stackTrace) {
      Logger.error('❌ 更新媒体通知失败', e, stackTrace, 'PlaybackController');
    }
  }
  
  /// 格式化时长显示
  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
  
  @override
  void dispose() {
    Logger.info('释放播放控制服务资源', 'PlaybackController');
    
    // 所有平台都需要取消订阅
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();

    // 仅桌面端需要释放本地播放器
    if (PlatformUtils.isDesktop) {
      _audioPlayer.dispose();
    }

    super.dispose();
  }
}
