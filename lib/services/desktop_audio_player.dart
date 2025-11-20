import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import '../models/song.dart';
import '../utils/logger.dart';
import 'audio_player_interface.dart';

/// 桌面端音频播放器实现（使用 audioplayers）
class DesktopAudioPlayer implements AudioPlayerInterface {
  final AudioPlayer _player = AudioPlayer();
  
  // 状态控制器
  final StreamController<bool> _playingController = StreamController<bool>.broadcast();
  final StreamController<Duration> _positionController = StreamController<Duration>.broadcast();
  final StreamController<Duration?> _durationController = StreamController<Duration?>.broadcast();
  final StreamController<void> _completionController = StreamController<void>.broadcast();
  
  // 当前状态
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration? _duration;
  double _volume = 1.0;
  double _speed = 1.0;
  
  // 订阅管理
  final List<StreamSubscription> _subscriptions = [];
  
  DesktopAudioPlayer() {
    _initializePlayer();
  }
  
  void _initializePlayer() {
    Logger.info('初始化桌面端音频播放器', 'DesktopAudioPlayer');
    
    // 监听播放状态变化
    _subscriptions.add(_player.onPlayerStateChanged.listen((state) {
      final wasPlaying = _isPlaying;
      _isPlaying = state == PlayerState.playing;
      
      if (wasPlaying != _isPlaying) {
        _playingController.add(_isPlaying);
        Logger.debug('播放状态变化: $_isPlaying', 'DesktopAudioPlayer');
      }
      
      // 播放完成处理
      if (state == PlayerState.completed) {
        _completionController.add(null);
        Logger.debug('播放完成', 'DesktopAudioPlayer');
      }
    }));
    
    // 监听播放位置变化
    _subscriptions.add(_player.onPositionChanged.listen((position) {
      _position = position;
      _positionController.add(position);
    }));
    
    // 监听时长变化
    _subscriptions.add(_player.onDurationChanged.listen((duration) {
      _duration = duration;
      _durationController.add(duration);
    }));
  }
  
  @override
  Stream<bool> get playingStream => _playingController.stream;
  
  @override
  Stream<Duration> get positionStream => _positionController.stream;
  
  @override
  Stream<Duration?> get durationStream => _durationController.stream;
  
  @override
  Stream<void> get completionStream => _completionController.stream;
  
  @override
  bool get isPlaying => _isPlaying;
  
  @override
  Duration get position => _position;
  
  @override
  Duration? get duration => _duration;
  
  @override
  double get volume => _volume;
  
  @override
  double get speed => _speed;
  
  @override
  Future<void> play(Song song) async {
    try {
      Logger.info('播放歌曲: ${song.title} - ${song.artist}', 'DesktopAudioPlayer');
      
      if (song.audioUrl.isEmpty) {
        throw Exception('歌曲播放链接为空');
      }
      
      
      // 设置音频源并播放
      if (song.audioUrl.startsWith('http')) {
        await _player.play(UrlSource(song.audioUrl));
      } else if (song.audioUrl.startsWith('file://')) {
        await _player.play(DeviceFileSource(song.audioUrl.substring(7)));
      } else {
        await _player.play(DeviceFileSource(song.audioUrl));
      }
      
      // 应用当前设置
      await _player.setVolume(_volume);
      await _player.setPlaybackRate(_speed);
      
      Logger.success('歌曲播放成功', 'DesktopAudioPlayer');
    } catch (e) {
      Logger.error('播放歌曲失败: ${song.title}', e, null, 'DesktopAudioPlayer');
      rethrow;
    }
  }
  
  @override
  Future<void> pause() async {
    try {
      await _player.pause();
      Logger.debug('暂停播放', 'DesktopAudioPlayer');
    } catch (e) {
      Logger.error('暂停播放失败', e, null, 'DesktopAudioPlayer');
      rethrow;
    }
  }
  
  @override
  Future<void> resume() async {
    try {
      await _player.resume();
      Logger.debug('继续播放', 'DesktopAudioPlayer');
    } catch (e) {
      Logger.error('继续播放失败', e, null, 'DesktopAudioPlayer');
      rethrow;
    }
  }
  
  @override
  Future<void> stop() async {
    try {
      await _player.stop();
      _position = Duration.zero;
      _duration = null;
      Logger.debug('停止播放', 'DesktopAudioPlayer');
    } catch (e) {
      Logger.error('停止播放失败', e, null, 'DesktopAudioPlayer');
      rethrow;
    }
  }
  
  @override
  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
      Logger.debug('跳转到位置: ${position.inSeconds}s', 'DesktopAudioPlayer');
    } catch (e) {
      Logger.error('跳转失败', e, null, 'DesktopAudioPlayer');
      rethrow;
    }
  }
  
  @override
  Future<void> setVolume(double volume) async {
    try {
      _volume = volume.clamp(0.0, 1.0);
      await _player.setVolume(_volume);
      Logger.debug('设置音量: $_volume', 'DesktopAudioPlayer');
    } catch (e) {
      Logger.error('设置音量失败', e, null, 'DesktopAudioPlayer');
      rethrow;
    }
  }
  
  @override
  Future<void> setSpeed(double speed) async {
    try {
      _speed = speed.clamp(0.25, 3.0);
      await _player.setPlaybackRate(_speed);
      Logger.debug('设置播放速度: $_speed', 'DesktopAudioPlayer');
    } catch (e) {
      Logger.error('设置播放速度失败', e, null, 'DesktopAudioPlayer');
      rethrow;
    }
  }
  
  @override
  Future<void> dispose() async {
    Logger.info('释放桌面端音频播放器资源', 'DesktopAudioPlayer');
    
    // 取消所有订阅
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    
    // 关闭流控制器
    await _playingController.close();
    await _positionController.close();
    await _durationController.close();
    await _completionController.close();
    
    // 释放播放器
    await _player.dispose();
    
    Logger.success('桌面端音频播放器资源释放完成', 'DesktopAudioPlayer');
  }
}
