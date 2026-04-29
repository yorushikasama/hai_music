import 'dart:async';

import 'package:audio_service/audio_service.dart';

import '../../models/song.dart';
import '../../models/song_media_item_extension.dart';
import '../../utils/logger.dart';
import '../cache/cache.dart';
import 'audio_player_factory.dart';
import 'audio_player_interface.dart';
import 'playback_index_resolver.dart';
import 'playback_state_transformer.dart';
import 'song_url_service.dart';

/// 音频服务核心 Handler，管理播放列表、播放控制和状态广播
class MusicAudioHandler extends BaseAudioHandler with SeekHandler {
  late final AudioPlayerInterface _audioPlayer;

  final List<MediaItem> _queue = [];
  int _currentIndex = 0;

  AudioServiceRepeatMode _repeatMode = AudioServiceRepeatMode.none;
  AudioServiceShuffleMode _shuffleMode = AudioServiceShuffleMode.none;

  double _currentSpeed = 1.0;

  bool _isStopped = false;

  Duration? _pendingInitialPosition;
  bool _hasPendingInitialPosition = false;

  final List<StreamSubscription<void>> _subscriptions = [];

  final SongUrlService _urlService = SongUrlService();
  final SmartCacheService _cacheService = SmartCacheService();

  MusicAudioHandler() {
    _initializeCompleter = Completer<void>();
    _initializeHandler();
  }

  Completer<void>? _initializeCompleter;
  Object? _initializationError;

  /// 等待 Handler 初始化完成
  Future<void> get ready {
    if (_initializationError != null) {
      return Future.error(_initializationError!);
    }
    return _initializeCompleter?.future ?? Future.value();
  }

  Future<void> _initializeHandler() async {
    Logger.info('初始化 AudioHandler', 'AudioHandler');

    try {
      _audioPlayer = AudioPlayerFactory.createPlayer();

      _subscriptions.add(
        _audioPlayer.playbackEventStream
            .map((event) => PlaybackStateTransformer.transformEvent(
                  event: event,
                  audioPlayer: _audioPlayer,
                  currentIndex: _currentIndex,
                  pendingInitialPosition: _pendingInitialPosition,
                  hasPendingInitialPosition: _hasPendingInitialPosition,
                  repeatMode: _repeatMode,
                  shuffleMode: _shuffleMode,
                ))
            .listen(playbackState.add),
      );

      _subscriptions.add(_audioPlayer.durationStream.listen((duration) {
        if (duration != null &&
            _queue.isNotEmpty &&
            _currentIndex >= 0 &&
            _currentIndex < _queue.length) {
          final current = _queue[_currentIndex];
          final updated = current.copyWith(duration: duration);
          _queue[_currentIndex] = updated;
          mediaItem.add(updated);
          queue.add(List.unmodifiable(_queue));
          _broadcastState();
        }
      }));

      _subscriptions.add(_audioPlayer.completionStream.listen((_) {
        _handlePlaybackCompleted();
      }));

      _broadcastState();

      Logger.success('AudioHandler 初始化完成', 'AudioHandler');
    } catch (e, stackTrace) {
      Logger.error('AudioHandler 初始化失败', e, stackTrace, 'AudioHandler');
      _initializationError = e;
      if (_initializeCompleter != null &&
          !_initializeCompleter!.isCompleted) {
        _initializeCompleter!.completeError(e);
      }
    }

    if (_initializeCompleter != null && !_initializeCompleter!.isCompleted) {
      _initializeCompleter!.complete();
    }
  }

  // ========== 播放列表管理 ==========

  /// 更新播放列表，可指定起始索引和初始位置（用于会话恢复）
  Future<void> updatePlaylist(
    List<Song> songs, {
    int? initialIndex,
    Duration? initialPosition,
  }) async {
    Logger.info('更新播放列表: ${songs.length} 首歌曲', 'AudioHandler');

    _queue.clear();
    _queue.addAll(songs.map((s) => s.toMediaItem()));

    if (_queue.isEmpty) {
      _currentIndex = 0;
      _isStopped = true;
      mediaItem.add(null);
      _pendingInitialPosition = null;
      _hasPendingInitialPosition = false;
    } else {
      if (initialIndex != null) {
        _currentIndex = initialIndex.clamp(0, _queue.length - 1);
      } else {
        if (_currentIndex < 0 || _currentIndex >= _queue.length) {
          _currentIndex = 0;
        }
      }

      if (initialPosition != null && initialPosition > Duration.zero) {
        _pendingInitialPosition = initialPosition;
        _hasPendingInitialPosition = true;
      } else {
        _pendingInitialPosition = null;
        _hasPendingInitialPosition = false;
      }
    }

    queue.add(List.unmodifiable(_queue));
    _broadcastState();
  }

  /// 更新当前媒体项（供外部调用）
  void updateCurrentMediaItem(MediaItem item) {
    final existingIndex = _queue.indexWhere((m) => m.id == item.id);
    if (existingIndex >= 0) {
      _queue[existingIndex] = item;
      if (_currentIndex == existingIndex) {
        mediaItem.add(item);
      }
    } else {
      _queue.add(item);
      _currentIndex = _queue.length - 1;
      mediaItem.add(item);
    }

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
      final removedItem = _queue.removeAt(index);

      if (index < _currentIndex) {
        _currentIndex--;
      } else if (index == _currentIndex && _queue.isNotEmpty) {
        _currentIndex = _currentIndex.clamp(0, _queue.length - 1);
        mediaItem.add(_queue[_currentIndex]);
      } else if (_queue.isEmpty) {
        mediaItem.add(null);
      }

      queue.add(_queue);
      Logger.info('移除歌曲: ${removedItem.title}', 'AudioHandler');
    }
  }

  // ========== AudioHandler 接口实现 ==========

  @override
  Future<void> play() async {
    if (_initializeCompleter != null && !_initializeCompleter!.isCompleted) {
      await _initializeCompleter!.future;
    }

    if (_queue.isEmpty) {
      Logger.warning('播放列表为空，无法播放', 'AudioHandler');
      return;
    }

    if (_audioPlayer.isPlaying) return;

    final currentPos = _audioPlayer.position;

    if (currentPos > Duration.zero) {
      _isStopped = false;
      await _audioPlayer.resume();
      _broadcastState();
      return;
    }

    if (_hasPendingInitialPosition &&
        _pendingInitialPosition != null &&
        _pendingInitialPosition! > Duration.zero) {
      await _playAtIndex(_currentIndex);
      await _audioPlayer.seek(_pendingInitialPosition!);
      _hasPendingInitialPosition = false;
      _pendingInitialPosition = null;
    } else {
      await _playAtIndex(_currentIndex);
    }
  }

  @override
  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  @override
  Future<void> stop() async {
    await _audioPlayer.stop();
    _isStopped = true;
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    try {
      await _audioPlayer.seek(position);
    } catch (e) {
      Logger.error('seek 失败', e, null, 'AudioHandler');
    }
  }

  @override
  Future<void> skipToNext() async {
    final nextIndex = _getNextIndex();
    if (nextIndex != null) {
      await _playAtIndex(nextIndex);
    } else {
      Logger.info('已到达播放列表末尾，停止播放', 'AudioHandler');
      await stop();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    final prevIndex = _getPreviousIndex();
    if (prevIndex != null) {
      await _playAtIndex(prevIndex);
    } else {
      Logger.info('已到达播放列表开头', 'AudioHandler');
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    await _playAtIndex(index);
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    _repeatMode = repeatMode;
    Logger.info('设置重复模式: $repeatMode', 'AudioHandler');
    _broadcastState();
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    _shuffleMode = shuffleMode;
    Logger.info('设置随机模式: $shuffleMode', 'AudioHandler');
    _broadcastState();
  }

  @override
  Future<void> setSpeed(double speed) async {
    _currentSpeed = speed;
    try {
      await _audioPlayer.setSpeed(speed);
    } catch (e) {
      Logger.error('设置播放速度失败', e, null, 'AudioHandler');
    }
    _broadcastState();
  }

  /// 设置音量
  Future<void> setVolume(double volume) async {
    await _audioPlayer.setVolume(volume);
  }

  // ========== 内部方法 ==========

  /// 播放指定索引的歌曲
  Future<void> _playAtIndex(int index) async {
    Logger.info('[_playAtIndex] 开始播放索引: $index', 'AudioHandler');
    _isStopped = false;

    if (_initializeCompleter != null && !_initializeCompleter!.isCompleted) {
      Logger.info('[_playAtIndex] 等待播放器初始化...', 'AudioHandler');
      await _initializeCompleter!.future;
    }

    if (index < 0 || index >= _queue.length) {
      Logger.warning(
        '[_playAtIndex] 索引越界: $index, 队列长度: ${_queue.length}',
        'AudioHandler',
      );
      return;
    }

    _currentIndex = index;
    final originalItem = _queue[index];

    final baseSong = originalItem.toSong();

    String? audioUrl;
    try {
      audioUrl = await _urlService.getSongUrl(baseSong);
    } catch (e, stackTrace) {
      Logger.error('[_playAtIndex] 获取播放链接异常', e, stackTrace, 'AudioHandler');
      _broadcastState();
      return;
    }

    if (audioUrl == null || audioUrl.isEmpty) {
      Logger.warning(
        '[_playAtIndex] 获取播放链接失败，跳过: ${baseSong.title}',
        'AudioHandler',
      );
      _broadcastState();
      return;
    }

    final songWithUrl = baseSong.copyWith(audioUrl: audioUrl);
    final updatedItem = songWithUrl.toMediaItem();
    _queue[_currentIndex] = updatedItem;
    mediaItem.add(updatedItem);
    queue.add(List.unmodifiable(_queue));

    try {
      await _audioPlayer.play(songWithUrl);
      if (_currentSpeed != 1.0) {
        try {
          await _audioPlayer.setSpeed(_currentSpeed);
        } catch (e) {
          Logger.warning('设置播放速度失败: $e', 'AudioHandler');
        }
      }
    } catch (e, stackTrace) {
      Logger.error(
        '[_playAtIndex] 播放失败: ${songWithUrl.title}',
        e,
        stackTrace,
        'AudioHandler',
      );
      _broadcastState();
      return;
    }

    unawaited(_cacheService.cacheOnPlay(songWithUrl).catchError((Object e) {
      Logger.error(
        '🎵 [AudioHandler] 缓存歌曲失败: ${songWithUrl.title}',
        e,
        null,
        'AudioHandler',
      );
    }));

    _preloadNextSong();
    _broadcastState();
  }

  /// 预加载下一首歌曲
  void _preloadNextSong() {
    final nextIndex = _getNextIndex();
    if (nextIndex != null && nextIndex < _queue.length) {
      final nextItem = _queue[nextIndex];
      final nextSong = nextItem.toSong();

      if (nextSong.audioUrl.isEmpty) {
        Logger.info(
          '🎵 [AudioHandler] 开始预加载: ${nextSong.title}',
          'AudioHandler',
        );

        Future.microtask(() async {
          try {
            final audioUrl = await _urlService.getSongUrl(nextSong);
            if (audioUrl != null && audioUrl.isNotEmpty) {
              final songWithUrl = nextSong.copyWith(audioUrl: audioUrl);
              final updatedItem = songWithUrl.toMediaItem();
              _queue[nextIndex] = updatedItem;
              queue.add(List.unmodifiable(_queue));
              Logger.success(
                '🎵 [AudioHandler] 预加载完成: ${songWithUrl.title}',
                'AudioHandler',
              );
            }
          } catch (e) {
            Logger.error(
              '🎵 [AudioHandler] 预加载失败: ${nextSong.title}',
              e,
              null,
              'AudioHandler',
            );
          }
        });
      }
    }
  }

  int? _getNextIndex() => PlaybackIndexResolver.getNextIndex(
        currentIndex: _currentIndex,
        queueLength: _queue.length,
        repeatMode: _repeatMode,
        shuffleMode: _shuffleMode,
      );

  int? _getPreviousIndex() => PlaybackIndexResolver.getPreviousIndex(
        currentIndex: _currentIndex,
        queueLength: _queue.length,
        repeatMode: _repeatMode,
        shuffleMode: _shuffleMode,
      );

  /// 处理播放完成
  Future<void> _handlePlaybackCompleted() async {
    Logger.info('播放完成', 'AudioHandler');

    switch (_repeatMode) {
      case AudioServiceRepeatMode.one:
        try {
          await _audioPlayer.seek(Duration.zero);
          await _audioPlayer.resume();
        } catch (e, st) {
          Logger.error('单曲循环重播失败', e, st, 'AudioHandler');
        }
        break;

      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.none:
      case AudioServiceRepeatMode.group:
        unawaited(skipToNext());
        break;
    }
  }

  /// 广播播放状态
  void _broadcastState() {
    PlaybackStateTransformer.broadcastState(
      audioPlayer: _audioPlayer,
      currentIndex: _currentIndex,
      queue: _queue,
      pendingInitialPosition: _pendingInitialPosition,
      hasPendingInitialPosition: _hasPendingInitialPosition,
      isStopped: _isStopped,
      repeatMode: _repeatMode,
      shuffleMode: _shuffleMode,
      onStateReady: playbackState.add,
      onMediaItemUpdate: (item) {
        if (mediaItem.value?.id != item?.id) {
          mediaItem.add(item);
        }
      },
    );
  }

  // ========== 属性访问 ==========

  /// 当前播放位置
  Duration get position => _audioPlayer.position;

  /// 歌曲总时长
  Duration? get duration => _audioPlayer.duration;

  /// 是否正在播放
  bool get isPlaying => _audioPlayer.isPlaying;

  /// 当前播放索引
  int get currentIndex => _currentIndex;

  /// 当前播放队列（不可变副本）
  List<MediaItem> get currentQueue => List.unmodifiable(_queue);

  // ========== 资源清理 ==========

  /// 释放所有资源
  Future<void> dispose() async {
    Logger.info('释放 AudioHandler 资源', 'AudioHandler');

    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();

    await _audioPlayer.dispose();

    Logger.success('AudioHandler 资源释放完成', 'AudioHandler');
  }
}
