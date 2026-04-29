import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';

import '../../models/song.dart';
import '../../utils/logger.dart';
import '../../utils/platform_utils.dart';
import 'desktop_playback_backend.dart';
import 'mobile_playback_backend.dart';
import 'playback_actions_service.dart';
import 'playback_backend.dart';
import 'playlist_manager_service.dart';
import 'song_url_service.dart';

/// 播放控制器服务，管理播放状态、流转发与会话恢复
class PlaybackControllerService extends ChangeNotifier {
  late final PlaybackBackend _backend;
  late final PlaybackActionsService _actions;
  final PlaylistManagerService _playlistManager;

  bool _isPlaying = false;
  bool _isLoading = false;
  bool _isQualityReloading = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  double _volume = 1.0;
  double _speed = 1.0;

  /// 播放位置 ValueNotifier，供 ValueListenableBuilder 使用
  final ValueNotifier<Duration> positionNotifier = ValueNotifier<Duration>(Duration.zero);

  final BehaviorSubject<Duration> _positionSubject = BehaviorSubject<Duration>.seeded(Duration.zero);
  final BehaviorSubject<Duration?> _durationSubject = BehaviorSubject<Duration?>.seeded(null);

  Song? _currentPlayingSong;
  bool _completionHandled = false;
  final List<StreamSubscription<void>> _subscriptions = [];
  late final VoidCallback _playlistListener;

  PlaybackControllerService({
    required PlaylistManagerService playlistManager,
    required SongUrlService urlService,
  }) : _playlistManager = playlistManager {
    _backend = PlatformUtils.isDesktop
        ? DesktopPlaybackBackend()
        : MobilePlaybackBackend();
    _actions = PlaybackActionsService(
      backend: _backend,
      playlistManager: playlistManager,
      urlService: urlService,
    );
    _initializeListeners();
    _setupPlaylistListener();
  }

  /// 当前是否正在播放
  bool get isPlaying => _isPlaying;

  /// 当前是否正在加载
  bool get isLoading => _isLoading;

  /// 当前播放位置
  Duration get currentPosition => _currentPosition;

  /// 当前歌曲总时长
  Duration get totalDuration => _totalDuration;

  /// 当前音量（0.0-1.0）
  double get volume => _volume;

  /// 当前播放速度
  double get speed => _speed;

  /// 当前播放的歌曲
  Song? get currentPlayingSong => _currentPlayingSong;

  /// 恢复上次会话的播放位置和时长
  void restoreSessionState(Duration position, Duration? songDuration) {
    _currentPosition = position;
    positionNotifier.value = position;
    _positionSubject.add(position);
    if (songDuration != null) {
      _totalDuration = songDuration;
      _durationSubject.add(songDuration);
    }
    notifyListeners();
  }

  /// 播放位置流，新订阅者自动获得最新值
  Stream<Duration> get positionStream => _positionSubject.stream;

  /// 总时长流，新订阅者自动获得最新值
  Stream<Duration?> get durationStream => _durationSubject.stream;

  void _initializeListeners() {
    _subscriptions.add(_backend.playingStream.listen((playing) {
      if (_isQualityReloading) return;
      if (_isPlaying != playing) {
        _isPlaying = playing;
        notifyListeners();
      }
    }));

    _subscriptions.add(_backend.positionStream.listen((position) {
      _currentPosition = position;
      positionNotifier.value = position;
      _positionSubject.add(position);
      if (_backend is DesktopPlaybackBackend) {
        _checkPlaybackCompletionByPosition(position);
      }
    }));

    _subscriptions.add(_backend.durationStream.listen((duration) {
      _totalDuration = duration ?? Duration.zero;
      _durationSubject.add(duration);
      notifyListeners();
    }));

    _subscriptions.add(_backend.completionStream.listen((_) {
      if (_isQualityReloading) return;
      if (_backend is DesktopPlaybackBackend) {
        _handlePlaybackCompleted();
      }
    }));

    _subscriptions.add(_backend.mediaItemStream.listen((item) {
      if (item != null) {
        final song = item.toSong();
        _currentPlayingSong = song;
        _totalDuration = item.duration ?? Duration.zero;
        _durationSubject.add(item.duration);
        _completionHandled = false;
        try {
          _playlistManager.jumpToSong(song);
        } catch (e) {
          Logger.warning('跳转歌曲失败: $e', 'PlaybackController');
        }
      } else if (_currentPlayingSong == null) {
        _totalDuration = Duration.zero;
        _currentPosition = Duration.zero;
        _positionSubject.add(Duration.zero);
        _durationSubject.add(null);
      }
      notifyListeners();
    }));
  }

  void _setupPlaylistListener() {
    _playlistListener = () {
      if (_playlistManager.isEmpty && _isPlaying) {
        _backend.stop();
        _isPlaying = false;
        _currentPlayingSong = null;
        notifyListeners();
      }
    };
    _playlistManager.addListener(_playlistListener);
  }

  /// 播放歌曲列表
  Future<void> playSongs(List<Song> songs, {int startIndex = 0}) async {
    _completionHandled = false;
    _isLoading = true;
    notifyListeners();

    await _actions.playSongs(songs, startIndex: startIndex);

    _isLoading = false;
    notifyListeners();
  }

  /// 播放单首歌曲
  Future<void> playSong(Song song, {List<Song>? playlist}) async {
    await _actions.playSong(song, playlist: playlist);
  }

  /// 更新播放列表
  Future<void> updatePlaylist(List<Song> songs) async {
    await _actions.updatePlaylist(songs);
    notifyListeners();
  }

  Future<void> _playCurrentSong() async {
    _completionHandled = false;
    _isLoading = true;
    notifyListeners();

    final result = await _actions.playCurrentSong();

    _isLoading = false;
    notifyListeners();

    if (result == PlayResult.shouldRetry) {
      await _actions.tryPlayNext();
    } else if (result == PlayResult.maxRetriesReached) {
      await stop();
    }
  }

  /// 切换播放/暂停状态
  Future<void> togglePlayPause() async {
    try {
      if (_isPlaying) {
        await _backend.pause();
      } else if (_currentPlayingSong != null) {
        await _backend.resume();
      } else {
        await _playCurrentSong();
      }
    } catch (e, stack) {
      Logger.error('播放/暂停切换失败', e, stack, 'PlaybackController');
    }
  }

  /// 强制暂停播放（不切换状态）
  Future<void> pauseDirect() async {
    try {
      await _backend.pause();
    } catch (e, stack) {
      Logger.error('强制暂停失败', e, stack, 'PlaybackController');
    }
  }

  /// 播放下一首
  Future<void> playNext() async {
    if (_backend is MobilePlaybackBackend) {
      await _backend.skipToNext();
      return;
    }
    if (_playlistManager.moveToNext()) {
      await _playCurrentSong();
    } else {
      await stop();
    }
  }

  /// 播放上一首
  Future<void> playPrevious() async {
    if (_backend is MobilePlaybackBackend) {
      await _backend.skipToPrevious();
      return;
    }
    if (_playlistManager.moveToPrevious()) {
      await _playCurrentSong();
    }
  }

  /// 跳转到指定歌曲
  Future<void> jumpToSong(Song song) async {
    if (_backend is MobilePlaybackBackend) {
      final index = _playlistManager.playlist.indexWhere((s) => s.id == song.id);
      if (index == -1) return;
      _playlistManager.jumpToIndex(index);
      await _backend.skipToQueueItem(index);
      return;
    }
    if (_playlistManager.jumpToSong(song)) {
      await _playCurrentSong();
    }
  }

  /// 跳转到指定索引
  Future<void> jumpToIndex(int index) async {
    if (_backend is MobilePlaybackBackend) {
      if (_playlistManager.jumpToIndex(index)) {
        await _backend.skipToQueueItem(index);
      }
      return;
    }
    if (_playlistManager.jumpToIndex(index)) {
      await _playCurrentSong();
    }
  }

  /// 停止播放并重置状态
  Future<void> stop() async {
    try {
      await _backend.stop();
      _currentPlayingSong = null;
      _currentPosition = Duration.zero;
      _totalDuration = Duration.zero;
      notifyListeners();
    } catch (e, stack) {
      Logger.error('停止播放失败', e, stack, 'PlaybackController');
    }
  }

  /// 跳转到指定播放位置
  Future<void> seekTo(Duration position) async {
    try {
      await _backend.seek(position);
      _currentPosition = position;
      positionNotifier.value = position;
      notifyListeners();
    } catch (e, stack) {
      Logger.error('跳转失败', e, stack, 'PlaybackController');
    }
  }

  /// 设置音量（0.0-1.0）
  Future<void> setVolume(double volume) async {
    try {
      _volume = volume.clamp(0.0, 1.0);
      await _backend.setVolume(_volume);
      notifyListeners();
    } catch (e, stack) {
      Logger.error('设置音量失败', e, stack, 'PlaybackController');
    }
  }

  /// 以新音质重新加载当前歌曲
  Future<void> reloadWithNewQuality() async {
    final currentSong = _currentPlayingSong ?? _playlistManager.currentSong;
    if (currentSong == null) return;

    final wasPlaying = _isPlaying;
    final savedPosition = _currentPosition;

    _isQualityReloading = true;
    _isLoading = true;
    notifyListeners();

    final result = await _actions.reloadWithNewQuality(
      currentSong: currentSong,
      savedPosition: savedPosition,
      wasPlaying: wasPlaying,
      isDesktop: _backend is DesktopPlaybackBackend,
    );

    _isPlaying = wasPlaying;
    _isQualityReloading = false;
    _isLoading = false;

    if (result == PlayResult.success) {
      _currentPlayingSong = _playlistManager.currentSong;
    }
    notifyListeners();
  }

  /// 设置播放速度（0.25-3.0）
  Future<void> setSpeed(double speed) async {
    try {
      _speed = speed.clamp(0.25, 3.0);
      await _backend.setSpeed(_speed);
      notifyListeners();
    } catch (e, stack) {
      Logger.error('设置播放速度失败', e, stack, 'PlaybackController');
    }
  }

  Future<void> _handlePlaybackCompleted() async {
    if (_completionHandled || _isLoading) return;
    _completionHandled = true;
    await _actions.handlePlaybackCompleted(_playlistManager.playMode);
  }

  void _checkPlaybackCompletionByPosition(Duration position) {
    if (_completionHandled || !_isPlaying || _isLoading) return;
    if (_totalDuration.inMilliseconds <= 0) return;

    final remainingMs = _totalDuration.inMilliseconds - position.inMilliseconds;
    if (remainingMs <= 100) {
      _handlePlaybackCompleted();
    }
  }

  @override
  void dispose() {
    _playlistManager.removeListener(_playlistListener);
    final subsToCancel = List<StreamSubscription<void>>.from(_subscriptions);
    _subscriptions.clear();
    for (final sub in subsToCancel) {
      sub.cancel().ignore();
    }
    positionNotifier.dispose();
    _positionSubject.close();
    _durationSubject.close();
    _backend.dispose();
    super.dispose();
  }
}
