import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/play_mode.dart';
import '../models/song.dart';
import '../utils/logger.dart';
import '../utils/platform_utils.dart';
import 'desktop_playback_backend.dart';
import 'mobile_playback_backend.dart';
import 'playback_backend.dart';
import 'playlist_manager_service.dart';
import 'smart_cache_service.dart';
import 'song_url_service.dart';

class PlaybackControllerService extends ChangeNotifier {
  late final PlaybackBackend _backend;
  final PlaylistManagerService _playlistManager;
  final SongUrlService _urlService;
  final SmartCacheService _cacheService = SmartCacheService();

  bool _isPlaying = false;
  bool _isLoading = false;
  bool _isQualityReloading = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  double _volume = 1.0;
  double _speed = 1.0;

  final ValueNotifier<Duration> positionNotifier = ValueNotifier<Duration>(Duration.zero);
  DateTime _lastPositionNotifyTime = DateTime.fromMillisecondsSinceEpoch(0);
  static const int _positionNotifyIntervalMs = 200;

  Song? _currentPlayingSong;
  bool _completionHandled = false;
  int _playRequestVersion = 0;
  final List<StreamSubscription<void>> _subscriptions = [];
  late final VoidCallback _playlistListener;

  PlaybackControllerService({
    required PlaylistManagerService playlistManager,
    required SongUrlService urlService,
  }) : _playlistManager = playlistManager,
       _urlService = urlService {
    _backend = PlatformUtils.isDesktop
        ? DesktopPlaybackBackend()
        : MobilePlaybackBackend();
    _initializeListeners();
    _setupPlaylistListener();
  }

  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  Duration get currentPosition => _currentPosition;
  Duration get totalDuration => _totalDuration;
  double get volume => _volume;
  double get speed => _speed;
  Song? get currentPlayingSong => _currentPlayingSong;

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

      if (_backend is DesktopPlaybackBackend) {
        _checkPlaybackCompletionByPosition(position);
      }

      final now = DateTime.now();
      if (now.difference(_lastPositionNotifyTime).inMilliseconds >= _positionNotifyIntervalMs) {
        _lastPositionNotifyTime = now;
        notifyListeners();
      }
    }));

    _subscriptions.add(_backend.durationStream.listen((duration) {
      _totalDuration = duration ?? Duration.zero;
      notifyListeners();
    }));

    _subscriptions.add(_backend.completionStream.listen((_) {
      if (_backend is DesktopPlaybackBackend) {
        _handlePlaybackCompleted();
      }
    }));

    _subscriptions.add(_backend.mediaItemStream.listen((item) {
      if (item != null) {
        final song = item.toSong();
        _currentPlayingSong = song;
        _totalDuration = item.duration ?? Duration.zero;
        _completionHandled = false;
        try {
          _playlistManager.jumpToSong(song);
        } catch (e) {
          Logger.debug('跳转到歌曲失败: ${song.title}', 'PlaybackController');
        }
      } else {
        _currentPlayingSong = null;
        _totalDuration = Duration.zero;
        _currentPosition = Duration.zero;
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

  Future<void> playSongs(List<Song> songs, {int startIndex = 0}) async {
    if (songs.isEmpty) return;

    Logger.info('播放歌曲列表: ${songs.length} 首，起始索引: $startIndex', 'PlaybackController');
    _playlistManager.setPlaylist(songs, startIndex: startIndex);

    if (_backend is MobilePlaybackBackend) {
      await _backend.playSongsFromList(songs, startIndex);
      return;
    }

    await _playCurrentSong();
  }

  Future<void> playSong(Song song, {List<Song>? playlist}) async {
    final songs = playlist ?? [song];
    int index = 0;

    if (playlist != null) {
      index = playlist.indexOf(song);
      if (index == -1) index = playlist.indexWhere((s) => s.id == song.id);
      if (index == -1) index = 0;
    }

    await playSongs(songs, startIndex: index);
  }

  Future<void> updatePlaylist(List<Song> songs) async {
    if (songs.isEmpty) return;
    final currentSong = _currentPlayingSong;
    if (currentSong == null) return;

    final currentIndex = songs.indexWhere((s) => s.id == currentSong.id);
    if (currentIndex == -1) return;

    _playlistManager.updatePlaylist(songs, currentIndex);
    notifyListeners();
  }

  Future<void> _playCurrentSong() async {
    final currentSong = _playlistManager.currentSong;
    if (currentSong == null) return;

    _playRequestVersion++;
    final currentVersion = _playRequestVersion;

    _completionHandled = false;
    _isLoading = true;
    notifyListeners();

    try {
      final audioUrl = await _urlService.getSongUrl(currentSong);

      if (currentVersion != _playRequestVersion) return;

      if (audioUrl == null || audioUrl.isEmpty) {
        throw Exception('获取播放链接失败: ${currentSong.title}');
      }

      final songWithUrl = _createSongWithUrl(currentSong, audioUrl);
      _currentPlayingSong = songWithUrl;

      await _backend.playSong(songWithUrl);

      if (_speed != 1.0) {
        try { await _backend.setSpeed(_speed); } catch (e) {
          Logger.debug('设置播放速度失败', 'PlaybackController');
        }
      }

      unawaited(_cacheService.cacheOnPlay(songWithUrl).catchError((Object e) {
        Logger.error('缓存歌曲失败: ${songWithUrl.title}', e, null, 'PlaybackController');
      }));

      await _backend.updateMediaItem(songWithUrl);

      Logger.success('播放成功: ${currentSong.title}', 'PlaybackController');
    } catch (e) {
      Logger.error('播放失败: ${currentSong.title}', e, null, 'PlaybackController');
      if (currentVersion == _playRequestVersion) {
        await _tryPlayNext();
      }
    } finally {
      if (currentVersion == _playRequestVersion) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> togglePlayPause() async {
    try {
      if (_isPlaying) {
        await _backend.pause();
      } else {
        if (_currentPlayingSong != null) {
          await _backend.resume();
        } else {
          await _playCurrentSong();
        }
      }
    } catch (e, stack) {
      Logger.error('播放/暂停切换失败', e, stack, 'PlaybackController');
    }
  }

  Future<void> pauseDirect() async {
    try {
      await _backend.pause();
    } catch (e, stack) {
      Logger.error('强制暂停失败', e, stack, 'PlaybackController');
    }
  }

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

  Future<void> playPrevious() async {
    if (_backend is MobilePlaybackBackend) {
      await _backend.skipToPrevious();
      return;
    }

    if (_playlistManager.moveToPrevious()) {
      await _playCurrentSong();
    }
  }

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

  Future<void> setVolume(double volume) async {
    try {
      _volume = volume.clamp(0.0, 1.0);
      await _backend.setVolume(_volume);
      notifyListeners();
    } catch (e, stack) {
      Logger.error('设置音量失败', e, stack, 'PlaybackController');
    }
  }

  Future<void> reloadWithNewQuality() async {
    final currentSong = _currentPlayingSong ?? _playlistManager.currentSong;
    if (currentSong == null) return;

    final wasPlaying = _isPlaying;
    final savedPosition = _currentPosition;

    _playRequestVersion++;
    final currentVersion = _playRequestVersion;

    _isQualityReloading = true;
    _isLoading = true;
    notifyListeners();

    try {
      if (_backend is DesktopPlaybackBackend) {
        try { await _backend.stop(); } catch (e) {
          Logger.debug('音质切换时停止播放失败', 'PlaybackController');
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }

      final audioUrl = await _urlService.getSongUrl(currentSong, forceRefresh: true);
      if (currentVersion != _playRequestVersion) return;
      if (audioUrl == null || audioUrl.isEmpty) return;

      final songWithUrl = _createSongWithUrl(currentSong, audioUrl);
      _currentPlayingSong = songWithUrl;

      await _backend.playSong(songWithUrl);

      if (savedPosition.inMilliseconds > 0) {
        try { await _backend.seek(savedPosition); } catch (e) {
          Logger.debug('音质切换后恢复进度失败', 'PlaybackController');
        }
      }

      if (!wasPlaying) {
        try { await _backend.pause(); } catch (e) {
          Logger.debug('音质切换后暂停失败', 'PlaybackController');
        }
      }

      _isPlaying = wasPlaying;
      await _backend.updateMediaItem(songWithUrl);

      Logger.success('音质切换成功', 'PlaybackController');
    } catch (e, stack) {
      Logger.error('音质切换重载失败', e, stack, 'PlaybackController');
    } finally {
      _isQualityReloading = false;
      if (currentVersion == _playRequestVersion) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

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
    if (_completionHandled) return;
    _completionHandled = true;

    if (_isLoading) return;

    switch (_playlistManager.playMode) {
      case PlayMode.single:
        await _backend.seek(Duration.zero);
        await _backend.resume();
        break;
      case PlayMode.sequence:
      case PlayMode.shuffle:
        await _tryPlayNext();
        break;
    }
  }

  Future<void> _tryPlayNext() async {
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

  void _checkPlaybackCompletionByPosition(Duration position) {
    if (_completionHandled || !_isPlaying || _isLoading) return;
    if (_totalDuration.inMilliseconds <= 0) return;

    final remainingMs = _totalDuration.inMilliseconds - position.inMilliseconds;
    if (remainingMs <= 100) {
      _handlePlaybackCompleted();
    }
  }

  Song _createSongWithUrl(Song song, String audioUrl) {
    return Song(
      id: song.id,
      title: song.title,
      artist: song.artist,
      album: song.album,
      coverUrl: song.coverUrl,
      audioUrl: audioUrl,
      duration: song.duration,
      platform: song.platform,
      r2CoverUrl: song.r2CoverUrl,
      lyricsLrc: song.lyricsLrc,
      lyricsTrans: song.lyricsTrans,
    );
  }

  @override
  void dispose() {
    _playlistManager.removeListener(_playlistListener);
    Future.wait(_subscriptions.map((s) => s.cancel())).ignore();
    _subscriptions.clear();
    positionNotifier.dispose();
    _backend.dispose();
    super.dispose();
  }
}
