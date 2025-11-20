import 'dart:async';
import 'package:just_audio/just_audio.dart';
import '../models/song.dart';
import '../utils/logger.dart';
import 'audio_player_interface.dart';

/// 移动端音频播放器实现（使用 just_audio）
class MobileAudioPlayer implements AudioPlayerInterface {
  final AudioPlayer _player = AudioPlayer();
  
  // 状态控制器
  final StreamController<bool> _playingController = StreamController<bool>.broadcast();
  final StreamController<void> _completionController = StreamController<void>.broadcast();
  
  // 当前状态
  bool _isPlaying = false;
  double _volume = 1.0;
  double _speed = 1.0;
  
  // 订阅管理
  final List<StreamSubscription> _subscriptions = [];
  
  MobileAudioPlayer() {
    _initializePlayer();
  }
  
  void _initializePlayer() {
    Logger.info('初始化移动端音频播放器', 'MobileAudioPlayer');
    
    // 监听播放状态变化
    _subscriptions.add(_player.playingStream.listen((playing) {
      if (_isPlaying != playing) {
        _isPlaying = playing;
        _playingController.add(playing);
        Logger.debug('播放状态变化: $playing', 'MobileAudioPlayer');
      }
    }));
    
    // 监听播放完成
    _subscriptions.add(_player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        _completionController.add(null);
        Logger.debug('播放完成', 'MobileAudioPlayer');
      }
    }));
  }
  
  @override
  Stream<bool> get playingStream => _playingController.stream;
  
  @override
  Stream<Duration> get positionStream => _player.positionStream;
  
  @override
  Stream<Duration?> get durationStream => _player.durationStream;
  
  @override
  Stream<void> get completionStream => _completionController.stream;
  
  @override
  bool get isPlaying => _isPlaying;
  
  @override
  Duration get position => _player.position;
  
  @override
  Duration? get duration => _player.duration;
  
  @override
  double get volume => _volume;
  
  @override
  double get speed => _speed;
  
  @override
  Future<void> play(Song song) async {
    try {
      Logger.info('播放歌曲: ${song.title} - ${song.artist}', 'MobileAudioPlayer');
      Logger.debug('播放链接: ${song.audioUrl.length > 100 ? song.audioUrl.substring(0, 100) + "..." : song.audioUrl}', 'MobileAudioPlayer');
      
      if (song.audioUrl.isEmpty) {
        throw Exception('歌曲播放链接为空');
      }
      
      
      // 设置音频源
      AudioSource audioSource;
      if (song.audioUrl.startsWith('http')) {
        audioSource = AudioSource.uri(Uri.parse(song.audioUrl));
      } else if (song.audioUrl.startsWith('file://')) {
        audioSource = AudioSource.file(song.audioUrl.substring(7));
      } else {
        audioSource = AudioSource.file(song.audioUrl);
      }
      
      await _player.setAudioSource(audioSource);
      
      // 应用当前设置
      await _player.setVolume(_volume);
      await _player.setSpeed(_speed);
      
      // 开始播放
      await _player.play();
      
      Logger.success('歌曲播放成功', 'MobileAudioPlayer');
    } catch (e) {
      Logger.error('播放歌曲失败: ${song.title}', e, null, 'MobileAudioPlayer');
      rethrow;
    }
  }
  
  @override
  Future<void> pause() async {
    try {
      await _player.pause();
      Logger.debug('暂停播放', 'MobileAudioPlayer');
    } catch (e) {
      Logger.error('暂停播放失败', e, null, 'MobileAudioPlayer');
      rethrow;
    }
  }
  
  @override
  Future<void> resume() async {
    try {
      await _player.play();
      Logger.debug('继续播放', 'MobileAudioPlayer');
    } catch (e) {
      Logger.error('继续播放失败', e, null, 'MobileAudioPlayer');
      rethrow;
    }
  }
  
  @override
  Future<void> stop() async {
    try {
      await _player.stop();
      Logger.debug('停止播放', 'MobileAudioPlayer');
    } catch (e) {
      Logger.error('停止播放失败', e, null, 'MobileAudioPlayer');
      rethrow;
    }
  }
  
  @override
  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
      Logger.debug('跳转到位置: ${position.inSeconds}s', 'MobileAudioPlayer');
    } catch (e) {
      Logger.error('跳转失败', e, null, 'MobileAudioPlayer');
      rethrow;
    }
  }
  
  @override
  Future<void> setVolume(double volume) async {
    try {
      _volume = volume.clamp(0.0, 1.0);
      await _player.setVolume(_volume);
      Logger.debug('设置音量: $_volume', 'MobileAudioPlayer');
    } catch (e) {
      Logger.error('设置音量失败', e, null, 'MobileAudioPlayer');
      rethrow;
    }
  }
  
  @override
  Future<void> setSpeed(double speed) async {
    try {
      _speed = speed.clamp(0.25, 3.0);
      await _player.setSpeed(_speed);
      Logger.debug('设置播放速度: $_speed', 'MobileAudioPlayer');
    } catch (e) {
      Logger.error('设置播放速度失败', e, null, 'MobileAudioPlayer');
      rethrow;
    }
  }
  
  @override
  Future<void> dispose() async {
    Logger.info('释放移动端音频播放器资源', 'MobileAudioPlayer');
    
    // 取消所有订阅
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    
    // 关闭流控制器
    await _playingController.close();
    await _completionController.close();
    
    // 释放播放器
    await _player.dispose();
    
    Logger.success('移动端音频播放器资源释放完成', 'MobileAudioPlayer');
  }
}
