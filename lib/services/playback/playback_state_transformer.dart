import 'package:audio_service/audio_service.dart';

import '../../utils/logger.dart';
import 'audio_player_interface.dart';

/// 播放状态转换辅助类，负责将播放器事件转换为 audio_service 的 PlaybackState
class PlaybackStateTransformer {
  /// 将 PlayerPlaybackEvent 转换为 audio_service 的 PlaybackState
  /// AudioService.position 会基于 updatePosition 自动外推位置
  static PlaybackState transformEvent({
    required PlayerPlaybackEvent event,
    required AudioPlayerInterface audioPlayer,
    required int currentIndex,
    required Duration? pendingInitialPosition,
    required bool hasPendingInitialPosition,
    required AudioServiceRepeatMode repeatMode,
    required AudioServiceShuffleMode shuffleMode,
  }) {
    Duration position = audioPlayer.position;

    if (!audioPlayer.isPlaying &&
        position == Duration.zero &&
        hasPendingInitialPosition &&
        pendingInitialPosition != null &&
        pendingInitialPosition > Duration.zero) {
      position = pendingInitialPosition;
    }

    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (audioPlayer.isPlaying) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: mapProcessingState(audioPlayer.processingState),
      playing: audioPlayer.isPlaying,
      updatePosition: position,
      bufferedPosition: audioPlayer.bufferedPosition,
      speed: audioPlayer.speed,
      queueIndex: event.currentIndex ?? currentIndex,
      repeatMode: repeatMode,
      shuffleMode: shuffleMode,
    );
  }

  /// 映射 PlayerProcessingState 到 audio_service AudioProcessingState
  static AudioProcessingState mapProcessingState(
    PlayerProcessingState state,
  ) {
    switch (state) {
      case PlayerProcessingState.idle:
        return AudioProcessingState.idle;
      case PlayerProcessingState.loading:
        return AudioProcessingState.loading;
      case PlayerProcessingState.buffering:
        return AudioProcessingState.buffering;
      case PlayerProcessingState.ready:
        return AudioProcessingState.ready;
      case PlayerProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  /// 广播播放状态（从播放器当前状态构建 PlaybackState）
  static void broadcastState({
    required AudioPlayerInterface audioPlayer,
    required int currentIndex,
    required List<MediaItem> queue,
    required Duration? pendingInitialPosition,
    required bool hasPendingInitialPosition,
    required bool isStopped,
    required AudioServiceRepeatMode repeatMode,
    required AudioServiceShuffleMode shuffleMode,
    required void Function(PlaybackState) onStateReady,
    required void Function(MediaItem?) onMediaItemUpdate,
  }) {
    bool playing = false;
    Duration position = Duration.zero;
    double speed = 1.0;

    try {
      playing = audioPlayer.isPlaying;
    } catch (e) {
      Logger.warning('获取播放状态失败: $e', 'AudioHandler');
    }

    try {
      position = audioPlayer.position;
    } catch (e) {
      Logger.warning('获取播放位置失败: $e', 'AudioHandler');
    }

    try {
      speed = audioPlayer.speed;
    } catch (e) {
      Logger.warning('获取播放速度失败: $e', 'AudioHandler');
    }

    if (!playing &&
        position == Duration.zero &&
        hasPendingInitialPosition &&
        pendingInitialPosition != null &&
        pendingInitialPosition > Duration.zero) {
      position = pendingInitialPosition;
    }

    final bufferedPosition = position;
    final processingState = _getProcessingState(
      audioPlayer: audioPlayer,
      queue: queue,
      isStopped: isStopped,
    );

    if (queue.isNotEmpty &&
        currentIndex >= 0 &&
        currentIndex < queue.length) {
      final currentItem = queue[currentIndex];
      onMediaItemUpdate(currentItem);
    }

    try {
      final state = PlaybackState(
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
        queueIndex: currentIndex,
        repeatMode: repeatMode,
        shuffleMode: shuffleMode,
      );
      onStateReady(state);
    } catch (e, stackTrace) {
      Logger.error(
        '[_broadcastState] 发送 playbackState 失败',
        e,
        stackTrace,
        'AudioHandler',
      );
    }
  }

  static AudioProcessingState _getProcessingState({
    required AudioPlayerInterface audioPlayer,
    required List<MediaItem> queue,
    required bool isStopped,
  }) {
    if (queue.isEmpty || isStopped) {
      return AudioProcessingState.idle;
    }

    try {
      final isPlaying = audioPlayer.isPlaying;

      if (isPlaying) {
        return AudioProcessingState.ready;
      }

      final position = audioPlayer.position;

      if (position.inSeconds > 0) {
        return AudioProcessingState.ready;
      } else {
        return AudioProcessingState.loading;
      }
    } catch (e) {
      Logger.warning('获取处理状态失败: $e', 'AudioHandler');
      return AudioProcessingState.idle;
    }
  }
}
