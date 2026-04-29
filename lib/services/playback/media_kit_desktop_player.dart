import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import '../../models/song.dart';
import '../../utils/logger.dart';
import 'audio_player_interface.dart';

class MediaKitDesktopPlayer implements AudioPlayerInterface {
  static bool _mediaKitInitialized = false;
  late final AudioPlayer _player;

  final StreamController<bool> _playingController = StreamController<bool>.broadcast();
  final StreamController<Duration> _positionController = StreamController<Duration>.broadcast();
  final StreamController<Duration?> _durationController = StreamController<Duration?>.broadcast();
  final StreamController<void> _completionController = StreamController<void>.broadcast();

  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration? _duration;
  double _volume = 1.0;
  double _speed = 1.0;

  final List<StreamSubscription<void>> _subscriptions = [];

  MediaKitDesktopPlayer() {
    _ensureMediaKitInit();
    _player = AudioPlayer();
    _initializePlayer();
  }

  static void _ensureMediaKitInit() {
    if (_mediaKitInitialized) return;
    JustAudioMediaKit.ensureInitialized(
      macOS: true,
    );
    JustAudioMediaKit.bufferSize = 50 * 1024 * 1024;
    _mediaKitInitialized = true;
    Logger.info('MediaKit 后端已初始化 (libmpv)', 'MediaKitPlayer');
  }

  void _initializePlayer() {
    Logger.info('初始化桌面端音频播放器 (just_audio + media_kit)', 'MediaKitPlayer');

    _subscriptions.add(_player.playingStream.listen((playing) {
      final wasPlaying = _isPlaying;
      _isPlaying = playing;
      if (wasPlaying != playing) {
        _playingController.add(playing);
      }
    }));

    _subscriptions.add(_player.positionStream.listen((position) {
      _position = position;
      _positionController.add(position);
    }));

    _subscriptions.add(_player.durationStream.listen((duration) {
      _duration = duration;
      _durationController.add(duration);
    }));

    _subscriptions.add(_player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _completionController.add(null);
      }
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
  Stream<PlayerPlaybackEvent> get playbackEventStream =>
      _player.playbackEventStream.map((event) => PlayerPlaybackEvent(
            updatePosition: event.updatePosition,
            bufferedPosition: event.bufferedPosition,
            duration: event.duration,
            currentIndex: event.currentIndex,
          ));

  @override
  bool get isPlaying => _isPlaying;

  @override
  Duration get position => _position;

  @override
  Duration get bufferedPosition => _player.bufferedPosition;

  @override
  Duration? get duration => _duration;

  @override
  PlayerProcessingState get processingState {
    switch (_player.processingState) {
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
  double get volume => _volume;

  @override
  double get speed => _speed;

  @override
  Future<void> play(Song song) async {
    try {
      Logger.info('播放歌曲: ${song.title} - ${song.artist}', 'MediaKitPlayer');

      if (song.audioUrl.isEmpty) {
        throw Exception('歌曲播放链接为空');
      }

      final stopwatch = Stopwatch()..start();

      final source = _createAudioSource(song.audioUrl);
      await _player.setAudioSource(source);

      stopwatch.stop();
      Logger.info('音频源加载耗时: ${stopwatch.elapsedMilliseconds}ms', 'MediaKitPlayer');

      await _player.setVolume(_volume);
      await _player.setSpeed(_speed);
      await _player.play();

      Logger.success('歌曲播放成功', 'MediaKitPlayer');
    } catch (e) {
      Logger.error('播放歌曲失败: ${song.title}', e, null, 'MediaKitPlayer');
      rethrow;
    }
  }

  AudioSource _createAudioSource(String audioUrl) {
    if (audioUrl.startsWith('http')) {
      return AudioSource.uri(Uri.parse(audioUrl));
    } else if (audioUrl.startsWith('content://')) {
      return AudioSource.uri(Uri.parse(audioUrl));
    } else if (audioUrl.startsWith('file://')) {
      return AudioSource.uri(Uri.parse(audioUrl));
    } else {
      return AudioSource.uri(Uri.file(audioUrl));
    }
  }

  @override
  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (e) {
      Logger.error('暂停播放失败', e, null, 'MediaKitPlayer');
      rethrow;
    }
  }

  @override
  Future<void> resume() async {
    try {
      await _player.play();
    } catch (e) {
      Logger.error('继续播放失败', e, null, 'MediaKitPlayer');
      rethrow;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _player.stop();
      _position = Duration.zero;
      _duration = null;
    } catch (e) {
      Logger.error('停止播放失败', e, null, 'MediaKitPlayer');
      rethrow;
    }
  }

  @override
  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
    } catch (e) {
      Logger.error('跳转失败', e, null, 'MediaKitPlayer');
      rethrow;
    }
  }

  @override
  Future<void> setVolume(double volume) async {
    try {
      _volume = volume.clamp(0.0, 1.0);
      await _player.setVolume(_volume);
    } catch (e) {
      Logger.error('设置音量失败', e, null, 'MediaKitPlayer');
      rethrow;
    }
  }

  @override
  Future<void> setSpeed(double speed) async {
    try {
      _speed = speed.clamp(0.25, 3.0);
      await _player.setSpeed(_speed);
    } catch (e) {
      Logger.error('设置播放速度失败', e, null, 'MediaKitPlayer');
      rethrow;
    }
  }

  @override
  Future<void> dispose() async {
    Logger.info('释放桌面端音频播放器资源', 'MediaKitPlayer');

    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();

    await _playingController.close();
    await _positionController.close();
    await _durationController.close();
    await _completionController.close();

    await _player.dispose();

    Logger.success('桌面端音频播放器资源释放完成', 'MediaKitPlayer');
  }
}
