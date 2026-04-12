import 'dart:async';

import 'package:audio_service/audio_service.dart';

import '../models/song.dart';
import '../utils/logger.dart';
import 'audio_handler_service.dart';
import 'audio_service_manager.dart';
import 'playback_backend.dart';

class MobilePlaybackBackend implements PlaybackBackend {
  final List<StreamSubscription<void>> _subscriptions = [];

  final StreamController<bool> _playingController = StreamController<bool>.broadcast();
  final StreamController<Duration> _positionController = StreamController<Duration>.broadcast();
  final StreamController<Duration?> _durationController = StreamController<Duration?>.broadcast();
  final StreamController<void> _completionController = StreamController<void>.broadcast();
  final StreamController<PlaybackMediaItem?> _mediaItemController = StreamController<PlaybackMediaItem?>.broadcast();

  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  bool _subscriptionsSetup = false;

  MobilePlaybackBackend() {
    _trySetupSubscriptions();
  }

  void _trySetupSubscriptions() {
    if (_subscriptionsSetup) return;
    final handler = AudioServiceManager.instance.currentAudioHandler;
    if (handler == null) {
      Logger.warning('AudioHandler 为空，移动端后端订阅延迟初始化', 'MobileBackend');
      return;
    }
    _subscriptionsSetup = true;

    _subscriptions.add(handler.playbackState.listen((state) {
      _isPlaying = state.playing;
      _playingController.add(state.playing);
      _currentPosition = state.position;
      _positionController.add(state.position);
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
          platform: item.extras?['platform']?.toString(),
          r2CoverUrl: item.extras?['r2CoverUrl']?.toString(),
          lyricsLrc: item.extras?['lyricsLrc']?.toString(),
          lyricsTrans: item.extras?['lyricsTrans']?.toString(),
        );
        _mediaItemController.add(mediaItem);
        _durationController.add(item.duration);
      } else {
        _mediaItemController.add(null);
        _durationController.add(null);
      }
    }));

    _subscriptions.add(handler.queue.listen((_) {}));
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
    _trySetupSubscriptions();
    return AudioServiceManager.instance.currentAudioHandler;
  }

  MediaItem _songToMediaItem(Song song) {
    return MediaItem(
      id: song.id,
      album: song.album,
      title: song.title,
      artist: song.artist,
      duration: song.duration != null ? Duration(seconds: song.duration!) : null,
      artUri: song.coverUrl.isNotEmpty ? Uri.tryParse(song.coverUrl) : null,
      extras: {
        'audioUrl': song.audioUrl,
        'platform': song.platform ?? 'unknown',
        'r2CoverUrl': song.r2CoverUrl ?? '',
        'lyricsLrc': song.lyricsLrc ?? '',
        'lyricsTrans': song.lyricsTrans ?? '',
      },
    );
  }

  @override
  Future<void> playSong(Song song) async {
    final handler = _getHandler();
    if (handler == null) return;
    final audioServiceManager = AudioServiceManager.instance;
    if (audioServiceManager.isAvailable) {
      final mediaItem = _songToMediaItem(song);
      audioServiceManager.updateMediaItem(mediaItem);
    }
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

      final mediaItem = _songToMediaItem(song);
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
