import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:math' show Random;
import '../models/song.dart';
import '../models/audio_quality.dart';
import '../models/play_mode.dart';
import '../services/music_api_service.dart';
import '../services/preferences_service.dart';
import '../services/favorite_manager_service.dart';
import '../services/play_history_service.dart';
import '../services/sleep_timer_service.dart';
import '../config/app_constants.dart';

class MusicProvider with ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final MusicApiService _apiService = MusicApiService();
  final PreferencesService _prefs = PreferencesService();
  final FavoriteManagerService _favoriteManager = FavoriteManagerService();
  final PlayHistoryService _historyService = PlayHistoryService();
  final SleepTimerService _sleepTimer = SleepTimerService();
  
  Song? _currentSong;
  List<Song> _playlist = [];
  int _currentIndex = 0;
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  bool _isLoading = false;
  AudioQuality _audioQuality = AudioQuality.high; // 默认HQ高音质
  PlayMode _playMode = PlayMode.sequence; // 默认顺序播放
  final Random _random = Random();
  double _volume = 1.0; // 音量 0.0 - 1.0
  final Set<String> _favoriteSongIds = {}; // 收藏的歌曲ID集合
  int _playRequestVersion = 0; // 播放请求版本号，用于防止竞态条件
  int _consecutiveFailures = 0; // 连续失败次数
  final Set<String> _favoriteOperationInProgress = {}; // 正在处理的收藏操作

  MusicProvider() {
    _initAudioPlayer();
    _loadSettings();
    _loadFavorites();
    _initFavoriteManager();
  }

  // 初始化收藏管理服务
  void _initFavoriteManager() async {
    await _favoriteManager.initialize();
  }

  // 从本地加载设置
  void _loadSettings() {
    _volume = _prefs.getVolume();
    _audioPlayer.setVolume(_volume);
    
    final modeStr = _prefs.getPlayMode();
    _playMode = _parsePlayMode(modeStr);
    
    final qualityStr = _prefs.getAudioQuality();
    _audioQuality = _parseAudioQuality(qualityStr);
    
    notifyListeners();
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

  void _initAudioPlayer() async {
    // 平台特殊配置
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      
      // Windows 平台优化：启用低延迟模式
      if (!kIsWeb && Platform.isWindows) {
        // Windows 平台使用 PlayerMode.lowLatency 减少卡顿
        await _audioPlayer.setPlayerMode(PlayerMode.lowLatency);
        print('✅ Windows 平台：启用低延迟模式');
      }
      
      // 设置音频上下文（仅移动平台支持）
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        await _audioPlayer.setAudioContext(AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: [
              AVAudioSessionOptions.mixWithOthers,
              AVAudioSessionOptions.duckOthers,
            ],
          ),
          android: AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: true,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.media,
            audioFocus: AndroidAudioFocus.gain,
          ),
        ));
        print('✅ 移动平台：音频上下文配置完成');
      }
      
      // Windows 平台额外配置
      if (!kIsWeb && Platform.isWindows) {
        print('✅ 音频播放器配置完成（Windows 平台 - 低延迟模式）');
        print('💡 Windows 提示：确保系统已安装必要的音频编解码器');
      } else {
        print('✅ 音频播放器配置完成（移动平台优化）');
      }
    } catch (e) {
      print('⚠️ 音频播放器配置失败: $e');
    }
    
    // 监听播放状态
    _audioPlayer.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;
      print('🎵 播放状态变化: $state');
      notifyListeners();
    });

    // 监听播放进度
    _audioPlayer.onPositionChanged.listen((position) {
      _currentPosition = position;
      notifyListeners();
    });

    // 监听总时长
    _audioPlayer.onDurationChanged.listen((duration) {
      _totalDuration = duration;
      print('⏱️ 歌曲时长: ${duration.inSeconds}秒');
      notifyListeners();
    });

    // 监听播放完成
    _audioPlayer.onPlayerComplete.listen((_) {
      print('✅ 播放完成事件触发');
      _handlePlayComplete();
    });
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
  
  // 兼容旧代码
  bool get isRepeat => _playMode == PlayMode.single;
  bool get isShuffle => _playMode == PlayMode.shuffle;

  void playSong(Song song, {List<Song>? playlist, bool autoSkipOnError = false}) async {
    // 增加版本号，标记这是一个新的播放请求
    _playRequestVersion++;
    final currentVersion = _playRequestVersion;
    
    // 先保存目标歌曲和播放列表，但不立即更新 _currentSong
    final targetSong = song;
    final targetPlaylist = playlist;
    
    _isLoading = true;
    notifyListeners();

    try {
      String? audioUrl;
      
      // 优先使用对象存储的直链（如果有）
      if (targetSong.audioUrl.isNotEmpty && targetSong.audioUrl.startsWith('http')) {
        audioUrl = targetSong.audioUrl;
        print('✅ 使用对象存储直链播放: ${targetSong.title}');
        print('🔗 直链URL: $audioUrl');
      } else {
        // 没有直链时才调用API获取
        print('⚠️ 无对象存储直链，使用API获取: ${targetSong.title}');
        print('📝 歌曲ID: ${targetSong.id}');
        print('🎵 音质: ${_audioQuality.value}');
        
        audioUrl = await _apiService.getSongUrl(
          songId: targetSong.id,
          quality: _audioQuality.value,
        ).timeout(
          Duration(seconds: AppConstants.playUrlTimeout),
          onTimeout: () {
            print('⏱️ 获取播放链接超时: ${targetSong.title}');
            return null;
          },
        );
        
        if (audioUrl != null && audioUrl.isNotEmpty) {
          print('✅ API返回URL: $audioUrl');
        } else {
          print('❌ API未返回有效URL');
        }
      }

      // 检查是否有新的播放请求，如果有则放弃当前请求
      if (currentVersion != _playRequestVersion) {
        print('播放请求已过期，放弃播放: ${targetSong.title}');
        return;
      }

      if (audioUrl != null && audioUrl.isNotEmpty) {
        // 只有在确认要播放时才更新当前歌曲和播放列表
        _currentSong = targetSong;
        if (targetPlaylist != null) {
          _playlist = targetPlaylist;
          _currentIndex = targetPlaylist.indexOf(targetSong);
        }
        
        // 重置播放进度和时长，避免显示上一首歌的数据
        _currentPosition = Duration.zero;
        _totalDuration = Duration.zero;
        
        // 刷新收藏状态，确保UI显示正确
        refreshFavorites();
        
        // 验证 URL 格式
        if (!audioUrl.startsWith('http://') && !audioUrl.startsWith('https://')) {
          print('❌ 无效的音频URL格式: $audioUrl');
          throw Exception('无效的音频URL格式');
        }
        
        print('🎵 准备播放: ${targetSong.title}');
        print('🔗 音频URL: $audioUrl');
        
        await _audioPlayer.stop();
        
        // Windows 平台特殊处理：预加载优化
        try {
          // 创建 UrlSource
          final source = UrlSource(audioUrl);
          
          // Windows 平台：先设置源，等待缓冲
          if (!kIsWeb && Platform.isWindows) {
            print('🔄 Windows 平台：预加载音频...');
            await _audioPlayer.setSource(source);
            // 给一点时间让它缓冲
            await Future.delayed(const Duration(milliseconds: 100));
          }
          
          // 开始播放
          await _audioPlayer.play(source);
          _isPlaying = true;
          
          // 播放成功，重置失败计数
          _consecutiveFailures = 0;
          
          // 添加到播放历史
          _historyService.addHistory(targetSong);
        } catch (playError) {
          print('❌ 播放失败: $playError');
          // 如果是 Windows 平台错误，尝试重新获取 URL
          if (playError.toString().contains('WindowsAudioError') || 
              playError.toString().contains('C00D2EE3')) {
            print('⚠️ Windows 平台播放错误，可能是 URL 或编解码器问题');
            print('💡 建议：检查音频格式是否为 MP3，或 URL 是否有效');
          }
          rethrow; // 重新抛出异常，让外层 catch 处理
        }
      } else {
        print('❌ 无法获取播放链接: ${targetSong.title}');
        _isPlaying = false;
        _consecutiveFailures++;
        
        // 如果是自动播放（如播放下一首）且失败，则自动跳过
        if (autoSkipOnError && _playlist.isNotEmpty) {
          if (_consecutiveFailures >= AppConstants.maxConsecutiveFailures) {
            print('⚠️ 连续失败 $_consecutiveFailures 次，停止自动跳过');
            _consecutiveFailures = 0;
          } else {
            print('⏭️ 自动跳过失败的歌曲 ($_consecutiveFailures/${AppConstants.maxConsecutiveFailures})，播放下一首');
            Future.delayed(const Duration(milliseconds: 500), () {
              playNext(autoSkip: true); // 继续启用自动跳过
            });
          }
        }
      }
    } catch (e) {
      print('❌ 播放歌曲出错: $e');
      _isPlaying = false;
      _consecutiveFailures++;
      
      // 如果是自动播放且失败，则自动跳过
      if (autoSkipOnError && _playlist.isNotEmpty && currentVersion == _playRequestVersion) {
        if (_consecutiveFailures >= AppConstants.maxConsecutiveFailures) {
          print('⚠️ 连续失败 $_consecutiveFailures 次，停止自动跳过');
          _consecutiveFailures = 0;
        } else {
          print('⏭️ 播放出错 ($_consecutiveFailures/${AppConstants.maxConsecutiveFailures})，自动跳过到下一首');
          Future.delayed(const Duration(milliseconds: 500), () {
            playNext(autoSkip: true); // 继续启用自动跳过
          });
        }
      }
    } finally {
      // 只有当前版本才更新加载状态
      if (currentVersion == _playRequestVersion) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void togglePlayPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.resume();
    }
  }

  void pause() async {
    await _audioPlayer.pause();
  }

  void play() async {
    await _audioPlayer.resume();
  }

  void _handlePlayComplete() {
    print('🎵 歌曲播放完成，当前模式: $_playMode');
    
    // 更新播放状态
    _isPlaying = false;
    notifyListeners();
    
    switch (_playMode) {
      case PlayMode.single:
        // 单曲循环：重新播放当前歌曲
        print('🔁 单曲循环，重新播放');
        _audioPlayer.seek(Duration.zero);
        _audioPlayer.resume();
        _isPlaying = true;
        notifyListeners();
        break;
      case PlayMode.sequence:
        // 顺序播放：播放下一首，循环播放（启用自动跳过）
        print('⏭️ 顺序播放，播放下一首');
        playNext(autoSkip: true);
        break;
      case PlayMode.shuffle:
        // 随机播放：随机选择下一首（启用自动跳过）
        print('🔀 随机播放，播放下一首');
        playNext(autoSkip: true);
        break;
    }
  }

  void playNext({bool autoSkip = false}) {
    if (_playlist.isEmpty) return;
    
    if (_playMode == PlayMode.shuffle) {
      // 随机播放：随机选择一首（避免重复当前歌曲）
      if (_playlist.length > 1) {
        int nextIndex;
        do {
          nextIndex = _random.nextInt(_playlist.length);
        } while (nextIndex == _currentIndex);
        _currentIndex = nextIndex;
      }
    } else {
      // 其他模式：顺序播放下一首
      _currentIndex = (_currentIndex + 1) % _playlist.length;
    }
    
    _currentSong = _playlist[_currentIndex];
    playSong(_currentSong!, playlist: _playlist, autoSkipOnError: autoSkip);
  }

  void playPrevious({bool autoSkip = false}) {
    if (_playlist.isEmpty) return;
    
    _currentIndex = (_currentIndex - 1 + _playlist.length) % _playlist.length;
    _currentSong = _playlist[_currentIndex];
    playSong(_currentSong!, playlist: _playlist, autoSkipOnError: autoSkip);
  }

  void seekTo(Duration position) async {
    await _audioPlayer.seek(position);
  }

  void updatePosition(Duration position) {
    _currentPosition = position;
    notifyListeners();
  }

  void togglePlayMode() async {
    _playMode = _playMode.next;
    await _prefs.setPlayMode(_playMode.toString().split('.').last); // 保存播放模式
    notifyListeners();
  }
  
  void setPlayMode(PlayMode mode) {
    _playMode = mode;
    notifyListeners();
  }

  /// 从播放列表移除歌曲
  void removeFromPlaylist(int index) {
    if (index < 0 || index >= _playlist.length) return;
    
    final removedSong = _playlist[index];
    _playlist.removeAt(index);
    
    // 如果移除的是当前播放的歌曲
    if (_currentSong?.id == removedSong.id) {
      if (_playlist.isEmpty) {
        _currentSong = null;
        _audioPlayer.stop();
        _isPlaying = false;
      } else {
        // 播放下一首
        _currentIndex = _currentIndex.clamp(0, _playlist.length - 1);
        playSong(_playlist[_currentIndex], playlist: _playlist);
      }
    } else if (index < _currentIndex) {
      // 如果移除的歌曲在当前歌曲之前，调整索引
      _currentIndex--;
    }
    
    notifyListeners();
  }

  /// 清空播放列表
  void clearPlaylist() {
    _playlist.clear();
    _currentSong = null;
    _currentIndex = 0;
    _audioPlayer.stop();
    _isPlaying = false;
    notifyListeners();
  }

  // 兼容旧代码
  void toggleRepeat() {
    if (_playMode == PlayMode.single) {
      _playMode = PlayMode.sequence;
    } else {
      _playMode = PlayMode.single;
    }
    notifyListeners();
  }

  void toggleShuffle() {
    if (_playMode == PlayMode.shuffle) {
      _playMode = PlayMode.sequence;
    } else {
      _playMode = PlayMode.shuffle;
    }
    notifyListeners();
  }

  void setPlaylist(List<Song> songs) {
    _playlist = songs;
    notifyListeners();
  }

  bool get isLoading => _isLoading;

  void setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _audioPlayer.setVolume(_volume);
    await _prefs.setVolume(_volume); // 保存音量设置
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

  @override
  void dispose() {
    _audioPlayer.dispose();
    _sleepTimer.dispose();
    super.dispose();
  }
}
