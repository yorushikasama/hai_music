import 'dart:async';
import 'dart:math';
import 'package:audio_service/audio_service.dart';
import '../models/song.dart';
import '../utils/logger.dart';
import 'audio_player_interface.dart';
import 'audio_player_factory.dart';
import 'song_url_service.dart';

/// 重构后的 AudioHandler 实现
/// 修复了播放列表管理问题，支持完整的播放列表功能
class MusicAudioHandler extends BaseAudioHandler with SeekHandler {
  // 音频播放器
  late final AudioPlayerInterface _audioPlayer;
  
  // 播放列表
  final List<MediaItem> _queue = [];
  int _currentIndex = 0;
  
  // 播放模式
  AudioServiceRepeatMode _repeatMode = AudioServiceRepeatMode.none;
  AudioServiceShuffleMode _shuffleMode = AudioServiceShuffleMode.none;
  
  // 会话恢复：记录上次播放位置，首次 play 时跳过去
  Duration? _pendingInitialPosition;
  bool _hasPendingInitialPosition = false;
  
  // 订阅管理
  final List<StreamSubscription> _subscriptions = [];

  // 歌曲 URL 服务（负责获取和缓存播放链接）
  final SongUrlService _urlService = SongUrlService();
  
  MusicAudioHandler() {
    _initializeHandler();
  }
  
  Future<void> _initializeHandler() async {
    Logger.info('初始化 AudioHandler', 'AudioHandler');
    
    // 创建音频播放器
    _audioPlayer = AudioPlayerFactory.createPlayer();
    
    // 监听播放状态变化
    _subscriptions.add(_audioPlayer.playingStream.listen((playing) {
      _broadcastState();
    }));
    
    // 监听播放位置变化
    _subscriptions.add(_audioPlayer.positionStream.listen((position) {
      _broadcastState();
    }));

    // 监听总时长变化，更新当前 MediaItem 的 duration
    _subscriptions.add(_audioPlayer.durationStream.listen((duration) {
      if (duration != null && _queue.isNotEmpty &&
          _currentIndex >= 0 && _currentIndex < _queue.length) {
        final current = _queue[_currentIndex];
        final updated = current.copyWith(duration: duration);
        _queue[_currentIndex] = updated;
        mediaItem.add(updated);
        queue.add(List.unmodifiable(_queue));
        Logger.debug('⏱️ 更新当前媒体项时长: ${duration.inSeconds}s (${current.title})', 'AudioHandler');
        _broadcastState();
      }
    }));
    
    // 监听播放完成
    _subscriptions.add(_audioPlayer.completionStream.listen((_) {
      _handlePlaybackCompleted();
    }));
    
    // 初始化播放状态
    _broadcastState();
    
    Logger.success('AudioHandler 初始化完成', 'AudioHandler');
  }
  
  /// 更新播放列表
  Future<void> updatePlaylist(
    List<Song> songs, {
    int? initialIndex,
    Duration? initialPosition,
  }) async {
    Logger.info('更新播放列表: ${songs.length} 首歌曲', 'AudioHandler');
    
    // 转换为 MediaItem 并更新队列
    _queue.clear();
    _queue.addAll(songs.map(_songToMediaItem));

    if (_queue.isEmpty) {
      // 队列为空时重置索引并清空当前媒体项
      _currentIndex = 0;
      mediaItem.add(null);
      _pendingInitialPosition = null;
      _hasPendingInitialPosition = false;
    } else {
      // 如果指定了起始索引，优先使用
      if (initialIndex != null) {
        _currentIndex = initialIndex.clamp(0, _queue.length - 1);
      } else {
        // 否则保持当前索引不变，如果越界则回到 0
        if (_currentIndex < 0 || _currentIndex >= _queue.length) {
          _currentIndex = 0;
        }
      }

      // 处理初始播放位置（用于会话恢复）
      if (initialPosition != null && initialPosition > Duration.zero) {
        _pendingInitialPosition = initialPosition;
        _hasPendingInitialPosition = true;
      } else {
        _pendingInitialPosition = null;
        _hasPendingInitialPosition = false;
      }
      
      // 不在这里主动修改 mediaItem，避免每次更新列表都短暂切到第 1 首
      // 真正的当前歌曲由后续的 skipToQueueItem/_playAtIndex 决定
    }

    // 更新队列流并广播状态
    queue.add(List.unmodifiable(_queue));

    final firstId = _queue.isNotEmpty ? _queue.first.id : 'null';
    final pendingPos = _pendingInitialPosition?.inSeconds ?? 0;
    Logger.debug(
      '更新播放列表完成: queueLen=${_queue.length}, currentIndex=$_currentIndex, firstId=$firstId, pendingPos=${pendingPos}s',
      'AudioHandler',
    );

    _broadcastState();
  }
  
  /// 播放指定索引的歌曲
  Future<void> _playAtIndex(int index) async {
    if (index < 0 || index >= _queue.length) return;

    _currentIndex = index;
    final originalItem = _queue[index];

    Logger.info('准备播放队列中的歌曲: ${originalItem.title}', 'AudioHandler');

    // 先根据当前 MediaItem 转为 Song（可能还没有 audioUrl）
    final baseSong = _mediaItemToSong(originalItem);

    // 获取播放链接
    final audioUrl = await _urlService.getSongUrl(baseSong);
    if (audioUrl == null || audioUrl.isEmpty) {
      Logger.warning('获取播放链接失败，跳过该歌曲: ${baseSong.title}', 'AudioHandler');
      _broadcastState();
      return;
    }

    // 构造带 URL 的 Song
    final songWithUrl = Song(
      id: baseSong.id,
      title: baseSong.title,
      artist: baseSong.artist,
      album: baseSong.album,
      duration: baseSong.duration,
      coverUrl: baseSong.coverUrl,
      audioUrl: audioUrl,
      platform: baseSong.platform,
      r2CoverUrl: baseSong.r2CoverUrl,
      lyricsLrc: baseSong.lyricsLrc,
    );

    // 用带 URL 的 Song 更新队列中的 MediaItem
    final updatedItem = _songToMediaItem(songWithUrl);
    _queue[_currentIndex] = updatedItem;

    // 更新当前 mediaItem 流和队列流
    mediaItem.add(updatedItem);
    queue.add(List.unmodifiable(_queue));

    Logger.info('开始播放: ${songWithUrl.title} - ${songWithUrl.artist}', 'AudioHandler');

    // 真正开始播放
    await _audioPlayer.play(songWithUrl);

    _broadcastState();
  }
  
  /// 更新媒体项（供外部调用）
  void updateCurrentMediaItem(MediaItem item) {
    Logger.debug('🎵 开始更新媒体项: ${item.title}', 'AudioHandler');
    
    // 检查是否已在队列中
    final existingIndex = _queue.indexWhere((m) => m.id == item.id);
    if (existingIndex >= 0) {
      // 更新现有项
      _queue[existingIndex] = item;
      if (_currentIndex == existingIndex) {
        mediaItem.add(item);
        Logger.debug('📱 更新当前播放的媒体项', 'AudioHandler');
      }
    } else {
      // 添加新项并设为当前
      _queue.add(item);
      _currentIndex = _queue.length - 1;
      mediaItem.add(item);
      Logger.debug('📱 添加新的媒体项到队列', 'AudioHandler');
    }
    
    // 更新队列
    queue.add(_queue);
    _broadcastState();
    
    Logger.success('✅ 媒体项更新完成: ${item.title}', 'AudioHandler');
  }
  
  /// 添加歌曲到队列
  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    _queue.add(mediaItem);
    queue.add(_queue);
    Logger.info('添加歌曲到队列: ${mediaItem.title}', 'AudioHandler');
  }
  
  /// 在指定位置插入歌曲
  @override
  Future<void> insertQueueItem(int index, MediaItem mediaItem) async {
    if (index >= 0 && index <= _queue.length) {
      _queue.insert(index, mediaItem);
      
      // 调整当前索引
      if (index <= _currentIndex) {
        _currentIndex++;
      }
      
      queue.add(_queue);
      Logger.info('在位置 $index 插入歌曲: ${mediaItem.title}', 'AudioHandler');
    }
  }
  
  /// 移除队列中的歌曲
  @override
  Future<void> removeQueueItemAt(int index) async {
    if (index >= 0 && index < _queue.length) {
      final mediaItem = _queue.removeAt(index);
      
      // 调整当前索引
      if (index < _currentIndex) {
        _currentIndex--;
      } else if (index == _currentIndex && _queue.isNotEmpty) {
        _currentIndex = _currentIndex.clamp(0, _queue.length - 1);
        // 如果移除的是当前播放的歌曲，需要更新当前媒体项
        this.mediaItem.add(_queue[_currentIndex]);
      } else if (_queue.isEmpty) {
        this.mediaItem.add(null);
      }
      
      queue.add(_queue);
      Logger.info('移除歌曲: ${mediaItem.title}', 'AudioHandlerV2');
    }
  }
  
  // ========== AudioHandler 接口实现 ==========
  
  @override
  Future<void> play() async {
    if (_queue.isEmpty) {
      Logger.warning('播放列表为空，无法播放', 'AudioHandlerV2');
      return;
    }

    // 如果当前已经在播放，直接返回
    if (_audioPlayer.isPlaying) {
      Logger.debug('已在播放中，忽略重复的 play 调用', 'AudioHandlerV2');
      return;
    }

    final currentPos = _audioPlayer.position;

    // 如果有有效的播放进度（说明是暂停状态），则从当前位置继续
    if (currentPos > Duration.zero) {
      Logger.debug('从暂停位置继续播放', 'AudioHandlerV2');
      await _audioPlayer.resume();
      _broadcastState();
      return;
    }

    // 首次播放当前索引的歌曲，考虑会话恢复的初始位置
    if (_hasPendingInitialPosition &&
        _pendingInitialPosition != null &&
        _pendingInitialPosition! > Duration.zero) {
      Logger.debug(
        '首次播放并跳转到上次位置: index=$_currentIndex, pos=${_pendingInitialPosition!.inSeconds}s',
        'AudioHandlerV2',
      );
      await _playAtIndex(_currentIndex);
      await _audioPlayer.seek(_pendingInitialPosition!);
      _hasPendingInitialPosition = false;
      _pendingInitialPosition = null;
    } else {
      // 否则视为首次播放当前索引的歌曲
      Logger.debug('首次播放当前索引的歌曲: index=$_currentIndex', 'AudioHandlerV2');
      await _playAtIndex(_currentIndex);
    }
  }
  
  @override
  Future<void> pause() async {
    await _audioPlayer.pause();
    Logger.debug('暂停播放', 'AudioHandlerV2');
  }
  
  @override
  Future<void> stop() async {
    await _audioPlayer.stop();
    Logger.debug('停止播放', 'AudioHandlerV2');
    _broadcastState();
  }
  
  @override
  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
    Logger.debug('跳转到位置: ${position.inSeconds}s', 'AudioHandlerV2');
  }
  
  @override
  Future<void> skipToNext() async {
    final nextIndex = _getNextIndex();
    if (nextIndex != null) {
      await _playAtIndex(nextIndex);
    } else {
      Logger.info('已到达播放列表末尾', 'AudioHandlerV2');
    }
  }
  
  @override
  Future<void> skipToPrevious() async {
    final prevIndex = _getPreviousIndex();
    if (prevIndex != null) {
      await _playAtIndex(prevIndex);
    } else {
      Logger.info('已到达播放列表开头', 'AudioHandlerV2');
    }
  }
  
  @override
  Future<void> skipToQueueItem(int index) async {
    await _playAtIndex(index);
  }
  
  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    _repeatMode = repeatMode;
    Logger.info('设置重复模式: $repeatMode', 'AudioHandlerV2');
    _broadcastState();
  }
  
  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    _shuffleMode = shuffleMode;
    Logger.info('设置随机模式: $shuffleMode', 'AudioHandlerV2');
    _broadcastState();
  }
  
  @override
  Future<void> setSpeed(double speed) async {
    await _audioPlayer.setSpeed(speed);
    Logger.debug('设置播放速度: $speed', 'AudioHandlerV2');
    _broadcastState();
  }
  
  /// 设置音量
  Future<void> setVolume(double volume) async {
    await _audioPlayer.setVolume(volume);
    Logger.debug('设置音量: $volume', 'AudioHandlerV2');
  }
  
  // ========== 内部方法 ==========
  
  /// 获取下一首的索引
  int? _getNextIndex() {
    if (_queue.isEmpty) return null;
    
    // 优先根据随机模式决定下一首
    if (_shuffleMode == AudioServiceShuffleMode.all && _queue.length > 1) {
      final random = Random();
      int nextIndex = _currentIndex;
      int attempts = 0;
      const maxAttempts = 10;

      // 尽量避免连续两次播放同一首
      while (attempts < maxAttempts && nextIndex == _currentIndex) {
        nextIndex = random.nextInt(_queue.length);
        attempts++;
      }

      return nextIndex;
    }

    // 非随机模式下，根据重复模式顺序播放
    switch (_repeatMode) {
      case AudioServiceRepeatMode.one:
        return _currentIndex; // 单曲循环
        
      case AudioServiceRepeatMode.all:
        return (_currentIndex + 1) % _queue.length; // 列表循环
        
      case AudioServiceRepeatMode.none:
      default:
        if (_currentIndex < _queue.length - 1) {
          return _currentIndex + 1;
        }
        return null; // 播放结束
    }
  }
  
  /// 获取上一首的索引
  int? _getPreviousIndex() {
    if (_queue.isEmpty) return null;
    
    // 随机模式下，上一首也随机选一首（行为与“下一首”保持一致）
    if (_shuffleMode == AudioServiceShuffleMode.all && _queue.length > 1) {
      final random = Random();
      int prevIndex = _currentIndex;
      int attempts = 0;
      const maxAttempts = 10;

      while (attempts < maxAttempts && prevIndex == _currentIndex) {
        prevIndex = random.nextInt(_queue.length);
        attempts++;
      }

      return prevIndex;
    }

    // 非随机模式下，根据重复模式顺序播放
    switch (_repeatMode) {
      case AudioServiceRepeatMode.one:
        return _currentIndex; // 单曲循环
        
      case AudioServiceRepeatMode.all:
        return (_currentIndex - 1 + _queue.length) % _queue.length; // 列表循环
        
      case AudioServiceRepeatMode.none:
      default:
        if (_currentIndex > 0) {
          return _currentIndex - 1;
        }
        return null; // 已到开头
    }
  }
  
  /// 处理播放完成
  void _handlePlaybackCompleted() {
    Logger.info('播放完成', 'AudioHandler');
    
    switch (_repeatMode) {
      case AudioServiceRepeatMode.one:
        // 单曲循环：重新播放
        _audioPlayer.seek(Duration.zero);
        _audioPlayer.resume();
        break;
        
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.none:
      case AudioServiceRepeatMode.group:
        // 播放下一首
        skipToNext();
        break;
    }
  }
  
  /// 广播播放状态
  void _broadcastState() {
    final playing = _audioPlayer.isPlaying;
    Duration position = _audioPlayer.position;

    // 如果尚未真正开始播放，但有待应用的初始位置（会话恢复），用于给 UI 显示进度
    if (!playing &&
        position == Duration.zero &&
        _hasPendingInitialPosition &&
        _pendingInitialPosition != null &&
        _pendingInitialPosition! > Duration.zero) {
      position = _pendingInitialPosition!;
    }

    final bufferedPosition = position; // 简化处理
    final speed = _audioPlayer.speed;
    final processingState = _getProcessingState();
    
    Logger.debug('📡 广播播放状态: playing=$playing, position=${position.inSeconds}s, state=$processingState', 'AudioHandler');
    Logger.debug('📡 当前队列: ${_queue.length} 首歌曲，当前索引: $_currentIndex', 'AudioHandler');
    
    // 确保有当前媒体项
    if (_queue.isNotEmpty && _currentIndex >= 0 && _currentIndex < _queue.length) {
      final currentItem = _queue[_currentIndex];
      Logger.debug('📡 当前媒体项: ${currentItem.title} - ${currentItem.artist}', 'AudioHandler');
      
      // 确保 mediaItem 流有当前项
      if (mediaItem.value?.id != currentItem.id) {
        mediaItem.add(currentItem);
        Logger.debug('📡 更新 mediaItem 流: ${currentItem.title}', 'AudioHandler');
      }
    }
    
    final playbackStateObj = PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: processingState,
      playing: playing,
      updatePosition: position,
      bufferedPosition: bufferedPosition,
      speed: speed,
      queueIndex: _currentIndex,
      repeatMode: _repeatMode,
      shuffleMode: _shuffleMode,
    );
    
    playbackState.add(playbackStateObj);
    Logger.debug('✅ 播放状态已广播: controls=${playbackStateObj.controls.length}, playing=$playing', 'AudioHandler');
  }
  
  /// 获取处理状态
  AudioProcessingState _getProcessingState() {
    if (_queue.isEmpty) {
      return AudioProcessingState.idle;
    }
    
    // 根据音频播放器的状态来判断
    if (_audioPlayer.isPlaying) {
      return AudioProcessingState.ready;
    } else if (_audioPlayer.position.inSeconds > 0) {
      // 有播放位置但暂停了
      return AudioProcessingState.ready;
    } else {
      // 准备播放
      return AudioProcessingState.loading;
    }
  }
  
  /// Song 转 MediaItem
  MediaItem _songToMediaItem(Song song) {
    return MediaItem(
      id: song.id,
      title: song.title,
      artist: song.artist,
      album: song.album,
      duration: song.duration != null ? Duration(seconds: song.duration!) : null,
      artUri: song.coverUrl.isNotEmpty ? Uri.tryParse(song.coverUrl) : null,
      extras: {
        'audioUrl': song.audioUrl,
        'platform': song.platform,
        'r2CoverUrl': song.r2CoverUrl,
        'lyricsLrc': song.lyricsLrc,
      },
    );
  }
  
  /// MediaItem 转 Song
  Song _mediaItemToSong(MediaItem mediaItem) {
    return Song(
      id: mediaItem.id,
      title: mediaItem.title,
      artist: mediaItem.artist ?? '',
      album: mediaItem.album ?? '',
      duration: mediaItem.duration?.inSeconds,
      coverUrl: mediaItem.artUri?.toString() ?? '',
      audioUrl: mediaItem.extras?['audioUrl'] ?? '',
      platform: mediaItem.extras?['platform'],
      r2CoverUrl: mediaItem.extras?['r2CoverUrl'],
      lyricsLrc: mediaItem.extras?['lyricsLrc'],
    );
  }
  
  // ========== 属性访问 ==========
  
  Duration get position => _audioPlayer.position;
  Duration? get duration => _audioPlayer.duration;
  bool get isPlaying => _audioPlayer.isPlaying;
  int get currentIndex => _currentIndex;
  List<MediaItem> get currentQueue => List.unmodifiable(_queue);
  
  // ========== 资源清理 ==========
  
  Future<void> dispose() async {
    Logger.info('释放 AudioHandler V2 资源', 'AudioHandlerV2');
    
    // 取消所有订阅
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    
    // 释放音频播放器
    await _audioPlayer.dispose();
    
    Logger.success('AudioHandler V2 资源释放完成', 'AudioHandlerV2');
  }
}
