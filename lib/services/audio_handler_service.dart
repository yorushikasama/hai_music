import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song.dart';
import '../utils/logger.dart';

/// 🔧 重新设计的音频处理服务
/// 核心理念：单曲播放模式，简化状态管理
class MusicAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  
  List<MediaItem> _queue = [];
  int _currentIndex = 0;
  final List<StreamSubscription> _subscriptions = [];
  
  static const bool _enableDebugLog = true;

  MusicAudioHandler() {
    _init();
  }

  void _log(String message) {
    if (_enableDebugLog) print(message);
  }

  void _init() {
    // 自动同步播放状态到系统通知
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);

    // 监听当前播放项变化
    _subscriptions.add(_player.currentIndexStream.listen((index) {
      if (index != null && index < _queue.length) {
        _currentIndex = index;
        mediaItem.add(_queue[index]);
        _log('🎵 当前播放: ${_queue[index].title}');
      }
    }));

    // 监听播放完成 - 由外部处理（MusicProvider）
    _subscriptions.add(_player.playerStateStream
        .where((state) => state.processingState == ProcessingState.completed)
        .listen((_) {
      _log('🎬 播放完成');
      onPlaybackCompleted?.call();
    }));
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      androidCompactActionIndices: const [0, 1, 2],
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

  // 回调函数
  Function? onPlaybackCompleted;
  Function? onSkipToNext;
  Function? onSkipToPrevious;

  /// 🔧 新设计：直接播放单首歌曲
  /// 不维护队列，每次都是单曲播放
  Future<void> playSingleSong(Song song, {List<Song>? displayQueue}) async {
    if (song.audioUrl.isEmpty) {
      _log('❌ 歌曲URL为空: ${song.title}');
      return;
    }

    try {
      final stopwatch = Stopwatch()..start();
      _log('▶️ 播放: ${song.title}');
      
      // 🔧 关键修复：先更新 mediaItem，确保通知栏立即显示正确的歌曲
      final currentMediaItem = _songToMediaItem(song);
      mediaItem.add(currentMediaItem);
      
      // 🔧 关键修复：更新显示队列时，将当前播放的歌曲放在队列的第一位
      // 这样即使 currentIndexStream 触发 index=0，也会显示正确的歌曲
      if (displayQueue != null && displayQueue.isNotEmpty) {
        // 找到当前歌曲在队列中的位置
        final currentIndex = displayQueue.indexWhere((s) => s.id == song.id);
        
        // 重新排列队列：当前歌曲放在第一位
        final List<Song> reorderedQueue = [];
        if (currentIndex >= 0) {
          reorderedQueue.add(displayQueue[currentIndex]);
          reorderedQueue.addAll(displayQueue.where((s) => s.id != song.id));
        } else {
          reorderedQueue.addAll(displayQueue);
        }
        
        _queue = reorderedQueue.map((s) => _songToMediaItem(s)).toList();
        queue.add(_queue);
      }
      
      // 创建单曲播放源
      final source = AudioSource.uri(
        Uri.parse(song.audioUrl),
        tag: currentMediaItem,
      );

      // 直接设置并播放
      await _player.setAudioSource(source);
      await _player.play();
      
      stopwatch.stop();
      _log('✅ 播放成功，耗时: ${stopwatch.elapsedMilliseconds}ms');
    } catch (e) {
      Logger.error('播放器错误', e, null, 'AudioHandler');
      rethrow;
    }
  }

  MediaItem _songToMediaItem(Song song) {
    return MediaItem(
      id: song.id,
      album: song.album,
      title: song.title,
      artist: song.artist,
      duration: song.duration != null ? Duration(seconds: song.duration!) : null,
      artUri: Uri.tryParse(song.r2CoverUrl ?? song.coverUrl),
    );
  }

  // ========== AudioHandler 接口实现 ==========

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    _log('⏭️ 下一首（系统通知栏）');
    onSkipToNext?.call();
  }

  @override
  Future<void> skipToPrevious() async {
    _log('⏮️ 上一首（系统通知栏）');
    onSkipToPrevious?.call();
  }

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  Future<void> setVolume(double volume) => _player.setVolume(volume);

  Future<void> clearQueue() async {
    await _player.stop();
    _queue.clear();
    queue.add(_queue);
  }

  // ========== 属性访问 ==========

  Duration get position => _player.position;
  Duration? get duration => _player.duration;
  bool get isPlaying => _player.playing;
  int get currentIndex => _currentIndex;

  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _player.dispose();
  }
}
