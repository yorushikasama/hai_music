import 'dart:async';
import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';

import '../models/play_mode.dart';
import '../models/playback_speed.dart';
import '../models/song.dart';
import '../services/audio_service_manager.dart';
import '../services/play_history_service.dart';
import '../services/playback_controller_service.dart';
import '../services/playlist_manager_service.dart';
import '../services/preferences_service.dart';
import '../services/song_url_service.dart';
import '../utils/logger.dart';
import '../utils/platform_utils.dart';

class MusicProvider extends ChangeNotifier {
  late final PlaylistManagerService _playlistManager;
  late final PlaybackControllerService _playbackController;
  late final SongUrlService _urlService;
  final PlayHistoryService _historyService = PlayHistoryService();
  static final PreferencesService _prefs = PreferencesService();

  late final VoidCallback _playlistListener;
  late final VoidCallback _playbackListener;

  MusicProvider() {
    _initializeServices();
  }

  void _initializeServices() {
    Logger.info('初始化 MusicProvider', 'MusicProvider');

    _playlistManager = PlaylistManagerService();
    _urlService = SongUrlService();
    _playbackController = PlaybackControllerService(
      playlistManager: _playlistManager,
      urlService: _urlService,
    );

    try {
      final modeStr = _prefs.getPlayMode();
      PlayMode initialMode;
      switch (modeStr) {
        case 'single':
          initialMode = PlayMode.single;
          break;
        case 'shuffle':
          initialMode = PlayMode.shuffle;
          break;
        case 'sequence':
        default:
          initialMode = PlayMode.sequence;
          break;
      }
      setPlayMode(initialMode);
      Logger.info('恢复播放模式: $initialMode', 'MusicProvider');
    } catch (e) {
      Logger.warning('读取播放模式失败，使用默认模式', 'MusicProvider');
    }

    _playlistListener = notifyListeners;
    _playlistManager.addListener(_playlistListener);
    _restoreLastSession();
    _restorePlaybackSpeed();

    _playbackListener = () {
      final currentSong = _playbackController.currentPlayingSong;
      if (currentSong != null) {
        _historyService.addHistory(currentSong);
        _saveLastSession();
      }
      notifyListeners();
    };
    _playbackController.addListener(_playbackListener);
  }

  PlaybackControllerService get playbackController => _playbackController;

  // ========== 播放列表相关 ==========

  List<Song> get playlist => _playlistManager.playlist;

  int get currentIndex => _playlistManager.currentIndex;

  Song? get currentSong => _playlistManager.currentSong;

  PlayMode get playMode => _playlistManager.playMode;

  bool get hasPrevious => _playlistManager.hasPrevious;

  bool get hasNext => _playlistManager.hasNext;

  bool get isPlaylistEmpty => _playlistManager.isEmpty;

  // ========== 播放控制相关 ==========

  bool get isPlaying => _playbackController.isPlaying;

  bool get isLoading => _playbackController.isLoading;

  Duration get currentPosition => _playbackController.currentPosition;

  ValueNotifier<Duration> get positionNotifier => _playbackController.positionNotifier;

  Duration get totalDuration => _playbackController.totalDuration;

  double get volume => _playbackController.volume;

  double get speed => _playbackController.speed;

  PlaybackSpeed get playbackSpeed => PlaybackSpeed.fromValue(speed);

  Song? get currentPlayingSong => _playbackController.currentPlayingSong;

  // ========== 服务访问器 ==========

  PlayHistoryService get historyService => _historyService;

  // ========== 播放控制方法 ==========

  Future<void> playSongs(List<Song> songs, {int startIndex = 0}) async {
    await _playbackController.playSongs(songs, startIndex: startIndex);
  }

  Future<void> playSong(Song song, {List<Song>? playlist}) async {
    await _playbackController.playSong(song, playlist: playlist);
  }

  Future<void> updatePlaylist(List<Song> songs) async {
    await _playbackController.updatePlaylist(songs);
  }

  Future<void> togglePlayPause() async {
    await _playbackController.togglePlayPause();
  }

  Future<void> playNext() async {
    await _playbackController.playNext();
  }

  Future<void> playPrevious() async {
    await _playbackController.playPrevious();
  }

  Future<void> seekTo(Duration position) async {
    await _playbackController.seekTo(position);
  }

  Future<void> seek(Duration position) async {
    await seekTo(position);
  }

  Future<void> pause() async {
    if (isPlaying) {
      await togglePlayPause();
    }
  }

  Future<void> forcePause() async {
    await _playbackController.pauseDirect();
  }

  Future<void> stop() async {
    await _playbackController.stop();
  }

  Future<void> jumpToSong(Song song) async {
    await _playbackController.jumpToSong(song);
  }

  Future<void> jumpToIndex(int index) async {
    await _playbackController.jumpToIndex(index);
  }

  // ========== 播放列表管理 ==========

  Future<void> addToPlaylist(Song song) async {
    _playlistManager.addSong(song);

    unawaited(_urlService.getSongUrl(song).catchError((e) {
      Logger.warning('预加载播放链接失败: ${song.title}', 'MusicProvider');
      return null;
    }));
  }

  Future<void> removeFromPlaylist(int index) async {
    _playlistManager.removeSongAt(index);
  }

  Future<void> clearPlaylist() async {
    _playlistManager.clearPlaylist();
    await _playbackController.stop();
  }

  void moveSong(int oldIndex, int newIndex) {
    _playlistManager.moveSong(oldIndex, newIndex);
  }

  // ========== 播放模式控制 ==========

  Future<void> setPlayMode(PlayMode mode) async {
    _playlistManager.setPlayMode(mode);
    Logger.info('设置播放模式: $mode', 'MusicProvider');

    await _prefs.setPlayMode(mode.name);

    if (!PlatformUtils.isDesktop) {
      final handler = AudioServiceManager.instance.currentAudioHandler;
      if (handler != null) {
        switch (mode) {
          case PlayMode.sequence:
            await handler.setRepeatMode(AudioServiceRepeatMode.none);
            await handler.setShuffleMode(AudioServiceShuffleMode.none);
            break;
          case PlayMode.single:
            await handler.setRepeatMode(AudioServiceRepeatMode.one);
            await handler.setShuffleMode(AudioServiceShuffleMode.none);
            break;
          case PlayMode.shuffle:
            await handler.setRepeatMode(AudioServiceRepeatMode.all);
            await handler.setShuffleMode(AudioServiceShuffleMode.all);
            break;
        }
      }
    }
  }

  Future<void> togglePlayMode() async {
    final newMode = _playlistManager.playMode.next;
    await setPlayMode(newMode);
  }

  // ========== 音频设置 ==========

  Future<void> setVolume(double volume) async {
    await _playbackController.setVolume(volume);
  }

  Future<void> setSpeed(double speed) async {
    await _playbackController.setSpeed(speed);
    await _prefs.setPlaybackSpeed(speed);
  }

  Future<void> setPlaybackSpeed(PlaybackSpeed speed) async {
    await setSpeed(speed.value);
  }

  void _restorePlaybackSpeed() {
    try {
      final savedSpeed = _prefs.getPlaybackSpeed();
      if (savedSpeed != 1.0) {
        _playbackController.setSpeed(savedSpeed);
        Logger.info('恢复播放速度: ${savedSpeed}x', 'MusicProvider');
      }
    } catch (e) {
      Logger.warning('恢复播放速度失败', 'MusicProvider');
    }
  }

  // ========== 会话管理 ==========

  void _saveLastSession() {
    try {
      if (_playlistManager.isEmpty) {
        _prefs.clearLastSession();
        return;
      }

      final current = _playbackController.currentPlayingSong ?? _playlistManager.currentSong;
      int currentIndex = 0;
      if (current != null) {
        final idx = _playlistManager.playlist.indexWhere((s) => s.id == current.id);
        if (idx >= 0) {
          currentIndex = idx;
        }
      }

      final session = {
        'playlist': _playlistManager.playlist.map((s) => s.toJson()).toList(),
        'currentIndex': currentIndex,
        'position': _playbackController.currentPosition.inSeconds,
      };

      final jsonStr = jsonEncode(session);
      _prefs.setLastSession(jsonStr);
    } catch (e) {
      Logger.error('保存上次播放会话失败', e, null, 'MusicProvider');
    }
  }

  void _restoreLastSession() {
    try {
      final sessionStr = _prefs.getLastSession();
      if (sessionStr.isEmpty) {
        return;
      }

      final decoded = jsonDecode(sessionStr);
      if (decoded is! Map<String, dynamic>) {
        Logger.warning('会话 JSON 不是 Map<String, dynamic>', 'MusicProvider');
        return;
      }

      final playlistData = decoded['playlist'];
      if (playlistData is! List) {
        Logger.warning('会话中 playlist 字段不是 List', 'MusicProvider');
        return;
      }

      final songs = playlistData
          .whereType<Map<String, dynamic>>()
          .map(Song.fromJson)
          .toList();
      if (songs.isEmpty) {
        Logger.warning('会话中 playlist 解析后为空', 'MusicProvider');
        return;
      }

      final indexValue = decoded['currentIndex'];
      int startIndex = 0;
      if (indexValue is int) {
        startIndex = indexValue;
      }
      if (startIndex < 0 || startIndex >= songs.length) {
        startIndex = 0;
      }

      int positionSeconds = 0;
      final positionValue = decoded['position'];
      if (positionValue is int && positionValue > 0) {
        positionSeconds = positionValue;
      }

      _playlistManager.setPlaylist(songs, startIndex: startIndex);

      if (!PlatformUtils.isDesktop) {
        final handler = AudioServiceManager.instance.currentAudioHandler;
        if (handler != null) {
          final initialPosition = Duration(seconds: positionSeconds);
          handler.updatePlaylist(
            songs,
            initialIndex: startIndex,
            initialPosition: initialPosition,
          );
        }
      } else {
        _playbackController.updatePlaylist(songs);
      }

      Logger.info('恢复上次播放会话: ${songs.length} 首歌曲，索引: $startIndex, 位置: ${positionSeconds}s', 'MusicProvider');
    } catch (e) {
      Logger.error('恢复上次播放会话失败', e, null, 'MusicProvider');
    }
  }

  // ========== 资源清理 ==========

  @override
  void dispose() {
    Logger.info('释放 MusicProvider 资源', 'MusicProvider');

    _playlistManager.removeListener(_playlistListener);
    _playbackController.removeListener(_playbackListener);

    _playbackController.dispose();
    _playlistManager.dispose();
    _urlService.dispose();

    if (!PlatformUtils.isDesktop) {
      AudioServiceManager.instance.dispose().ignore();
    }

    super.dispose();
  }
}
