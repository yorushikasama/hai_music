import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:audio_service/audio_service.dart';
import '../models/song.dart';
import '../models/play_mode.dart';
import '../models/audio_quality.dart';
import '../services/music_api_service.dart';
import '../services/audio_handler_service.dart';
import '../services/play_history_service.dart';
import '../services/favorite_manager_service.dart';
import '../services/sleep_timer_service.dart';
import '../services/preferences_service.dart';
import '../utils/platform_utils.dart';
import '../config/app_constants.dart';

class MusicProvider with ChangeNotifier {
  // 🔧 优化:添加调试日志开关,生产环境可关闭以提升性能
  static const bool _enableDebugLog = true;

  // 根据平台选择播放器
  // Windows: audioplayers (稳定)
  // Android/iOS: audio_service + just_audio (支持后台播放)
  MusicAudioHandler? _audioHandler;
  AudioPlayer? _audioPlayer;
  final MusicApiService _apiService = MusicApiService();
  final PreferencesService _prefs = PreferencesService();
  final FavoriteManagerService _favoriteManager = FavoriteManagerService();
  final PlayHistoryService _historyService = PlayHistoryService();
  final SleepTimerService _sleepTimer = SleepTimerService();

  // 🔧 优化:Stream 订阅管理,防止内存泄漏
  final List<StreamSubscription> _subscriptions = [];
  
  Song? _currentSong;
  List<Song> _playlist = [];
  int _currentIndex = 0;
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  DateTime? _lastPositionNotifyTime; // 上次通知位置更新的时间
  bool _isLoading = false;
  AudioQuality _audioQuality = AudioQuality.high; // 默认HQ高音质
  PlayMode _playMode = PlayMode.sequence; // 默认顺序播放
  final Random _random = Random();
  double _volume = 1.0; // 音量 0.0 - 1.0
  final Set<String> _favoriteSongIds = {}; // 收藏的歌曲ID集合
  int _playRequestVersion = 0; // 播放请求版本号，用于防止竞态条件
  int _consecutiveFailures = 0; // 连续失败次数
  final Set<String> _favoriteOperationInProgress = {}; // 正在处理的收藏操作
  bool _audioHandlerInitialized = false; // AudioHandler 是否已初始化
  
  // 伪随机播放队列
  List<int> _shuffleQueue = []; // 随机播放的索引队列
  int _shuffleQueueIndex = 0; // 当前在随机队列中的位置
  
  // URL缓存（内存缓存，应用重启后清空）
  final Map<String, String> _urlCache = {};
  final Map<String, DateTime> _urlCacheTimestamp = {};
  static const int _urlCacheExpiryMinutes = 60; // URL缓存1小时过期
  static const int _maxUrlCacheSize = 100; // 最多缓存100个URL

  MusicProvider() {
    _initPlayer();
    _loadSettings();
    _loadFavorites();
    _initFavoriteManager();
  }

  /// 🔧 优化:统一的日志输出方法
  /// 生产环境可通过 _enableDebugLog 开关关闭
  void _log(String message) {
    if (_enableDebugLog) {
      print(message);
    }
  }

  /// 初始化播放器（根据平台选择）
  Future<void> _initPlayer() async {
    if (PlatformUtils.isWindows) {
      _initAudioPlayer();
    } else {
      await _initAudioHandler();
    }
  }

  /// 初始化 audioplayers (Windows)
  void _initAudioPlayer() {
    _audioPlayer = AudioPlayer();
    _audioHandlerInitialized = true;

    // 🔧 优化:保存订阅以便后续取消,防止内存泄漏
    // 监听播放状态
    _subscriptions.add(_audioPlayer!.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;
      notifyListeners();
    }));

    // 监听播放进度（限制更新频率为每500ms）
    _subscriptions.add(_audioPlayer!.onPositionChanged.listen((position) {
      _currentPosition = position;

      final now = DateTime.now();
      if (_lastPositionNotifyTime == null ||
          now.difference(_lastPositionNotifyTime!).inMilliseconds >= 500) {
        _lastPositionNotifyTime = now;
        notifyListeners();
      }
    }));

    // 监听总时长
    _subscriptions.add(_audioPlayer!.onDurationChanged.listen((duration) {
      _totalDuration = duration;
      notifyListeners();
    }));

    // 监听播放完成
    _subscriptions.add(_audioPlayer!.onPlayerComplete.listen((_) {
      _handlePlayComplete();
    }));
  }

  /// 初始化 audio_service (Android/iOS)
  Future<void> _initAudioHandler() async {
    try {
      // 检查是否已经初始化过
      if (_audioHandlerInitialized && _audioHandler != null) {
        return;
      }
      
      // 只初始化一次
      _audioHandler = await AudioService.init(
        builder: () => MusicAudioHandler(),
        config: AudioServiceConfig(
          androidNotificationChannelId: 'com.haimusic.audio',
          androidNotificationChannelName: 'Hai Music',
          // 🔧 设置为 true：播放时通知不可滑动删除，防止用户误删
          androidNotificationOngoing: true,
          // 🔧 修复：设置为 false 防止切歌时通知消失
          // 当设置为 true 时，切歌过程中的短暂暂停会导致前台服务停止，通知被移除
          androidStopForegroundOnPause: false,
        ),
      );
      _audioHandlerInitialized = true;
      
      // 设置播放完成回调（只设置一次）
      if (_audioHandler is MusicAudioHandler) {
        final handler = _audioHandler as MusicAudioHandler;
        handler.onPlaybackCompleted = () {
          _handlePlayComplete();
        };

        // 设置系统通知栏按钮回调
        handler.onSkipToNext = () {
          _log('🔔 [MusicProvider] 系统通知栏触发：下一首');
          playNext();
        };

        handler.onSkipToPrevious = () {
          _log('🔔 [MusicProvider] 系统通知栏触发：上一首');
          playPrevious();
        };
      }
      
      // 🔧 优化:保存订阅以便后续取消,防止内存泄漏
      // 监听播放状态
      _subscriptions.add(_audioHandler!.playbackState.listen((state) {
        _isPlaying = state.playing;
        notifyListeners();
      }));

      // 监听当前媒体项
      _subscriptions.add(_audioHandler!.mediaItem.listen((item) {
        if (item != null) {
          _updateCurrentSongFromMediaItem(item);
        }
      }));

      // 监听播放位置（定期更新，限制通知频率）
      _subscriptions.add(Stream.periodic(const Duration(milliseconds: 500)).listen((_) {
        if (_audioHandler != null) {
          _currentPosition = _audioHandler!.position;
          _totalDuration = _audioHandler!.duration ?? Duration.zero;
          notifyListeners();
        }
      }));
    } catch (e, stackTrace) {
      print('❌ AudioService 初始化失败: $e');
      print('❌ 堆栈跟踪: $stackTrace');
      _audioHandlerInitialized = false;
    }
  }

  /// 生成随机播放队列
  void _generateShuffleQueue() {
    if (_playlist.isEmpty) return;
    
    // 生成0到playlist.length-1的索引列表
    _shuffleQueue = List.generate(_playlist.length, (index) => index);
    
    // 打乱队列
    _shuffleQueue.shuffle(_random);
    
    // 如果当前歌曲在队列中，将其移到第一位
    if (_currentIndex >= 0 && _currentIndex < _playlist.length) {
      final currentPos = _shuffleQueue.indexOf(_currentIndex);
      if (currentPos > 0) {
        _shuffleQueue.removeAt(currentPos);
        _shuffleQueue.insert(0, _currentIndex);
      }
    }
    
    _shuffleQueueIndex = 0;
  }

  /// 处理播放完成
  void _handlePlayComplete() async {
    _log('🎬 [MusicProvider] 播放完成: ${_currentSong?.title}, 当前位置: $_currentPosition, 总时长: $_totalDuration');
    
    _isPlaying = false;
    notifyListeners();
    
    switch (_playMode) {
      case PlayMode.single:
        // 单曲循环：seek到开头继续播放
        if (_currentSong != null) {
          _log('🔁 [MusicProvider] 单曲循环，重新播放');
          if (PlatformUtils.isWindows) {
            await _audioPlayer?.seek(Duration.zero);
            await _audioPlayer?.resume();
          } else {
            await _audioHandler?.seek(Duration.zero);
            await _audioHandler?.play();
          }
        }
        break;
      case PlayMode.sequence:
      case PlayMode.shuffle:
        _log('⏭️ [MusicProvider] 自动播放下一首');
        playNext(autoSkip: true);
        break;
    }
  }

  /// 获取歌曲播放URL（带缓存）
  Future<String?> _getSongUrl(Song song) async {
    // 优先使用直链
    if (song.audioUrl.isNotEmpty && song.audioUrl.startsWith('http')) {
      return song.audioUrl;
    }

    // 检查缓存
    if (_urlCache.containsKey(song.id)) {
      final timestamp = _urlCacheTimestamp[song.id];
      if (timestamp != null) {
        final age = DateTime.now().difference(timestamp).inMinutes;
        if (age < _urlCacheExpiryMinutes) {
          return _urlCache[song.id];
        } else {
          _urlCache.remove(song.id);
          _urlCacheTimestamp.remove(song.id);
        }
      }
    }

    // 从API获取
    final url = await _apiService.getSongUrl(
      songId: song.id,
      quality: _audioQuality.value,
    ).timeout(
      const Duration(seconds: AppConstants.playUrlTimeout),
      onTimeout: () => null,
    );

    // 🔧 优化:保存到缓存
    if (url != null && url.isNotEmpty) {
      // 如果缓存已满，移除最旧的条目
      if (_urlCache.length >= _maxUrlCacheSize) {
        _removeOldestCacheEntry();
      }

      _urlCache[song.id] = url;
      _urlCacheTimestamp[song.id] = DateTime.now();
    }

    return url;
  }

  /// 🔧 优化:移除最旧的缓存条目
  void _removeOldestCacheEntry() {
    if (_urlCacheTimestamp.isEmpty) return;

    // 找到最旧的条目
    final oldestEntry = _urlCacheTimestamp.entries.reduce(
      (a, b) => a.value.isBefore(b.value) ? a : b
    );

    _urlCache.remove(oldestEntry.key);
    _urlCacheTimestamp.remove(oldestEntry.key);
  }

  /// 创建带URL的Song副本
  Song _createSongWithUrl(Song song, String url) {
    return Song(
      id: song.id,
      title: song.title,
      artist: song.artist,
      album: song.album,
      coverUrl: song.coverUrl,
      r2CoverUrl: song.r2CoverUrl,
      audioUrl: url,
      duration: song.duration,
      lyricsLrc: song.lyricsLrc,
    );
  }

  /// 🔧 优化:预加载下一首歌曲的URL
  /// 添加错误处理,防止预加载失败影响播放
  void _preloadNextSong() async {
    if (_playlist.isEmpty) return;

    try {
      // 🔧 修复：记录当前播放请求版本，防止预加载过时数据
      final preloadVersion = _playRequestVersion;
      
      // 计算下一首的索引（考虑播放模式）
      int nextIndex;
      if (_playMode == PlayMode.shuffle && _playlist.length > 1) {
        // 随机播放：使用随机队列
        if (_shuffleQueue.isEmpty || _shuffleQueue.length != _playlist.length) {
          return; // 随机队列未初始化，跳过预加载
        }
        final nextQueueIndex = (_shuffleQueueIndex + 1) % _shuffleQueue.length;
        nextIndex = _shuffleQueue[nextQueueIndex];
      } else {
        // 顺序播放
        nextIndex = (_currentIndex + 1) % _playlist.length;
      }

      if (nextIndex < 0 || nextIndex >= _playlist.length) return;

      final nextSong = _playlist[nextIndex];

      // 如果下一首已经有URL或在缓存中，跳过
      if (nextSong.audioUrl.isNotEmpty && nextSong.audioUrl.startsWith('http')) {
        return;
      }

      if (_urlCache.containsKey(nextSong.id)) {
        final timestamp = _urlCacheTimestamp[nextSong.id];
        if (timestamp != null) {
          final age = DateTime.now().difference(timestamp).inMinutes;
          if (age < _urlCacheExpiryMinutes) {
            return; // 缓存仍然有效
          }
        }
      }

      // 后台获取下一首的URL
      final url = await _getSongUrl(nextSong);

      // 🔧 修复：检查版本号，如果用户已经切歌，放弃更新
      if (preloadVersion != _playRequestVersion) {
        _log('⚠️ [预加载] 播放列表已变化，放弃预加载结果');
        return;
      }

      if (url != null && url.isNotEmpty) {
        // 再次检查索引是否仍然有效（播放列表可能已改变）
        if (nextIndex < _playlist.length && _playlist[nextIndex].id == nextSong.id) {
          _playlist[nextIndex] = _createSongWithUrl(nextSong, url);
          _log('✅ [预加载] 成功预加载: ${nextSong.title}');
        }
      }
    } catch (e) {
      // 🔧 优化:预加载失败不影响播放,只记录日志
      _log('⚠️ [预加载] 预加载失败: $e');
    }
  }

  /// 从 MediaItem 更新当前歌曲
  void _updateCurrentSongFromMediaItem(MediaItem item) {
    // 从播放列表中找到对应的歌曲
    final song = _playlist.firstWhere(
      (s) => s.id == item.id,
      orElse: () => Song(
        id: item.id,
        title: item.title,
        artist: item.artist ?? '',
        album: item.album ?? '',
        coverUrl: item.extras?['coverUrl'] as String? ?? '',
        r2CoverUrl: item.extras?['r2CoverUrl'] as String?,
        audioUrl: item.extras?['audioUrl'] as String? ?? '',
        duration: item.duration?.inSeconds,
      ),
    );
    
    if (_currentSong?.id != song.id) {
      _currentSong = song;
      _currentIndex = _playlist.indexWhere((s) => s.id == song.id);
      notifyListeners();
    }
  }

  // 初始化收藏管理服务
  void _initFavoriteManager() async {
    await _favoriteManager.initialize();
  }

  // 从本地加载设置
  void _loadSettings() async {
    _volume = _prefs.getVolume();

    // 🔧 修复:同时设置 AudioPlayer (Windows) 和 AudioHandler (移动平台) 的音量
    if (_audioPlayer != null) {
      await _audioPlayer!.setVolume(_volume);
    }
    if (_audioHandler != null) {
      await _audioHandler!.setVolume(_volume);
    }

    final modeStr = _prefs.getPlayMode();
    _playMode = _parsePlayMode(modeStr);
    _applyPlayMode();

    final qualityStr = _prefs.getAudioQuality();
    _audioQuality = _parseAudioQuality(qualityStr);

    notifyListeners();
  }

  /// 应用播放模式到 AudioHandler
  void _applyPlayMode() async {
    if (_audioHandler == null) return;
    
    // 注意：我们手动管理播放模式，不使用AudioHandler的内置模式
    // 所以这里禁用AudioHandler的内置repeat和shuffle
    await _audioHandler!.setRepeatMode(AudioServiceRepeatMode.none);
    await _audioHandler!.setShuffleMode(AudioServiceShuffleMode.none);
  }

  PlayMode _parsePlayMode(String mode) {
    switch (mode) {
      case 'single':
        return PlayMode.single;
      case 'shuffle':
        return PlayMode.shuffle;
      default:
        return PlayMode.sequence;
    }
  }

  AudioQuality _parseAudioQuality(String quality) {
    switch (quality) {
      case 'standard':
        return AudioQuality.standard;
      case 'high':
        return AudioQuality.high;
      case 'lossless':
        return AudioQuality.lossless;
      default:
        return AudioQuality.high;
    }
  }


  Song? get currentSong => _currentSong;
  List<Song> get playlist => _playlist;
  int get currentIndex => _currentIndex;
  bool get isPlaying => _isPlaying;
  Duration get currentPosition => _currentPosition;
  Duration get totalDuration => _totalDuration;
  AudioQuality get audioQuality => _audioQuality;
  PlayMode get playMode => _playMode;
  double get volume => _volume;

  /// 🔧 优化:设置播放列表和索引
  /// 提取公共逻辑,减少代码重复
  void _setupPlaylist(Song song, List<Song>? playlist) {
    if (playlist != null && playlist.isNotEmpty) {
      _playlist = playlist;
      _currentIndex = playlist.indexWhere((s) => s.id == song.id);
      if (_currentIndex < 0) _currentIndex = 0;

      // 如果是随机播放模式，生成新的随机队列
      if (_playMode == PlayMode.shuffle) {
        _generateShuffleQueue();
      }
    } else {
      _playlist = [song];
      _currentIndex = 0;
      _shuffleQueue.clear(); // 单曲播放，清空随机队列
    }
  }

  void playSong(Song song, {List<Song>? playlist, bool autoSkipOnError = false}) async {
    if (PlatformUtils.isWindows) {
      // Windows 平台使用 audioplayers
      await _playSongWithAudioPlayer(song, playlist: playlist, autoSkipOnError: autoSkipOnError);
    } else {
      // 移动平台使用 audio_service
      await _playSongWithAudioService(song, playlist: playlist, autoSkipOnError: autoSkipOnError);
    }
  }

  /// 使用 audioplayers 播放 (Windows)
  Future<void> _playSongWithAudioPlayer(Song song, {List<Song>? playlist, bool autoSkipOnError = false}) async {
    _playRequestVersion++;
    final currentVersion = _playRequestVersion;

    _isLoading = true;
    notifyListeners();

    try {
      // 🔧 优化:使用提取的公共方法设置播放列表
      _setupPlaylist(song, playlist);

      // 获取当前歌曲的播放链接（使用缓存）
      final audioUrl = await _getSongUrl(song);

      if (currentVersion != _playRequestVersion) {
        return;
      }

      if (audioUrl == null || audioUrl.isEmpty) {
        print('❌ 获取播放链接失败: ${song.title}');
        _consecutiveFailures++;
        
        // 🔧 修复：只在自动播放时才自动跳过，用户主动点击时不跳过
        if (autoSkipOnError && _consecutiveFailures < AppConstants.maxConsecutiveFailures) {
          print('⏭️ [MusicProvider] 自动跳过失败歌曲,尝试下一首 (自动播放模式)');
          Future.delayed(const Duration(milliseconds: 500), () => playNext(autoSkip: true));
        } else {
          print('⚠️ [MusicProvider] 播放失败，停止播放（用户主动点击）');
          _isLoading = false;
          notifyListeners();
        }
        return;
      }

      // 更新当前歌曲（带URL）
      _currentSong = _createSongWithUrl(song, audioUrl);
      
      // 更新播放列表中的当前歌曲
      _playlist[_currentIndex] = _currentSong!;
      
      // 刷新收藏状态并立即通知监听器
      refreshFavorites();
      notifyListeners();

      // 🔧 修复：在停止播放之前检查版本号，避免影响新的播放请求
      if (currentVersion != _playRequestVersion) {
        print('⚠️ [MusicProvider] 播放请求已过期（停止前），取消操作');
        return;
      }

      // Windows: 使用 audioplayers 播放
      await _audioPlayer!.stop();
      
      // 🔧 修复：在调用 play() 之前再次检查版本号，防止快速切歌时播放旧歌曲
      if (currentVersion != _playRequestVersion) {
        print('⚠️ [MusicProvider] 播放请求已过期（播放前），取消播放');
        return;
      }
      
      await _audioPlayer!.play(UrlSource(_currentSong!.audioUrl));
      
      _consecutiveFailures = 0;
      _historyService.addHistory(_currentSong!);
      
      // 预加载下一首歌曲
      _preloadNextSong();
    } catch (e) {
      print('❌ 播放出错: $e');
      _consecutiveFailures++;
      
      if (autoSkipOnError && currentVersion == _playRequestVersion && 
          _consecutiveFailures < AppConstants.maxConsecutiveFailures) {
        Future.delayed(const Duration(milliseconds: 500), () => playNext(autoSkip: true));
      }
    } finally {
      if (currentVersion == _playRequestVersion) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// 使用 audio_service 播放 (Android/iOS)
  Future<void> _playSongWithAudioService(Song song, {List<Song>? playlist, bool autoSkipOnError = false}) async {
    // 确保 AudioHandler 已初始化
    if (_audioHandler == null) {
      await _initAudioHandler();
      if (_audioHandler == null) {
        _log('❌ AudioHandler 初始化失败');
        return;
      }
    }

    _playRequestVersion++;
    final currentVersion = _playRequestVersion;

    _isLoading = true;
    notifyListeners();

    try {
      // 设置播放列表
      _setupPlaylist(song, playlist);

      // 获取播放链接
      final audioUrl = await _getSongUrl(song);

      if (currentVersion != _playRequestVersion) {
        _log('⚠️ 播放请求已过期');
        return;
      }
      
      if (audioUrl == null || audioUrl.isEmpty) {
        _log('❌ 获取播放链接失败: ${song.title}');
        _consecutiveFailures++;

        if (autoSkipOnError && _consecutiveFailures < AppConstants.maxConsecutiveFailures) {
          _log('⏭️ 自动跳过失败歌曲');
          Future.delayed(const Duration(milliseconds: 500), () => playNext(autoSkip: true));
        } else {
          _isLoading = false;
          notifyListeners();
        }
        return;
      }

      // 更新当前歌曲
      _currentSong = _createSongWithUrl(song, audioUrl);
      _playlist[_currentIndex] = _currentSong!;
      
      refreshFavorites();
      notifyListeners();

      if (currentVersion != _playRequestVersion) {
        _log('⚠️ 播放请求已过期（播放前）');
        return;
      }

      // 🔧 新架构：直接播放单首歌曲
      await _audioHandler!.playSingleSong(_currentSong!, displayQueue: _playlist);

      _consecutiveFailures = 0;
      _historyService.addHistory(_currentSong!);

      // 预加载下一首
      _preloadNextSong();
    } catch (e) {
      _log('❌ 播放出错: $e');
      _consecutiveFailures++;
    } finally {
      if (currentVersion == _playRequestVersion) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void togglePlayPause() async {
    if (PlatformUtils.isWindows) {
      if (_audioPlayer == null) return;
      if (_isPlaying) {
        await _audioPlayer!.pause();
      } else {
        await _audioPlayer!.resume();
      }
    } else {
      if (_audioHandler == null) return;
      if (_isPlaying) {
        await _audioHandler!.pause();
      } else {
        await _audioHandler!.play();
      }
    }
  }

  void pause() async {
    if (PlatformUtils.isWindows) {
      if (_audioPlayer == null) return;
      await _audioPlayer!.pause();
    } else {
      if (_audioHandler == null) return;
      await _audioHandler!.pause();
    }
  }

  void play() async {
    if (PlatformUtils.isWindows) {
      if (_audioPlayer == null) return;
      await _audioPlayer!.resume();
    } else {
      if (_audioHandler == null) return;
      await _audioHandler!.play();
    }
  }

  void playNext({bool autoSkip = false}) async {
    if (_playlist.isEmpty) {
      _log('⚠️ [MusicProvider] playNext: 播放列表为空');
      return;
    }

    // 🔧 防抖：如果正在加载，忽略快速点击
    if (_isLoading && !autoSkip) {
      _log('⚠️ [MusicProvider] 正在加载，忽略快速点击');
      return;
    }

    _log('⏭️ [MusicProvider] playNext: 当前索引=$_currentIndex, 列表长度=${_playlist.length}, 模式=$_playMode');

    // 计算下一首的索引
    int nextIndex;
    if (_playMode == PlayMode.shuffle && _playlist.length > 1) {
      // 随机播放：使用伪随机队列
      if (_shuffleQueue.isEmpty || _shuffleQueue.length != _playlist.length) {
        _generateShuffleQueue();
      }

      // 移动到队列中的下一首
      _shuffleQueueIndex = (_shuffleQueueIndex + 1) % _shuffleQueue.length;
      nextIndex = _shuffleQueue[_shuffleQueueIndex];

      // 如果播放完整个随机队列，重新生成
      if (_shuffleQueueIndex == 0) {
        _generateShuffleQueue();
      }
    } else {
      // 顺序播放
      nextIndex = (_currentIndex + 1) % _playlist.length;
    }

    _log('✅ [MusicProvider] playNext: 下一首索引=$nextIndex, 歌曲=${_playlist[nextIndex].title}');
    
    // 🔧 优化：直接切歌，不重建队列
    await _switchToSong(nextIndex, autoSkipOnError: autoSkip);
  }

  void playPrevious({bool autoSkip = false}) async {
    if (_playlist.isEmpty) {
      _log('⚠️ [MusicProvider] playPrevious: 播放列表为空');
      return;
    }

    // 🔧 防抖：如果正在加载，忽略快速点击
    if (_isLoading && !autoSkip) {
      _log('⚠️ [MusicProvider] 正在加载，忽略快速点击');
      return;
    }

    _log('⏮️ [MusicProvider] playPrevious: 当前索引=$_currentIndex, 列表长度=${_playlist.length}, 模式=$_playMode');

    // 计算上一首的索引
    int prevIndex;
    if (_playMode == PlayMode.shuffle && _playlist.length > 1) {
      // 随机播放：在随机队列中后退
      if (_shuffleQueue.isEmpty || _shuffleQueue.length != _playlist.length) {
        _generateShuffleQueue();
      }

      _shuffleQueueIndex = (_shuffleQueueIndex - 1 + _shuffleQueue.length) % _shuffleQueue.length;
      prevIndex = _shuffleQueue[_shuffleQueueIndex];
    } else {
      // 顺序播放
      prevIndex = (_currentIndex - 1 + _playlist.length) % _playlist.length;
    }

    _log('✅ [MusicProvider] playPrevious: 上一首索引=$prevIndex, 歌曲=${_playlist[prevIndex].title}');
    
    // 🔧 优化：直接切歌，不重建队列
    await _switchToSong(prevIndex, autoSkipOnError: autoSkip);
  }

  /// 🔧 优化：快速切歌
  Future<void> _switchToSong(int targetIndex, {bool autoSkipOnError = false}) async {
    if (targetIndex < 0 || targetIndex >= _playlist.length) {
      _log('❌ 索引越界: $targetIndex');
      return;
    }

    _playRequestVersion++;
    final currentVersion = _playRequestVersion;

    _isLoading = true;
    notifyListeners();

    try {
      final targetSong = _playlist[targetIndex];
      _log('🔄 切歌: ${targetSong.title}');
      
      // 获取播放链接
      final audioUrl = await _getSongUrl(targetSong);

      if (currentVersion != _playRequestVersion) {
        _log('⚠️ 请求已过期');
        return;
      }

      if (audioUrl == null || audioUrl.isEmpty) {
        _log('❌ 获取URL失败: ${targetSong.title}');
        _consecutiveFailures++;

        if (autoSkipOnError && _consecutiveFailures < AppConstants.maxConsecutiveFailures) {
          _log('⏭️ 自动跳过失败歌曲');
          Future.delayed(const Duration(milliseconds: 500), () => playNext(autoSkip: true));
        } else {
          _isLoading = false;
          notifyListeners();
        }
        return;
      }

      // 更新当前歌曲
      _currentIndex = targetIndex;
      _currentSong = _createSongWithUrl(targetSong, audioUrl);
      _playlist[_currentIndex] = _currentSong!;

      refreshFavorites();
      notifyListeners();

      if (currentVersion != _playRequestVersion) {
        _log('⚠️ 播放前请求已过期');
        return;
      }

      // 🔧 新架构：直接播放
      if (PlatformUtils.isWindows) {
        await _audioPlayer!.stop();
        if (currentVersion != _playRequestVersion) return;
        await _audioPlayer!.play(UrlSource(_currentSong!.audioUrl));
      } else {
        await _audioHandler!.playSingleSong(_currentSong!, displayQueue: _playlist);
      }

      _consecutiveFailures = 0;
      _historyService.addHistory(_currentSong!);

      // 预加载下一首
      _preloadNextSong();
    } catch (e) {
      _log('❌ 切歌失败: $e');
      _consecutiveFailures++;

      if (autoSkipOnError && currentVersion == _playRequestVersion &&
          _consecutiveFailures < AppConstants.maxConsecutiveFailures) {
        Future.delayed(const Duration(milliseconds: 500), () => playNext(autoSkip: true));
      }
    } finally {
      if (currentVersion == _playRequestVersion) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void seekTo(Duration position) async {
    if (PlatformUtils.isWindows) {
      if (_audioPlayer == null) return;
      await _audioPlayer!.seek(position);
    } else {
      if (_audioHandler == null) return;
      await _audioHandler!.seek(position);
    }
  }

  /// 🔧 快捷键支持:跳转到指定位置
  /// 别名方法,方便快捷键调用
  void seek(Duration position) {
    seekTo(position);
  }



  void updatePosition(Duration position) {
    _currentPosition = position;
    notifyListeners();
  }

  void togglePlayMode() async {
    _playMode = _playMode.next;
    await _prefs.setPlayMode(_playMode.toString().split('.').last);
    _applyPlayMode();

    // 切换到随机播放时，生成随机队列
    if (_playMode == PlayMode.shuffle) {
      _generateShuffleQueue();
    }

    notifyListeners();
  }

  void setPlayMode(PlayMode mode) async {
    _playMode = mode;
    await _prefs.setPlayMode(_playMode.toString().split('.').last);
    _applyPlayMode();
    
    // 切换到随机播放时，生成随机队列
    if (_playMode == PlayMode.shuffle) {
      _generateShuffleQueue();
    }
    
    notifyListeners();
  }

  /// 从播放列表移除歌曲
  void removeFromPlaylist(int index) async {
    if (_audioHandler == null || index < 0 || index >= _playlist.length) return;
    
    await _audioHandler!.removeQueueItemAt(index);
    _playlist.removeAt(index);
    
    // 如果是随机播放模式，重新生成随机队列
    if (_playMode == PlayMode.shuffle && _playlist.isNotEmpty) {
      _generateShuffleQueue();
    } else if (_playlist.isEmpty) {
      _shuffleQueue.clear();
      _shuffleQueueIndex = 0;
    }
    
    if (index < _currentIndex) {
      _currentIndex--;
    } else if (index == _currentIndex && _playlist.isNotEmpty) {
      _currentIndex = _currentIndex.clamp(0, _playlist.length - 1);
      _currentSong = _playlist[_currentIndex];
    } else if (_playlist.isEmpty) {
      _currentSong = null;
      _currentIndex = 0;
    }
    
    notifyListeners();
  }

  /// 清空播放列表
  void clearPlaylist() async {
    if (_audioHandler == null) return;
    
    await _audioHandler!.clearQueue();
    _playlist.clear();
    _shuffleQueue.clear(); // 清空随机队列
    _shuffleQueueIndex = 0;
    _currentSong = null;
    _currentIndex = 0;
    _isPlaying = false;
    notifyListeners();
  }

  void setPlaylist(List<Song> songs) {
    _playlist = songs;
    notifyListeners();
  }

  bool get isLoading => _isLoading;

  void setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);

    // 🔧 修复:同时设置 AudioPlayer (Windows) 和 AudioHandler (移动平台) 的音量
    if (_audioPlayer != null) {
      await _audioPlayer!.setVolume(_volume);
    }
    if (_audioHandler != null) {
      await _audioHandler!.setVolume(_volume);
    }

    await _prefs.setVolume(_volume);
    notifyListeners();
  }

  void setAudioQuality(AudioQuality quality) async {
    _audioQuality = quality;
    await _prefs.setAudioQuality(quality.toString().split('.').last); // 保存音质设置
    notifyListeners();
    
    // 如果正在播放，重新加载当前歌曲以应用新音质
    if (_currentSong != null && _isPlaying) {
      final currentSong = _currentSong;
      final currentPlaylist = _playlist;
      playSong(currentSong!, playlist: currentPlaylist.isNotEmpty ? currentPlaylist : null);
    }
  }

  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  // 加载收藏列表
  void _loadFavorites() {
    final favorites = _prefs.getFavoriteSongs();
    _favoriteSongIds.clear();
    _favoriteSongIds.addAll(favorites);
    notifyListeners();
  }

  // 刷新收藏列表（公开方法，供外部调用）
  void refreshFavorites() {
    _loadFavorites();
  }

  // 检查歌曲是否已收藏
  bool isFavorite(String songId) {
    return _favoriteSongIds.contains(songId);
  }

  // 检查是否正在处理收藏操作
  bool isFavoriteOperationInProgress(String songId) {
    return _favoriteOperationInProgress.contains(songId);
  }

  // 切换收藏状态（带防抖）
  Future<bool> toggleFavorite(String songId) async {
    // 防止重复点击
    if (_favoriteOperationInProgress.contains(songId)) {
      print('⚠️ 收藏操作正在进行中，请稍候...');
      return false;
    }

    // 标记为正在处理
    _favoriteOperationInProgress.add(songId);
    notifyListeners(); // 更新 UI 显示加载状态

    try {
      if (_favoriteSongIds.contains(songId)) {
        // 取消收藏
        print('📤 取消收藏: $songId');
        _favoriteSongIds.remove(songId);
        notifyListeners(); // 立即更新 UI
        
        final success = await _favoriteManager.removeFavorite(songId);
        if (success) {
          await _prefs.setFavoriteSongs(_favoriteSongIds.toList());
          print('✅ 取消收藏成功');
          return true;
        } else {
          // 失败时回滚
          _favoriteSongIds.add(songId);
          notifyListeners();
          print('❌ 取消收藏失败');
          return false;
        }
      } else {
        // 添加收藏
        print('💖 添加收藏: $songId');
        
        // 查找歌曲对象
        Song? song;
        if (_currentSong?.id == songId) {
          song = _currentSong;
        } else {
          try {
            song = _playlist.firstWhere((s) => s.id == songId);
          } catch (e) {
            print('❌ 在播放列表中找不到歌曲: $songId');
          }
        }
        
        if (song == null) {
          print('❌ 无法找到歌曲对象，无法添加收藏');
          return false;
        }
        
        _favoriteSongIds.add(songId);
        notifyListeners(); // 立即更新 UI
        
        // 传递当前播放音质
        print('💾 使用当前播放音质下载: ${_audioQuality.value}');
        final success = await _favoriteManager.addFavorite(
          song,
          audioQuality: _audioQuality.value, // 使用当前播放音质
        );
        if (success) {
          await _prefs.setFavoriteSongs(_favoriteSongIds.toList());
          print('✅ 添加收藏成功: ${song.title}');
          return true;
        } else {
          // 失败时回滚
          _favoriteSongIds.remove(songId);
          notifyListeners();
          print('❌ 添加收藏失败');
          return false;
        }
      }
    } catch (e) {
      print('❌ 切换收藏状态出错: $e');
      // 出错时回滚状态
      if (_favoriteSongIds.contains(songId)) {
        _favoriteSongIds.remove(songId);
      } else {
        _favoriteSongIds.add(songId);
      }
      notifyListeners();
      return false;
    } finally {
      // 移除处理中标记
      _favoriteOperationInProgress.remove(songId);
      notifyListeners();
    }
  }

  // 获取收藏列表
  Set<String> get favoriteSongIds => _favoriteSongIds;

  // 获取收藏管理服务
  FavoriteManagerService get favoriteManager => _favoriteManager;
  
  // 获取播放历史服务
  PlayHistoryService get historyService => _historyService;
  
  // 获取定时关闭服务
  SleepTimerService get sleepTimer => _sleepTimer;

  /// 🔧 优化:内存使用监控
  /// 用于调试和性能分析
  void logMemoryUsage() {
    print('📊 [内存监控] ==================');
    print('📊 [内存] URL缓存: ${_urlCache.length}/$_maxUrlCacheSize');
    print('📊 [内存] 播放列表: ${_playlist.length} 首歌曲');
    print('📊 [内存] 收藏歌曲: ${_favoriteSongIds.length} 首');
    print('📊 [内存] 随机队列: ${_shuffleQueue.length} 个索引');
    print('📊 [内存] 正在处理的收藏操作: ${_favoriteOperationInProgress.length}');
    print('📊 [内存监控] ==================');
  }

  /// 🔧 优化:清理过期的URL缓存
  /// 手动清理过期缓存,释放内存
  void clearExpiredUrlCache() {
    final now = DateTime.now();
    final expiredKeys = <String>[];

    _urlCacheTimestamp.forEach((key, timestamp) {
      if (now.difference(timestamp).inMinutes >= _urlCacheExpiryMinutes) {
        expiredKeys.add(key);
      }
    });

    for (final key in expiredKeys) {
      _urlCache.remove(key);
      _urlCacheTimestamp.remove(key);
    }

    if (expiredKeys.isNotEmpty) {
      print('🗑️ [缓存清理] 已清理 ${expiredKeys.length} 个过期URL缓存');
    }
  }

  /// 🔧 优化:清空所有URL缓存
  void clearAllUrlCache() {
    final count = _urlCache.length;
    _urlCache.clear();
    _urlCacheTimestamp.clear();
    print('🗑️ [缓存清理] 已清空所有URL缓存 ($count 个)');
  }

  @override
  void dispose() {
    // 🔧 优化:正确释放所有资源,防止内存泄漏
    // 参考: https://benamorn.medium.com/today-i-learned-memory-leak-in-flutter-c81951e2d9d8

    _log('🗑️ [MusicProvider] 开始释放资源');

    // 1. 取消所有 Stream 订阅,防止内存泄漏
    final subscriptionCount = _subscriptions.length;
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _log('✅ [MusicProvider] 已取消 $subscriptionCount 个 Stream 订阅');

    // 2. 释放 AudioPlayer (Windows)
    _audioPlayer?.dispose();

    // 3. 释放 AudioHandler (Android/iOS)
    if (_audioHandler != null) {
      // 注意: AudioHandler 由 AudioService 管理,不需要手动 dispose
      // 但我们可以清理缓存
      final cacheCount = _urlCache.length;
      _urlCache.clear();
      _urlCacheTimestamp.clear();
      _log('✅ [MusicProvider] 已清理 $cacheCount 个 URL 缓存');
    }

    // 4. 释放定时器服务
    _sleepTimer.dispose();

    _log('✅ [MusicProvider] 资源释放完成');
    super.dispose();
  }
}
