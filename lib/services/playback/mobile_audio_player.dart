import 'dart:async';
import 'package:just_audio/just_audio.dart';
import '../../models/song.dart';
import '../../utils/logger.dart';
import 'audio_player_interface.dart';

class MobileAudioPlayer implements AudioPlayerInterface {
  AudioPlayer? _player;
  bool _isDisposed = false;
  Completer<void>? _initLock;

  final StreamController<bool> _playingController = StreamController<bool>.broadcast();
  final StreamController<void> _completionController = StreamController<void>.broadcast();

  final List<StreamSubscription<void>> _subscriptions = [];

  MobileAudioPlayer() {
    Logger.info('【构造函数】MobileAudioPlayer 创建', 'MobileAudioPlayer');
    _initialize();
  }

  Future<void> _ensureInitialized() async {
    if (_player != null || _isDisposed) return;
    if (_initLock != null) {
      await _initLock!.future;
      return;
    }
    _initLock = Completer<void>();
    try {
      await _initialize();
      _initLock!.complete();
    } catch (e) {
      _initLock!.completeError(e);
      _initLock = null;
      rethrow;
    }
  }

  Future<void> _initialize() async {
    Logger.info('【初始化】开始初始化移动端音频播放器', 'MobileAudioPlayer');

    if (_isDisposed) {
      Logger.warning('【初始化】播放器已释放，跳过初始化', 'MobileAudioPlayer');
      return;
    }

    try {
      _player = AudioPlayer();
      Logger.info('【初始化】AudioPlayer 创建成功', 'MobileAudioPlayer');
    } catch (e, stackTrace) {
      Logger.error('【初始化】AudioPlayer 创建失败', e, stackTrace, 'MobileAudioPlayer');
      return;
    }

    Logger.info('【初始化】设置播放状态监听...', 'MobileAudioPlayer');
    _subscriptions.add(_player!.playingStream.listen((playing) {
      _playingController.add(playing);
    }));

    Logger.info('【初始化】设置处理状态监听...', 'MobileAudioPlayer');
    _subscriptions.add(_player!.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        Logger.info('【状态】播放完成', 'MobileAudioPlayer');
        _completionController.add(null);
      }
    }));

    Logger.info('【初始化】设置播放事件监听...', 'MobileAudioPlayer');
    _subscriptions.add(_player!.playbackEventStream.listen(
      (event) {
      },
      onError: (Object e, StackTrace stackTrace) {
        Logger.error('【错误】playbackEventStream 错误', e, stackTrace, 'MobileAudioPlayer');
      },
    ));

    Logger.success('【初始化】移动端音频播放器初始化完成', 'MobileAudioPlayer');
  }

  AudioPlayer get _safePlayer {
    if (_player == null) {
      throw StateError('AudioPlayer 未初始化');
    }
    if (_isDisposed) {
      throw StateError('AudioPlayer 已释放');
    }
    return _player!;
  }

  @override
  Stream<bool> get playingStream => _playingController.stream;

  @override
  Stream<Duration> get positionStream => _safePlayer.positionStream;

  @override
  Stream<Duration?> get durationStream => _safePlayer.durationStream;

  @override
  Stream<void> get completionStream => _completionController.stream;

  @override
  Stream<PlayerPlaybackEvent> get playbackEventStream =>
      _safePlayer.playbackEventStream.map((event) => PlayerPlaybackEvent(
            updatePosition: event.updatePosition,
            bufferedPosition: event.bufferedPosition,
            duration: event.duration,
            currentIndex: event.currentIndex,
          ));

  @override
  bool get isPlaying => _safePlayer.playing;

  @override
  Duration get position => _safePlayer.position;

  @override
  Duration get bufferedPosition => _safePlayer.bufferedPosition;

  @override
  Duration? get duration => _safePlayer.duration;

  @override
  PlayerProcessingState get processingState {
    switch (_safePlayer.processingState) {
      case ProcessingState.idle:
        return PlayerProcessingState.idle;
      case ProcessingState.loading:
        return PlayerProcessingState.loading;
      case ProcessingState.buffering:
        return PlayerProcessingState.buffering;
      case ProcessingState.ready:
        return PlayerProcessingState.ready;
      case ProcessingState.completed:
        return PlayerProcessingState.completed;
    }
  }

  @override
  double get volume => _safePlayer.volume;

  @override
  double get speed => _safePlayer.speed;

  @override
  Future<void> play(Song song) async {
    Logger.info('【播放】开始播放歌曲: ${song.title}', 'MobileAudioPlayer');
    Logger.info('【播放】音频URL: ${song.audioUrl}', 'MobileAudioPlayer');

    if (_isDisposed) {
      Logger.error('【播放】播放器已释放', null, null, 'MobileAudioPlayer');
      return;
    }

    if (_player == null) {
      Logger.info('【播放】播放器未初始化，重新初始化...', 'MobileAudioPlayer');
      await _ensureInitialized();
    }

    try {
      if (song.audioUrl.isEmpty) {
        Logger.error('【播放】歌曲播放链接为空', null, null, 'MobileAudioPlayer');
        return;
      }

      Logger.info('【播放】设置音频源...', 'MobileAudioPlayer');
      Duration? duration;
      try {
        if (song.audioUrl.startsWith('http')) {
          Logger.info('【播放】使用 setUrl 加载网络音频', 'MobileAudioPlayer');
          await _safePlayer.stop();
          duration = await _safePlayer.setUrl(song.audioUrl);
        } else if (song.audioUrl.startsWith('content://')) {
          Logger.info('【播放】使用 setUrl 加载 content URI', 'MobileAudioPlayer');
          await _safePlayer.stop();
          duration = await _safePlayer.setUrl(song.audioUrl);
        } else if (song.audioUrl.startsWith('file://')) {
          await _safePlayer.stop();
          try {
            final filePath = Uri.parse(song.audioUrl).toFilePath();
            duration = await _safePlayer.setFilePath(filePath);
          } on FormatException {
            Logger.warning('【播放】file:// URI 解析失败，尝试 setUrl', 'MobileAudioPlayer');
            duration = await _safePlayer.setUrl(song.audioUrl);
          } catch (e) {
            Logger.warning('【播放】setFilePath 失败，尝试 setUrl: $e', 'MobileAudioPlayer');
            duration = await _safePlayer.setUrl(song.audioUrl);
          }
        } else {
          await _safePlayer.stop();
          try {
            Logger.info('【播放】使用 setFilePath 加载本地文件(默认)', 'MobileAudioPlayer');
            duration = await _safePlayer.setFilePath(song.audioUrl);
          } catch (e) {
            Logger.warning('【播放】setFilePath 失败，尝试 setUrl: $e', 'MobileAudioPlayer');
            duration = await _safePlayer.setUrl(Uri.file(song.audioUrl).toString());
          }
        }
        Logger.info('【播放】音频加载成功，时长: ${duration?.inSeconds}s', 'MobileAudioPlayer');
      } catch (e, stackTrace) {
        Logger.error('【播放】设置音频源失败', e, stackTrace, 'MobileAudioPlayer');
        rethrow;
      }

      // 确保播放器处于准备状态
      final currentState = _safePlayer.processingState;
      Logger.info('【播放】当前处理状态: $currentState', 'MobileAudioPlayer');

      if (currentState == ProcessingState.ready || currentState == ProcessingState.idle) {
        Logger.info('【播放】调用 player.play()...', 'MobileAudioPlayer');
        try {
          await _safePlayer.play();
          Logger.success('【播放】player.play() 调用成功', 'MobileAudioPlayer');
        } catch (e, stackTrace) {
          Logger.error('【播放】player.play() 调用失败', e, stackTrace, 'MobileAudioPlayer');
          rethrow;
        }
      } else {
        Logger.warning('【播放】播放器未准备好，当前状态: $currentState', 'MobileAudioPlayer');
        await for (final state in _safePlayer.processingStateStream) {
          Logger.info('【播放】等待播放器准备，当前状态: $state', 'MobileAudioPlayer');
          if (state == ProcessingState.ready) {
            Logger.info('【播放】播放器已准备好，开始播放...', 'MobileAudioPlayer');
            await _safePlayer.play().timeout(const Duration(seconds: 15));
            Logger.success('【播放】player.play() 调用成功', 'MobileAudioPlayer');
            break;
          }
          if (state == ProcessingState.idle || state == ProcessingState.completed) {
            Logger.error('【播放】播放器进入异常状态: $state', null, null, 'MobileAudioPlayer');
            break;
          }
        }
      }

      Logger.success('【播放】歌曲播放流程完成: ${song.title}', 'MobileAudioPlayer');
    } on PlayerException catch (e, stackTrace) {
      Logger.error('【播放】播放器异常: code=${e.code}, message=${e.message}', e, stackTrace, 'MobileAudioPlayer');
      rethrow;
    } on PlayerInterruptedException catch (e, stackTrace) {
      Logger.error('【播放】播放中断: ${e.message}', e, stackTrace, 'MobileAudioPlayer');
      rethrow;
    } catch (e, stackTrace) {
      Logger.error('【播放】播放失败: $e', e, stackTrace, 'MobileAudioPlayer');
      rethrow;
    }
  }

  @override
  Future<void> pause() async {
    Logger.info('【暂停】调用 pause()', 'MobileAudioPlayer');
    if (_isDisposed || _player == null) {
      Logger.warning('【暂停】播放器未初始化或已释放', 'MobileAudioPlayer');
      return;
    }
    try {
      await _safePlayer.pause();
      Logger.info('【暂停】pause() 调用成功', 'MobileAudioPlayer');
    } catch (e, stackTrace) {
      Logger.error('【暂停】pause() 调用失败', e, stackTrace, 'MobileAudioPlayer');
    }
  }

  @override
  Future<void> resume() async {
    Logger.info('【恢复】调用 play()', 'MobileAudioPlayer');
    if (_isDisposed || _player == null) {
      Logger.warning('【恢复】播放器未初始化或已释放', 'MobileAudioPlayer');
      return;
    }
    try {
      await _safePlayer.play();
      Logger.info('【恢复】play() 调用成功', 'MobileAudioPlayer');
    } catch (e, stackTrace) {
      Logger.error('【恢复】play() 调用失败', e, stackTrace, 'MobileAudioPlayer');
    }
  }

  @override
  Future<void> stop() async {
    Logger.info('【停止】调用 stop()', 'MobileAudioPlayer');
    if (_isDisposed || _player == null) {
      Logger.warning('【停止】播放器未初始化或已释放', 'MobileAudioPlayer');
      return;
    }
    try {
      await _safePlayer.stop();
      Logger.info('【停止】stop() 调用成功', 'MobileAudioPlayer');
    } catch (e, stackTrace) {
      Logger.error('【停止】stop() 调用失败', e, stackTrace, 'MobileAudioPlayer');
    }
  }

  @override
  Future<void> seek(Duration position) async {
    Logger.info('【跳转】调用 seek($position)', 'MobileAudioPlayer');
    if (_isDisposed || _player == null) {
      Logger.warning('【跳转】播放器未初始化或已释放', 'MobileAudioPlayer');
      return;
    }
    try {
      await _safePlayer.seek(position);
      Logger.info('【跳转】seek() 调用成功', 'MobileAudioPlayer');
    } catch (e, stackTrace) {
      Logger.error('【跳转】seek() 调用失败', e, stackTrace, 'MobileAudioPlayer');
    }
  }

  @override
  Future<void> setVolume(double volume) async {
    Logger.info('【音量】设置音量: $volume', 'MobileAudioPlayer');
    if (_isDisposed || _player == null) {
      Logger.warning('【音量】播放器未初始化或已释放', 'MobileAudioPlayer');
      return;
    }
    try {
      await _safePlayer.setVolume(volume.clamp(0.0, 1.0));
      Logger.info('【音量】设置音量成功', 'MobileAudioPlayer');
    } catch (e, stackTrace) {
      Logger.error('【音量】设置音量失败', e, stackTrace, 'MobileAudioPlayer');
    }
  }

  @override
  Future<void> setSpeed(double speed) async {
    Logger.info('【速度】设置速度: $speed', 'MobileAudioPlayer');
    if (_isDisposed || _player == null) {
      Logger.warning('【速度】播放器未初始化或已释放', 'MobileAudioPlayer');
      return;
    }
    try {
      await _safePlayer.setSpeed(speed.clamp(0.25, 3.0));
      Logger.info('【速度】设置速度成功', 'MobileAudioPlayer');
    } catch (e, stackTrace) {
      Logger.error('【速度】设置速度失败', e, stackTrace, 'MobileAudioPlayer');
    }
  }

  @override
  Future<void> dispose() async {
    Logger.info('【释放】开始释放移动端音频播放器资源', 'MobileAudioPlayer');

    _isDisposed = true;

    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();

    await _playingController.close();
    await _completionController.close();

    if (_player != null) {
      await _player!.dispose();
      _player = null;
    }

    Logger.success('【释放】移动端音频播放器资源释放完成', 'MobileAudioPlayer');
  }
}
