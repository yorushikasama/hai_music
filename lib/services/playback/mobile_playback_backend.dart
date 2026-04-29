import 'dart:async';

import 'package:audio_service/audio_service.dart';

import '../../models/song.dart';
import '../../models/song_media_item_extension.dart';
import '../../utils/logger.dart';
import 'audio_handler_service.dart';
import 'audio_service_manager.dart';
import 'playback_backend.dart';

/// 移动端播放后端，基于 audio_service + just_audio 实现
class MobilePlaybackBackend implements PlaybackBackend {
  final List<StreamSubscription<void>> _subscriptions = [];

  final StreamController<bool> _playingController = StreamController<bool>.broadcast();
  final StreamController<Duration> _positionController = StreamController<Duration>.broadcast();
  final StreamController<Duration?> _durationController = StreamController<Duration?>.broadcast();
  final StreamController<void> _completionController = StreamController<void>.broadcast();
  final StreamController<PlaybackMediaItem?> _mediaItemController = StreamController<PlaybackMediaItem?>.broadcast();

  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;

  MobilePlaybackBackend() {
    _setupSubscriptions();
  }

  void _setupSubscriptions() {
    final handler = AudioServiceManager.instance.currentAudioHandler;
    if (handler == null) {
      Logger.warning('AudioHandler 为空，移动端后端无法初始化订阅', 'MobileBackend');
      return;
    }

    _subscriptions.add(handler.playbackState.listen((state) {
      _isPlaying = state.playing;
      _playingController.add(state.playing);
    }));

    _subscriptions.add(AudioService.position.listen((position) {
      _currentPosition = position;
      _positionController.add(position);
    }));

    _subscriptions.add(handler.mediaItem.listen((item) {
      if (item != null) {
        final mediaItem = PlaybackMediaItem(
          id: item.id,
          title: item.title,
          artist: item.artist ?? '',
          album: item.album ?? '',
          duration: item.duration,
          coverUrl: item.artUri?.toString() ?? '',
          audioUrl: (item.extras?['audioUrl'] ?? '').toString(),
          platform: _toNullableString(item.extras, 'platform'),
          r2CoverUrl: _toNullableString(item.extras, 'r2CoverUrl'),
          lyricsLrc: _toNullableString(item.extras, 'lyricsLrc'),
          lyricsTrans: _toNullableString(item.extras, 'lyricsTrans'),
          localCoverPath: _toNullableString(item.extras, 'localCoverPath'),
          localLyricsPath: _toNullableString(item.extras, 'localLyricsPath'),
          localTransPath: _toNullableString(item.extras, 'localTransPath'),
        );
        _mediaItemController.add(mediaItem);
        _durationController.add(item.duration);
      } else {
        _mediaItemController.add(null);
        _durationController.add(null);
      }
    }));

    _subscriptions.add(handler.queue.listen((_) {
      // 保持队列订阅活跃，确保 queue 流正常工作
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
  Stream<PlaybackMediaItem?> get mediaItemStream => _mediaItemController.stream;

  @override
  bool get isPlaying => _isPlaying;

  @override
  Duration get currentPosition => _currentPosition;

  MusicAudioHandler? _getHandler() {
    return AudioServiceManager.instance.currentAudioHandler;
  }

  /// 从 MediaItem.extras Map 中安全提取可空字符串值
  static String? _toNullableString(Map<String, Object?>? extras, String key) {
    final value = extras?[key];
    if (value == null) return null;
    final str = value.toString();
    return str.isNotEmpty ? str : null;
  }

  /// 播放指定歌曲
  @override
  Future<void> playSong(Song song) async {
    final handler = _getHandler();
    if (handler == null) return;
    await handler.updatePlaylist([song], initialIndex: 0);
    await handler.play();
  }

  @override
  Future<void> pause() async {
    final handler = _getHandler();
    if (handler == null) return;
    await handler.pause();
  }

  @override
  Future<void> resume() async {
    final handler = _getHandler();
    if (handler == null) return;
    await handler.play();
  }

  @override
  Future<void> seek(Duration position) async {
    final handler = _getHandler();
    if (handler == null) return;
    await handler.seek(position);
    _currentPosition = position;
    _positionController.add(position);
  }

  @override
  Future<void> stop() async {
    final handler = _getHandler();
    if (handler == null) return;
    await handler.stop();
    _isPlaying = false;
    _currentPosition = Duration.zero;
    _mediaItemController.add(null);
    _playingController.add(false);
    _positionController.add(Duration.zero);
    _durationController.add(null);
  }

  @override
  Future<void> setVolume(double volume) async {
    final handler = _getHandler();
    if (handler == null) return;
    await handler.setVolume(volume);
  }

  @override
  Future<void> setSpeed(double speed) async {
    final handler = _getHandler();
    if (handler == null) return;
    await handler.setSpeed(speed);
  }

  @override
  Future<void> playSongsFromList(List<Song> songs, int startIndex) async {
    final handler = _getHandler();
    if (handler == null) return;
    await handler.updatePlaylist(songs, initialIndex: startIndex);
    await handler.skipToQueueItem(startIndex);
  }

  @override
  Future<void> skipToNext() async {
    final handler = _getHandler();
    if (handler == null) return;
    await handler.skipToNext();
  }

  @override
  Future<void> skipToPrevious() async {
    final handler = _getHandler();
    if (handler == null) return;
    await handler.skipToPrevious();
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    final handler = _getHandler();
    if (handler == null) return;
    await handler.skipToQueueItem(index);
    await handler.play();
  }

  @override
  Future<void> updateMediaItem(Song song) async {
    try {
      final audioServiceManager = AudioServiceManager.instance;
      if (!audioServiceManager.isAvailable) return;

      final mediaItem = song.toMediaItem();
      audioServiceManager.updateMediaItem(mediaItem);
    } catch (e, stackTrace) {
      Logger.error('更新媒体通知失败', e, stackTrace, 'MobileBackend');
    }
  }

  @override
  void updatePlaylist(List<Song> songs, {int initialIndex = 0, Duration? initialPosition}) {
    final handler = _getHandler();
    if (handler == null) return;
    handler.updatePlaylist(songs, initialIndex: initialIndex, initialPosition: initialPosition);
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _playingController.close();
    _positionController.close();
    _durationController.close();
    _completionController.close();
    _mediaItemController.close();
  }
}
