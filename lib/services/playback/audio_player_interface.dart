import 'dart:async';
import '../../models/song.dart';

/// 播放处理状态（映射 just_audio 的 ProcessingState）
enum PlayerProcessingState {
  idle,
  loading,
  buffering,
  ready,
  completed,
}

/// 播放事件（映射 just_audio 的 PlaybackEvent）
class PlayerPlaybackEvent {
  /// 对应 just_audio PlaybackEvent.updatePosition
  final Duration? updatePosition;
  final Duration? bufferedPosition;
  final Duration? duration;
  final int? currentIndex;

  const PlayerPlaybackEvent({
    this.updatePosition,
    this.bufferedPosition,
    this.duration,
    this.currentIndex,
  });
}

/// 统一的音频播放器接口
/// 支持桌面端（media_kit）和移动端（just_audio）
abstract class AudioPlayerInterface {
  /// 播放状态流
  Stream<bool> get playingStream;
  
  /// 播放位置流
  Stream<Duration> get positionStream;
  
  /// 播放进度流
  Stream<Duration?> get durationStream;
  
  /// 播放完成流
  Stream<void> get completionStream;
  
  /// 播放事件流（用于 audio_service 集成）
  Stream<PlayerPlaybackEvent> get playbackEventStream;
  
  /// 当前播放状态
  bool get isPlaying;
  
  /// 当前播放位置
  Duration get position;
  
  /// 当前缓冲位置
  Duration get bufferedPosition;
  
  /// 当前歌曲总时长
  Duration? get duration;
  
  /// 当前处理状态
  PlayerProcessingState get processingState;
  
  /// 音量 (0.0 - 1.0)
  double get volume;
  
  /// 播放速度
  double get speed;
  
  /// 播放歌曲
  Future<void> play(Song song);
  
  /// 暂停播放
  Future<void> pause();
  
  /// 继续播放
  Future<void> resume();
  
  /// 停止播放
  Future<void> stop();
  
  /// 跳转到指定位置
  Future<void> seek(Duration position);
  
  /// 设置音量
  Future<void> setVolume(double volume);
  
  /// 设置播放速度
  Future<void> setSpeed(double speed);
  
  /// 释放资源
  Future<void> dispose();
}
