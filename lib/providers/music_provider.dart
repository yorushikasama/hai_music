import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';
import '../models/song.dart';
import '../models/play_mode.dart';
import '../services/playlist_manager_service.dart';
import '../services/playback_controller_service.dart';
import '../services/song_url_service.dart';
import '../services/play_history_service.dart';
import '../services/favorite_manager_service.dart';
import '../services/preferences_service.dart';
import '../services/audio_service_manager.dart';
import '../utils/platform_utils.dart';
import '../utils/logger.dart';

/// 重构后的音乐播放器 Provider
/// 职责更加清晰，通过组合多个专门的服务来实现功能
class MusicProvider extends ChangeNotifier {
  // 核心服务
  late final PlaylistManagerService _playlistManager;
  late final PlaybackControllerService _playbackController;
  late final SongUrlService _urlService;
  final PlayHistoryService _historyService = PlayHistoryService();
  final FavoriteManagerService _favoriteManager = FavoriteManagerService();
  final PreferencesService _prefs = PreferencesService();
  
  // 收藏功能
  final Set<String> _favoriteSongIds = <String>{};
  final Set<String> _favoriteOperationInProgress = <String>{};
  
  // 订阅管理
  final List<StreamSubscription> _subscriptions = [];
  
  // 监听器函数引用
  late final VoidCallback _playlistListener;
  late final VoidCallback _playbackListener;
  
  MusicProvider() {
    _initializeServices();
    _loadFavorites();
  }
  
  /// 初始化服务
  void _initializeServices() {
    Logger.info('初始化 MusicProvider', 'MusicProvider');
    
    // 创建服务实例
    _playlistManager = PlaylistManagerService();
    _urlService = SongUrlService();
    _playbackController = PlaybackControllerService(
      playlistManager: _playlistManager,
      urlService: _urlService,
    );
    
    // 加载上次使用的播放模式
    try {
      final modeStr = _prefs.getPlayMode();
      PlayMode initialMode;
      switch (modeStr) {
        case 'single':
          initialMode = PlayMode.single;
          break;
        case 'shuffle':
          initialMode = PlayMode.shuffle;
          break;
        case 'sequence':
        default:
          initialMode = PlayMode.sequence;
          break;
      }
      // 通过 setPlayMode 统一恢复播放模式到 PlaylistManager 和 AudioHandler
      setPlayMode(initialMode);
      Logger.info('恢复播放模式: $initialMode', 'MusicProvider');
    } catch (e) {
      Logger.warning('读取播放模式失败，使用默认模式', 'MusicProvider');
    }
    
    // 监听服务变化
    _playlistListener = () {
      notifyListeners();
    };
    _playlistManager.addListener(_playlistListener);
    _restoreLastSession();

    _playbackListener = () {
      // 播放新歌曲时添加到历史记录
      final currentSong = _playbackController.currentPlayingSong;
      if (currentSong != null) {
        _historyService.addHistory(currentSong);
        _saveLastSession();
      }
      notifyListeners();
    };
    _playbackController.addListener(_playbackListener);
  }
  
  // ========== 播放列表相关 ==========
  
  /// 播放列表
  List<Song> get playlist => _playlistManager.playlist;
  
  /// 当前播放索引
  int get currentIndex => _playlistManager.currentIndex;
  
  /// 当前歌曲（播放列表中的）
  Song? get currentSong => _playlistManager.currentSong;
  
  /// 播放模式
  PlayMode get playMode => _playlistManager.playMode;
  
  /// 是否有上一首
  bool get hasPrevious => _playlistManager.hasPrevious;
  
  /// 是否有下一首
  bool get hasNext => _playlistManager.hasNext;
  
  /// 播放列表是否为空
  bool get isPlaylistEmpty => _playlistManager.isEmpty;
  
  // ========== 播放控制相关 ==========
  
  /// 是否正在播放
  bool get isPlaying => _playbackController.isPlaying;
  
  /// 是否正在加载
  bool get isLoading => _playbackController.isLoading;
  
  /// 当前播放位置
  Duration get currentPosition => _playbackController.currentPosition;
  
  /// 总时长
  Duration get totalDuration => _playbackController.totalDuration;
  
  /// 音量
  double get volume => _playbackController.volume;
  
  /// 播放速度
  double get speed => _playbackController.speed;
  
  /// 当前正在播放的歌曲（可能与播放列表中的不同，因为包含了播放链接）
  Song? get currentPlayingSong => _playbackController.currentPlayingSong;
  
  // ========== 服务访问器（兼容性） ==========
  
  FavoriteManagerService get favoriteManager => _favoriteManager;
  PlayHistoryService get historyService => _historyService;
  
  // 兼容性属性
  String get audioQuality => _prefs.getAudioQuality();
  
  // ========== 播放控制方法 ==========
  
  /// 播放歌曲列表
  Future<void> playSongs(List<Song> songs, {int startIndex = 0}) async {
    await _playbackController.playSongs(songs, startIndex: startIndex);
  }
  
  /// 播放单首歌曲
  Future<void> playSong(Song song, {List<Song>? playlist}) async {
    await _playbackController.playSong(song, playlist: playlist);
  }
  
  /// 更新当前播放列表（不改变当前播放的歌曲）
  Future<void> updatePlaylist(List<Song> songs) async {
    await _playbackController.updatePlaylist(songs);
  }
  
  /// 播放/暂停切换
  Future<void> togglePlayPause() async {
    await _playbackController.togglePlayPause();
  }
  
  /// 播放下一首
  Future<void> playNext() async {
    await _playbackController.playNext();
  }
  
  /// 播放上一首
  Future<void> playPrevious() async {
    await _playbackController.playPrevious();
  }
  
  /// 跳转到指定位置
  Future<void> seekTo(Duration position) async {
    await _playbackController.seekTo(position);
  }
  
  /// 跳转到指定位置（兼容性方法）
  Future<void> seek(Duration position) async {
    await seekTo(position);
  }
  
  /// 暂停播放（兼容性方法）
  Future<void> pause() async {
    if (isPlaying) {
      await togglePlayPause();
    }
  }

  /// 强制暂停播放（不依赖 isPlaying 状态），用于定时关闭等场景
  Future<void> forcePause() async {
    await _playbackController.pauseDirect();
  }
  
  /// 停止播放
  Future<void> stop() async {
    await _playbackController.stop();
  }
  
  /// 跳转到指定歌曲
  Future<void> jumpToSong(Song song) async {
    await _playbackController.jumpToSong(song);
  }
  
  /// 跳转到指定索引
  Future<void> jumpToIndex(int index) async {
    await _playbackController.jumpToIndex(index);
  }
  
  // ========== 播放列表管理 ==========
  
  /// 添加歌曲到播放列表
  Future<void> addToPlaylist(Song song) async {
    _playlistManager.addSong(song);
    
    // 预加载播放链接
    _urlService.getSongUrl(song).catchError((e) {
      Logger.warning('预加载播放链接失败: ${song.title}', 'MusicProvider');
    });
  }
  
  /// 从播放列表移除歌曲
  Future<void> removeFromPlaylist(int index) async {
    _playlistManager.removeSongAt(index);
  }
  
  /// 清空播放列表
  Future<void> clearPlaylist() async {
    _playlistManager.clearPlaylist();
    await _playbackController.stop();
  }
  
  /// 移动歌曲位置
  void moveSong(int oldIndex, int newIndex) {
    _playlistManager.moveSong(oldIndex, newIndex);
  }
  
  // ========== 播放模式控制 ==========
  
  /// 设置播放模式
  Future<void> setPlayMode(PlayMode mode) async {
    _playlistManager.setPlayMode(mode);
    Logger.info('设置播放模式: $mode', 'MusicProvider');
    
    // 持久化当前播放模式
    await _prefs.setPlayMode(mode.name);

    // 移动端：同步到 AudioHandler 的重复/随机模式，保证系统通知和自动切歌行为一致
    if (!PlatformUtils.isDesktop) {
      final handler = AudioServiceManager.instance.audioHandler;
      if (handler != null) {
        switch (mode) {
          case PlayMode.sequence:
            await handler.setRepeatMode(AudioServiceRepeatMode.none);
            await handler.setShuffleMode(AudioServiceShuffleMode.none);
            break;
          case PlayMode.single:
            await handler.setRepeatMode(AudioServiceRepeatMode.one);
            await handler.setShuffleMode(AudioServiceShuffleMode.none);
            break;
          case PlayMode.shuffle:
            await handler.setRepeatMode(AudioServiceRepeatMode.all);
            await handler.setShuffleMode(AudioServiceShuffleMode.all);
            break;
        }
      }
    }
  }
  
  /// 切换播放模式（兼容性方法）
  Future<void> togglePlayMode() async {
    // 通过 setPlayMode 统一处理内部状态和 AudioHandler 状态
    final newMode = _playlistManager.playMode.next;
    await setPlayMode(newMode);
  }
  
  // ========== 音频设置 ==========
  
  /// 设置音量
  Future<void> setVolume(double volume) async {
    await _playbackController.setVolume(volume);
  }
  
  /// 设置播放速度
  Future<void> setSpeed(double speed) async {
    await _playbackController.setSpeed(speed);
  }
  
  /// 设置音质
  Future<void> setAudioQuality(String quality) async {
    await _prefs.setAudioQuality(quality);
    Logger.info('设置音质: $quality', 'MusicProvider');
    notifyListeners();
  }
  
  // ========== 收藏功能 ==========
  
  /// 加载收藏列表
  void _loadFavorites() {
    final favorites = _prefs.getFavoriteSongs();
    _favoriteSongIds.clear();
    _favoriteSongIds.addAll(favorites);
    notifyListeners();
  }
  
  /// 刷新收藏列表
  void refreshFavorites() {
    _loadFavorites();
  }
  
  /// 检查歌曲是否已收藏
  bool isFavorite(String songId) {
    return _favoriteSongIds.contains(songId);
  }
  
  /// 检查是否正在处理收藏操作
  bool isFavoriteOperationInProgress(String songId) {
    return _favoriteOperationInProgress.contains(songId);
  }
  
  /// 切换收藏状态
  Future<bool> toggleFavorite(String songId) async {
    if (_favoriteOperationInProgress.contains(songId)) {
      Logger.warning('收藏操作正在进行中，请稍候...', 'MusicProvider');
      return false;
    }
    
    _favoriteOperationInProgress.add(songId);
    notifyListeners();
    
    try {
      if (_favoriteSongIds.contains(songId)) {
        // 取消收藏
        _favoriteSongIds.remove(songId);
        notifyListeners();
        
        final success = await _favoriteManager.removeFavorite(songId);
        if (success) {
          await _prefs.setFavoriteSongs(_favoriteSongIds.toList());
          Logger.success('取消收藏成功', 'MusicProvider');
          return true;
        } else {
          _favoriteSongIds.add(songId);
          notifyListeners();
          return false;
        }
      } else {
        // 添加收藏
        Song? song = currentSong;
        if (song?.id == songId) {
          // 使用当前歌曲
        } else {
          // 在播放列表中查找
          try {
            song = playlist.firstWhere((s) => s.id == songId);
          } catch (e) {
            Logger.error('找不到要收藏的歌曲: $songId', null, null, 'MusicProvider');
            return false;
          }
        }
        
        if (song == null) {
          Logger.error('无法找到歌曲对象，无法添加收藏', null, null, 'MusicProvider');
          return false;
        }
        
        _favoriteSongIds.add(songId);
        notifyListeners();
        
        final success = await _favoriteManager.addFavorite(song);
        if (success) {
          await _prefs.setFavoriteSongs(_favoriteSongIds.toList());
          Logger.success('添加收藏成功', 'MusicProvider');
          return true;
        } else {
          _favoriteSongIds.remove(songId);
          notifyListeners();
          return false;
        }
      }
    } catch (e) {
      Logger.error('收藏操作异常', e, null, 'MusicProvider');
      return false;
    } finally {
      _favoriteOperationInProgress.remove(songId);
      notifyListeners();
    }
  }

  // ========== 工具方法 ========== 
  
  void _saveLastSession() {
    try {
      if (_playlistManager.isEmpty) {
        _prefs.clearLastSession();
        Logger.debug('🧷 [Session] 播放列表为空，清除上次播放会话', 'MusicProvider');
        return;
      }
      
      // 根据当前正在播放的歌曲来确定索引，避免索引不同步导致总是记录第一首
      final current = _playbackController.currentPlayingSong ?? _playlistManager.currentSong;
      int currentIndex = 0;
      if (current != null) {
        final idx = _playlistManager.playlist.indexWhere((s) => s.id == current.id);
        if (idx >= 0) {
          currentIndex = idx;
        }
      }

      Logger.debug(
        '🧷 [Session] 准备保存会话: currentId=${current?.id}, playlistLen=${_playlistManager.length}, index=$currentIndex, position=${_playbackController.currentPosition.inSeconds}s',
        'MusicProvider',
      );

      final session = {
        'playlist': _playlistManager.playlist.map((s) => s.toJson()).toList(),
        'currentIndex': currentIndex,
        'position': _playbackController.currentPosition.inSeconds,
      };

      final jsonStr = jsonEncode(session);
      _prefs.setLastSession(jsonStr);

      final preview = jsonStr.length > 200 ? jsonStr.substring(0, 200) + '...' : jsonStr;
      Logger.debug(
        '🧷 [Session] 已保存会话: jsonLen=${jsonStr.length}, preview=$preview',
        'MusicProvider',
      );
    } catch (e) {
      Logger.error('保存上次播放会话失败', e, null, 'MusicProvider');
    }
  }

  void _restoreLastSession() {
    try {
      final sessionStr = _prefs.getLastSession();
      if (sessionStr.isEmpty) {
        Logger.debug('🧷 [Session] 本地没有上次播放会话', 'MusicProvider');
        return;
      }

      Logger.debug(
        '🧷 [Session] 读取到会话字符串，长度=${sessionStr.length}',
        'MusicProvider',
      );

      final decoded = jsonDecode(sessionStr);
      if (decoded is! Map<String, dynamic>) {
        Logger.warning('🧷 [Session] 会话 JSON 不是 Map<String, dynamic>', 'MusicProvider');
        return;
      }

      final playlistData = decoded['playlist'];
      if (playlistData is! List) {
        Logger.warning('🧷 [Session] 会话中 playlist 字段不是 List', 'MusicProvider');
        return;
      }

      final songs = playlistData
          .whereType<Map<String, dynamic>>()
          .map((e) => Song.fromJson(e))
          .toList();
      if (songs.isEmpty) {
        Logger.warning('🧷 [Session] 会话中 playlist 解析后为空', 'MusicProvider');
        return;
      }

      final indexValue = decoded['currentIndex'];
      int startIndex = 0;
      if (indexValue is int) {
        startIndex = indexValue;
      }
      if (startIndex < 0 || startIndex >= songs.length) {
        startIndex = 0;
      }

      // 解析上次播放位置（秒）
      int positionSeconds = 0;
      final positionValue = decoded['position'];
      if (positionValue is int && positionValue > 0) {
        positionSeconds = positionValue;
      }

      _playlistManager.setPlaylist(songs, startIndex: startIndex);

      // 移动端：同步到 AudioHandler 的播放列表，但不自动播放，仅恢复索引和上次进度
      if (!PlatformUtils.isDesktop) {
        final handler = AudioServiceManager.instance.audioHandler;
        if (handler != null) {
          final initialPosition = Duration(seconds: positionSeconds);
          Logger.debug(
            '🧷 [Session] 同步到 AudioHandler: startIndex=$startIndex, position=${initialPosition.inSeconds}s',
            'MusicProvider',
          );
          handler.updatePlaylist(
            songs,
            initialIndex: startIndex,
            initialPosition: initialPosition,
          );
        }
      }

      Logger.info('恢复上次播放会话: ${songs.length} 首歌曲，索引: $startIndex, 位置: ${positionSeconds}s', 'MusicProvider');
      Logger.debug(
        '🧷 [Session] 恢复后 PlaylistManager 状态: ${_playlistManager.getPlaylistInfo()}',
        'MusicProvider',
      );
    } catch (e) {
      Logger.error('恢复上次播放会话失败', e, null, 'MusicProvider');
    }
  }
  
  /// 格式化时长显示
  String formatDuration(Duration duration) {
    return _playbackController.formatDuration(duration);
  }
  
  /// 预加载播放列表的播放链接
  Future<void> preloadPlaylistUrls() async {
    if (playlist.isNotEmpty) {
      await _urlService.preloadUrls(playlist);
    }
  }
  
  /// 获取播放器状态信息
  Map<String, dynamic> getPlayerState() {
    return {
      'isPlaying': isPlaying,
      'isLoading': isLoading,
      'currentPosition': currentPosition.inSeconds,
      'totalDuration': totalDuration.inSeconds,
      'volume': volume,
      'speed': speed,
      'playMode': playMode.toString(),
      'playlistInfo': _playlistManager.getPlaylistInfo(),
      'cacheStats': _urlService.getCacheStats(),
    };
  }
  
  // ========== 资源清理 ==========
  
  @override
  void dispose() {
    Logger.info('释放 MusicProvider 资源', 'MusicProvider');
    
    // 取消所有订阅
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    
    // 移除监听器
    _playlistManager.removeListener(_playlistListener);
    _playbackController.removeListener(_playbackListener);
    
    // 释放服务资源
    _playbackController.dispose();
    _playlistManager.dispose();
    _urlService.clearAllCache();
    
    super.dispose();
  }
}
