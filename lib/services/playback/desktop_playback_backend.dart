import 'dart:async';

import '../../models/song.dart';
import '../../utils/logger.dart';
import 'audio_player_factory.dart';
import 'audio_player_interface.dart';
import 'playback_backend.dart';

/// 桌面端播放后端，基于 media_kit 实现
class DesktopPlaybackBackend implements PlaybackBackend {
  AudioPlayerInterface? _audioPlayer;
  final List<StreamSubscription<void>> _subscriptions = [];

  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;

  final StreamController<bool> _playingController = StreamController<bool>.broadcast();
  final StreamController<Duration> _positionController = StreamController<Duration>.broadcast();
  final StreamController<Duration?> _durationController = StreamController<Duration?>.broadcast();
  final StreamController<void> _completionController = StreamController<void>.broadcast();
  final StreamController<PlaybackMediaItem?> _mediaItemController = StreamController<PlaybackMediaItem?>.broadcast();

  DesktopPlaybackBackend() {
    _initialize();
  }

  void _initialize() {
    _audioPlayer = AudioPlayerFactory.createPlayer();

    _subscriptions.add(_audioPlayer!.playingStream.listen((playing) {
      _isPlaying = playing;
      _playingController.add(playing);
    }));

    _subscriptions.add(_audioPlayer!.positionStream.listen((position) {
      _currentPosition = position;
      _positionController.add(position);
    }));

    _subscriptions.add(_audioPlayer!.durationStream.listen(_durationController.add));

    _subscriptions.add(_audioPlayer!.completionStream.listen((_) {
      _completionController.add(null);
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

  @override
  Future<void> playSong(Song song) async {
    try {
      if (song.audioUrl.isEmpty) {
        Logger.warning('播放链接为空，跳过: ${song.title}', 'DesktopBackend');
        return;
      }
      Logger.info('播放歌曲: ${song.title}', 'DesktopBackend');
      _mediaItemController.add(PlaybackMediaItem(
        id: song.id,
        title: song.title,
        artist: song.artist,
        album: song.album,
        duration: song.duration != null ? Duration(seconds: song.duration!) : null,
        coverUrl: song.coverUrl,
        audioUrl: song.audioUrl,
        platform: song.platform,
        r2CoverUrl: song.r2CoverUrl,
        lyricsLrc: song.lyricsLrc,
        lyricsTrans: song.lyricsTrans,
        localCoverPath: song.localCoverPath,
        localLyricsPath: song.localLyricsPath,
        localTransPath: song.localTransPath,
      ));
      await _audioPlayer?.play(song);
      Logger.success('播放成功: ${song.title}', 'DesktopBackend');
    } catch (e, stackTrace) {
      Logger.error('播放歌曲失败: ${song.title}', e, stackTrace, 'DesktopBackend');
      rethrow;
    }
  }

  @override
  Future<void> pause() async {
    try {
      await _audioPlayer?.pause();
    } catch (e) {
      Logger.error('暂停失败', e, null, 'DesktopBackend');
    }
  }

  @override
  Future<void> resume() async {
    try {
      await _audioPlayer?.resume();
    } catch (e) {
      Logger.error('恢复播放失败', e, null, 'DesktopBackend');
    }
  }

  @override
  Future<void> seek(Duration position) async {
    try {
      _currentPosition = position;
      _positionController.add(position);
      await _audioPlayer?.seek(position);
    } catch (e) {
      Logger.error('跳转失败', e, null, 'DesktopBackend');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _audioPlayer?.stop();
    } catch (e) {
      Logger.error('停止播放失败', e, null, 'DesktopBackend');
    }
    _isPlaying = false;
    _currentPosition = Duration.zero;
    _playingController.add(false);
    _positionController.add(Duration.zero);
    _durationController.add(null);
    _mediaItemController.add(null);
  }

  @override
  Future<void> setVolume(double volume) async {
    try {
      await _audioPlayer?.setVolume(volume);
    } catch (e) {
      Logger.error('设置音量失败', e, null, 'DesktopBackend');
    }
  }

  @override
  Future<void> setSpeed(double speed) async {
    try {
      await _audioPlayer?.setSpeed(speed);
    } catch (e) {
      Logger.error('设置播放速度失败', e, null, 'DesktopBackend');
    }
  }

  @override
  Future<void> playSongsFromList(List<Song> songs, int startIndex) async {
    // no-op: desktop backend handles these via PlaybackControllerService
  }

  @override
  Future<void> skipToNext() async {
    // no-op: desktop backend handles these via PlaybackControllerService
  }

  @override
  Future<void> skipToPrevious() async {
    // no-op: desktop backend handles these via PlaybackControllerService
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    // no-op: desktop backend handles these via PlaybackControllerService
  }

  @override
  Future<void> updateMediaItem(Song song) async {
    // no-op: desktop backend handles these via PlaybackControllerService
  }

  @override
  void updatePlaylist(List<Song> songs, {int initialIndex = 0, Duration? initialPosition}) {
    // no-op: desktop backend handles these via PlaybackControllerService
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _audioPlayer?.dispose();
    _playingController.close();
    _positionController.close();
    _durationController.close();
    _completionController.close();
    _mediaItemController.close();
  }
}
