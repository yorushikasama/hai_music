import 'dart:math';

import 'package:audio_service/audio_service.dart';

/// 播放索引计算辅助类，处理随机/循环模式下的下一首/上一首逻辑
class PlaybackIndexResolver {
  /// 根据当前播放模式和队列状态计算下一首索引
  static int? getNextIndex({
    required int currentIndex,
    required int queueLength,
    required AudioServiceRepeatMode repeatMode,
    required AudioServiceShuffleMode shuffleMode,
  }) {
    if (queueLength == 0) return null;

    if (shuffleMode == AudioServiceShuffleMode.all && queueLength > 1) {
      final random = Random();
      int nextIndex = currentIndex;
      int attempts = 0;
      const maxAttempts = 10;

      while (attempts < maxAttempts && nextIndex == currentIndex) {
        nextIndex = random.nextInt(queueLength);
        attempts++;
      }

      return nextIndex;
    }

    switch (repeatMode) {
      case AudioServiceRepeatMode.one:
        return currentIndex;

      case AudioServiceRepeatMode.all:
        return (currentIndex + 1) % queueLength;

      case AudioServiceRepeatMode.none:
      case AudioServiceRepeatMode.group:
        if (currentIndex < queueLength - 1) {
          return currentIndex + 1;
        }
        return null;
    }
  }

  /// 根据当前播放模式和队列状态计算上一首索引
  static int? getPreviousIndex({
    required int currentIndex,
    required int queueLength,
    required AudioServiceRepeatMode repeatMode,
    required AudioServiceShuffleMode shuffleMode,
  }) {
    if (queueLength == 0) return null;

    if (shuffleMode == AudioServiceShuffleMode.all && queueLength > 1) {
      final random = Random();
      int prevIndex = currentIndex;
      int attempts = 0;
      const maxAttempts = 10;

      while (attempts < maxAttempts && prevIndex == currentIndex) {
        prevIndex = random.nextInt(queueLength);
        attempts++;
      }

      return prevIndex;
    }

    switch (repeatMode) {
      case AudioServiceRepeatMode.one:
        return currentIndex;

      case AudioServiceRepeatMode.all:
        return (currentIndex - 1 + queueLength) % queueLength;

      case AudioServiceRepeatMode.none:
      case AudioServiceRepeatMode.group:
        if (currentIndex > 0) {
          return currentIndex - 1;
        }
        return null;
    }
  }
}
