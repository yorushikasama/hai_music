import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song.dart';

/// 音频处理服务，负责后台播放和系统媒体控制
class MusicAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  
  // 播放列表
  List<MediaItem> _queue = [];
  int _currentIndex = 0;
  LoopMode _loopMode = LoopMode.off;
  bool _shuffleModeEnabled = false;
  bool _hasTriggeredCompletion = false; // 防止重复触发

  MusicAudioHandler() {
    _init();
  }

  void _init() {
    // 监听播放状态变化
    _player.playbackEventStream.listen((event) {
      _broadcastState();
    });

    // 监听播放位置，检测播放完成
    _player.positionStream.listen((position) {
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

    // 监听播放完成（备用方案）
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (!_hasTriggeredCompletion) {
          _hasTriggeredCompletion = true;
          _handlePlaybackCompleted();
        }
      }
    });

    // 监听当前播放项变化
    _player.currentIndexStream.listen((index) {
      if (index != null && index < _queue.length) {
        _currentIndex = index;
        mediaItem.add(_queue[index]);
      }
    });

    // 监听播放顺序变化
    _player.sequenceStateStream.listen((sequenceState) {
      if (sequenceState != null) {
        _queue = sequenceState.effectiveSequence
            .map((source) => source.tag as MediaItem)
            .toList();
        queue.add(_queue);
      }
    });
  }

  /// 广播播放状态
  void _broadcastState() {
    playbackState.add(PlaybackState(
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
      androidCompactActionIndices: const [0, 1, 2],
      processingState: _getProcessingState(),
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: _currentIndex,
    ));
  }

  /// 获取处理状态
  AudioProcessingState _getProcessingState() {
    switch (_player.processingState) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  /// 播放完成回调（由外部设置）
  Function? onPlaybackCompleted;

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

  /// 从歌曲列表创建播放队列
  Future<void> setQueueFromSongs(List<Song> songs, {int initialIndex = 0}) async {
    _queue = songs.map((song) => _songToMediaItem(song)).toList();
    queue.add(_queue);
    
    final playlist = ConcatenatingAudioSource(
      children: songs.map((song) {
        if (song.audioUrl.isEmpty) {
          print('⚠️ 警告: 音频URL为空 - ${song.title}');
        }
        return AudioSource.uri(
          Uri.parse(song.audioUrl),
          tag: _songToMediaItem(song),
        );
      }).toList(),
    );
    
    await _player.setAudioSource(playlist, initialIndex: initialIndex);
    _currentIndex = initialIndex;
    mediaItem.add(_queue[initialIndex]);
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
      album: song.album ?? '',
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
    if (_currentIndex < _queue.length - 1) {
      await _player.seekToNext();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_currentIndex > 0) {
      await _player.seekToPrevious();
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

  @override
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
    switch (name) {
      case 'setAudioQuality':
        // 处理音质切换
        final quality = extras?['quality'] as String?;
        if (quality != null) {
          // 重新加载当前歌曲
          final currentPos = _player.position;
          final wasPlaying = _player.playing;
          
          // 这里需要重新获取音频 URL，由外部处理
          // 只是保存位置和播放状态
          if (wasPlaying) {
            await _player.seek(currentPos);
            await _player.play();
          }
        }
        break;
    }
  }

  @override
  Future<void> onTaskRemoved() async {
    // Android 任务被移除时的处理
    // 可以选择停止播放或继续后台播放
    await stop();
  }
}
