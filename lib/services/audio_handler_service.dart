import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song.dart';

/// 音频处理服务，负责后台播放和系统媒体控制
class MusicAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  // 🔧 使用 ConcatenatingAudioSource 管理播放列表
  // 参考官方示例:https://github.com/ryanheise/audio_service/blob/master/audio_service/example/lib/example_playlist.dart
  final ConcatenatingAudioSource _playlist = ConcatenatingAudioSource(children: []);

  // 播放列表
  List<MediaItem> _queue = [];
  int _currentIndex = 0;
  LoopMode _loopMode = LoopMode.off;
  bool _shuffleModeEnabled = false;
  bool _hasTriggeredCompletion = false; // 防止重复触发
  bool _isInitialized = false; // 标记是否已初始化

  // 🔧 优化:添加调试日志开关,生产环境可关闭以提升性能
  static const bool _enableDebugLog = true;

  // 🔧 优化:Stream 订阅管理,防止内存泄漏
  // 参考: https://benamorn.medium.com/today-i-learned-memory-leak-in-flutter-c81951e2d9d8
  final List<StreamSubscription> _subscriptions = [];

  MusicAudioHandler() {
    _init();
  }

  /// 🔧 优化:统一的日志输出方法
  void _log(String message) {
    if (_enableDebugLog) {
      print(message);
    }
  }

  void _init() {
    // 🔧 关键修复:使用 playbackEventStream 自动同步状态到系统通知
    // 参考官方示例:https://pub.dev/packages/audio_service/example
    // 这样可以确保系统通知始终与播放器状态保持同步,不会在切歌时消失
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);

    // 🔧 优化:监听播放位置，检测播放完成
    // 保存订阅以便后续取消,防止内存泄漏
    final positionSubscription = _player.positionStream.listen((position) {
      final duration = _player.duration;
      if (duration != null && !_hasTriggeredCompletion) {
        // 当剩余时间小于1秒时，认为即将播放完成
        final remaining = duration - position;
        if (remaining.inMilliseconds > 0 && remaining.inMilliseconds <= 1000) {
          _hasTriggeredCompletion = true;

          // 延迟到真正结束时触发
          Future.delayed(remaining, () {
            _handlePlaybackCompleted();
          });
        }
      }
    });
    _subscriptions.add(positionSubscription);

    // 🔧 优化:监听播放完成（备用方案）
    // 使用 where() 过滤,只处理 completed 状态
    final stateSubscription = _player.playerStateStream
        .where((state) => state.processingState == ProcessingState.completed)
        .listen((state) {
      if (!_hasTriggeredCompletion) {
        _hasTriggeredCompletion = true;
        _handlePlaybackCompleted();
      }
    });
    _subscriptions.add(stateSubscription);

    // 🔧 关键修复:监听当前播放项变化,自动更新 mediaItem
    // 这样切歌时不需要手动调用 mediaItem.add(),系统通知会自动更新
    final indexSubscription = _player.currentIndexStream.listen((index) {
      if (index != null && index < _queue.length) {
        _currentIndex = index;
        _log('🎵 [AudioHandler] 当前索引变化: $index, 歌曲: ${_queue[index].title}');
        mediaItem.add(_queue[index]);
      }
    });
    _subscriptions.add(indexSubscription);

    // 🔧 优化:监听播放顺序变化
    // 保存订阅以便后续取消,防止内存泄漏
    final sequenceSubscription = _player.sequenceStateStream.listen((sequenceState) {
      if (sequenceState != null) {
        _queue = sequenceState.effectiveSequence
            .map((source) => source.tag as MediaItem)
            .toList();
        queue.add(_queue);
      }
    });
    _subscriptions.add(sequenceSubscription);
  }

  /// 🔧 将 just_audio 的事件转换为 audio_service 的状态
  /// 参考官方示例:https://pub.dev/packages/audio_service/example
  /// 这个方法确保系统通知能够实时反映播放器状态
  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2], // 通知栏显示:上一首、播放/暂停、下一首
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }

  /// 播放完成回调（由外部设置）
  Function? onPlaybackCompleted;

  /// 下一首回调（由外部设置，用于系统通知栏按钮）
  Function? onSkipToNext;

  /// 上一首回调（由外部设置，用于系统通知栏按钮）
  Function? onSkipToPrevious;

  /// 处理播放完成
  void _handlePlaybackCompleted() {
    // 通知外部处理播放完成
    if (onPlaybackCompleted != null) {
      try {
        onPlaybackCompleted!();
      } catch (e) {
        print('❌ [AudioHandler] 回调执行失败: $e');
      }
    }
  }

  /// 🔧 从歌曲列表创建播放队列
  /// 参考官方示例,使用 ConcatenatingAudioSource 管理播放列表
  /// 智能判断是否需要重建队列:如果队列内容相同,只切换索引;如果不同,重建队列
  Future<void> setQueueFromSongs(List<Song> songs, {int initialIndex = 0}) async {
    // 🔧 优化:参数验证
    if (songs.isEmpty) {
      _log('⚠️ [AudioHandler] 歌曲列表为空,跳过设置');
      return;
    }

    if (initialIndex < 0 || initialIndex >= songs.length) {
      _log('⚠️ [AudioHandler] 初始索引越界: $initialIndex (总数: ${songs.length}), 使用 0');
      initialIndex = 0;
    }

    // 🔧 优化:性能监控
    final stopwatch = Stopwatch()..start();

    _log('🎵 [AudioHandler] 设置播放队列: ${songs.length} 首歌曲, 初始索引: $initialIndex');

    final newQueue = songs.map((song) => _songToMediaItem(song)).toList();

    // 🔧 智能判断:检查队列是否发生变化
    final queueChanged = _isQueueChanged(newQueue);

    if (!queueChanged && _isInitialized) {
      // 队列内容相同,只需要切换索引,不重建队列
      _log('✅ [AudioHandler] 队列未变化,使用 seek 切换到索引: $initialIndex');
      if (initialIndex >= 0 && initialIndex < _queue.length) {
        await _player.seek(Duration.zero, index: initialIndex);
        _currentIndex = initialIndex;
        // mediaItem 会通过 currentIndexStream 自动更新
      }

      stopwatch.stop();
      _log('⏱️ [性能] setQueueFromSongs (seek) 耗时: ${stopwatch.elapsedMilliseconds}ms');
      return;
    }

    // 队列发生变化,需要重建
    _log('🔧 [AudioHandler] 队列发生变化,重建播放列表');
    _queue = newQueue;
    queue.add(_queue);

    // 🔧 优化:批量操作,减少重建次数
    // 清空现有播放列表
    await _playlist.clear();

    // 添加新的音频源到播放列表
    final sources = songs.map((song) {
      if (song.audioUrl.isEmpty) {
        print('⚠️ 警告: 音频URL为空 - ${song.title}');
      }
      final mediaItem = _songToMediaItem(song);
      return AudioSource.uri(
        Uri.parse(song.audioUrl),
        tag: mediaItem,
      );
    }).toList();

    // 🔧 优化:使用 addAll 批量添加,而不是逐个添加
    await _playlist.addAll(sources);

    // 🔧 关键修复:只在第一次初始化时调用 setAudioSource
    // 之后的队列更新也使用 seek() 方法,不会重置系统通知
    if (!_isInitialized) {
      await _player.setAudioSource(_playlist, initialIndex: initialIndex);
      _isInitialized = true;
      print('✅ [AudioHandler] 首次初始化播放器');
    } else {
      // 已初始化,队列已更新,跳转到指定索引
      if (initialIndex >= 0 && initialIndex < _queue.length) {
        await _player.seek(Duration.zero, index: initialIndex);
        print('✅ [AudioHandler] 队列已更新,跳转到索引: $initialIndex');
      }
    }

    _currentIndex = initialIndex;
    // mediaItem 会通过 currentIndexStream 自动更新,不需要手动调用

    stopwatch.stop();
    _log('⏱️ [性能] setQueueFromSongs (rebuild) 耗时: ${stopwatch.elapsedMilliseconds}ms');
  }

  /// 检查队列是否发生变化
  bool _isQueueChanged(List<MediaItem> newQueue) {
    if (_queue.length != newQueue.length) {
      return true;
    }

    for (int i = 0; i < _queue.length; i++) {
      if (_queue[i].id != newQueue[i].id) {
        return true;
      }
    }

    return false;
  }

  /// 播放指定歌曲
  Future<void> playSong(Song song, {List<Song>? playlist}) async {
    if (playlist != null && playlist.isNotEmpty) {
      final index = playlist.indexWhere((s) => s.id == song.id);
      await setQueueFromSongs(playlist, initialIndex: index >= 0 ? index : 0);
    } else {
      await setQueueFromSongs([song]);
    }
    await play();
  }

  /// 将 Song 转换为 MediaItem
  MediaItem _songToMediaItem(Song song) {
    return MediaItem(
      id: song.id,
      album: song.album,
      title: song.title,
      artist: song.artist,
      duration: song.duration != null ? Duration(seconds: song.duration!) : null,
      artUri: Uri.tryParse(song.r2CoverUrl ?? song.coverUrl),
      extras: {
        'audioUrl': song.audioUrl,
        'coverUrl': song.coverUrl,
        'r2CoverUrl': song.r2CoverUrl,
      },
    );
  }

  // ========== AudioHandler 接口实现 ==========

  @override
  Future<void> play() async {
    _hasTriggeredCompletion = false; // 重置完成标志
    try {
      await _player.play();
    } catch (e) {
      print('❌ 播放失败: $e');
      rethrow;
    }
  }

  @override
  Future<void> pause() async {
    await _player.pause();
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  @override
  Future<void> skipToNext() async {
    print('⏭️ [AudioHandler] skipToNext 被调用（系统通知栏）');

    // 🔧 优先使用外部回调（MusicProvider 管理播放模式）
    if (onSkipToNext != null) {
      try {
        onSkipToNext!();
        print('✅ [AudioHandler] 调用外部 skipToNext 回调');
        return;
      } catch (e) {
        print('❌ [AudioHandler] skipToNext 回调失败: $e');
      }
    }

    // 降级方案：使用 just_audio 内置的 seekToNext
    // 这会自动触发 currentIndexStream 更新,mediaItem 会自动更新
    if (_currentIndex < _queue.length - 1) {
      await _player.seekToNext();
      print('✅ [AudioHandler] 使用内置 seekToNext');
    }
  }

  @override
  Future<void> skipToPrevious() async {
    print('⏮️ [AudioHandler] skipToPrevious 被调用（系统通知栏）');

    // 🔧 优先使用外部回调（MusicProvider 管理播放模式）
    if (onSkipToPrevious != null) {
      try {
        onSkipToPrevious!();
        print('✅ [AudioHandler] 调用外部 skipToPrevious 回调');
        return;
      } catch (e) {
        print('❌ [AudioHandler] skipToPrevious 回调失败: $e');
      }
    }

    // 降级方案：使用 just_audio 内置的 seekToPrevious
    // 这会自动触发 currentIndexStream 更新,mediaItem 会自动更新
    if (_currentIndex > 0) {
      await _player.seekToPrevious();
      print('✅ [AudioHandler] 使用内置 seekToPrevious');
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index >= 0 && index < _queue.length) {
      await _player.seek(Duration.zero, index: index);
      _currentIndex = index;
      mediaItem.add(_queue[index]);
    }
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        _loopMode = LoopMode.off;
        break;
      case AudioServiceRepeatMode.one:
        _loopMode = LoopMode.one;
        break;
      case AudioServiceRepeatMode.all:
        _loopMode = LoopMode.all;
        break;
      case AudioServiceRepeatMode.group:
        _loopMode = LoopMode.all;
        break;
    }
    await _player.setLoopMode(_loopMode);
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    _shuffleModeEnabled = shuffleMode != AudioServiceShuffleMode.none;
    await _player.setShuffleModeEnabled(_shuffleModeEnabled);
  }

  @override
  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
  }

  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume);
  }

  // ========== 自定义方法 ==========

  /// 获取当前播放位置
  Duration get position => _player.position;

  /// 获取总时长
  Duration? get duration => _player.duration;

  /// 获取播放状态
  bool get isPlaying => _player.playing;

  /// 获取当前索引
  int get currentIndex => _currentIndex;

  /// 获取播放列表
  List<MediaItem> get currentQueue => _queue;

  /// 获取循环模式
  LoopMode get loopMode => _loopMode;

  /// 获取随机模式
  bool get shuffleModeEnabled => _shuffleModeEnabled;

  /// 从播放列表移除歌曲
  @override
  Future<void> removeQueueItemAt(int index) async {
    if (index < 0 || index >= _queue.length) return;
    
    _queue.removeAt(index);
    queue.add(_queue);
    
    // 如果移除的是当前播放的歌曲
    if (index == _currentIndex) {
      if (_queue.isEmpty) {
        await stop();
      } else {
        // 播放下一首
        final newIndex = _currentIndex.clamp(0, _queue.length - 1);
        await skipToQueueItem(newIndex);
      }
    } else if (index < _currentIndex) {
      // 如果移除的歌曲在当前歌曲之前，调整索引
      _currentIndex--;
    }
  }

  /// 清空播放列表
  Future<void> clearQueue() async {
    _queue.clear();
    queue.add(_queue);
    await stop();
  }

  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
    // 🔧 优化:自定义操作预留接口
    // 目前音质切换由 MusicProvider 直接处理,这里暂时不需要实现
    _log('🔧 [AudioHandler] 收到自定义操作: $name');
  }

  @override
  Future<void> onTaskRemoved() async {
    // Android 任务被移除时的处理
    // 可以选择停止播放或继续后台播放
    await stop();
  }

  /// 🔧 优化:添加资源清理方法
  /// 释放播放器资源,防止内存泄漏
  /// 参考: https://benamorn.medium.com/today-i-learned-memory-leak-in-flutter-c81951e2d9d8
  Future<void> dispose() async {
    try {
      _log('🗑️ [AudioHandler] 开始释放资源');

      // 1. 取消所有 Stream 订阅,防止内存泄漏
      final subscriptionCount = _subscriptions.length;
      for (final subscription in _subscriptions) {
        await subscription.cancel();
      }
      _subscriptions.clear();
      _log('✅ [AudioHandler] 已取消 $subscriptionCount 个 Stream 订阅');

      // 2. 停止并释放播放器
      await _player.stop();
      await _player.dispose();

      _log('✅ [AudioHandler] 资源释放完成');
    } catch (e) {
      _log('❌ [AudioHandler] 资源释放失败: $e');
    }
  }
}
