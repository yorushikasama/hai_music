import 'dart:async';
import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';

import '../models/play_mode.dart';
import '../models/playback_speed.dart';
import '../models/song.dart';
import '../services/playback/audio_service_manager.dart';
import '../services/ui/play_history_service.dart';
import '../services/playback/playback_controller_service.dart';
import '../services/playback/playlist_manager_service.dart';
import '../services/core/preferences_service.dart';
import '../services/playback/song_url_service.dart';
import '../utils/logger.dart';
import '../utils/platform_utils.dart';

/// 音乐播放核心 Provider，统一管理播放列表、播放控制和会话持久化
class MusicProvider extends ChangeNotifier {
  late final PlaylistManagerService _playlistManager;
  late final PlaybackControllerService _playbackController;
  late final SongUrlService _urlService;
  final PlayHistoryService _historyService = PlayHistoryService();
  static final PreferencesService _prefs = PreferencesService();

  late final VoidCallback _playlistListener;
  late final VoidCallback _playbackListener;

  // 防抖：避免频繁保存会话到 SharedPreferences
  Timer? _saveSessionTimer;
  Song? _lastSavedSong;

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

    // 异步加载播放模式和会话
    _loadAsyncSettings();

    _playlistListener = notifyListeners;
    _playlistManager.addListener(_playlistListener);

    _playbackListener = () {
      final currentSong = _playbackController.currentPlayingSong;
      if (currentSong != null) {
        _historyService.addHistory(currentSong);
        _debouncedSaveSession(currentSong);
      }
      notifyListeners();
    };
    _playbackController.addListener(_playbackListener);
  }

  Future<void> _loadAsyncSettings() async {
    try {
      final modeStr = await _prefs.getPlayMode();
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

    await _restoreLastSession();
    await _restorePlaybackSpeed();
  }

  /// 播放控制器服务实例
  PlaybackControllerService get playbackController => _playbackController;

  // ========== 播放列表相关 ==========

  /// 当前播放列表
  List<Song> get playlist => _playlistManager.playlist;

  /// 当前播放索引
  int get currentIndex => _playlistManager.currentIndex;

  /// 当前歌曲（基于播放列表索引）
  Song? get currentSong => _playlistManager.currentSong;

  /// 当前播放模式
  PlayMode get playMode => _playlistManager.playMode;

  /// 是否有上一首
  bool get hasPrevious => _playlistManager.hasPrevious;

  /// 是否有下一首
  bool get hasNext => _playlistManager.hasNext;

  /// 播放列表是否为空
  bool get isPlaylistEmpty => _playlistManager.isEmpty;

  // ========== 播放控制相关 ==========

  /// 是否正在播放
  bool get isPlaying => _playbackController.isPlaying;

  /// 是否正在加载
  bool get isLoading => _playbackController.isLoading;

  /// 当前播放位置
  Duration get currentPosition => _playbackController.currentPosition;

  /// 播放位置流 - 供 StreamBuilder 直接监听（与 just_audio 官方模式一致）
  Stream<Duration> get positionStream => _playbackController.positionStream;

  /// 总时长流 - 供 StreamBuilder 直接监听（与 just_audio 官方模式一致）
  Stream<Duration?> get durationStream => _playbackController.durationStream;

  /// 歌曲总时长
  Duration get totalDuration => _playbackController.totalDuration;

  /// 当前音量（0.0 ~ 1.0）
  double get volume => _playbackController.volume;

  /// 当前播放速度
  double get speed => _playbackController.speed;

  /// 当前播放速度枚举
  PlaybackSpeed get playbackSpeed => PlaybackSpeed.fromValue(speed);

  /// 当前正在播放的歌曲（来自播放控制器）
  Song? get currentPlayingSong => _playbackController.currentPlayingSong;

  // ========== 服务访问器 ==========

  /// 播放历史服务实例
  PlayHistoryService get historyService => _historyService;

  // ========== 播放控制方法 ==========

  /// 播放歌曲列表，可指定起始索引
  Future<void> playSongs(List<Song> songs, {int startIndex = 0}) async {
    await _playbackController.playSongs(songs, startIndex: startIndex);
  }

  /// 播放单首歌曲，可附带播放列表
  Future<void> playSong(Song song, {List<Song>? playlist}) async {
    await _playbackController.playSong(song, playlist: playlist);
  }

  /// 更新播放列表（不改变当前播放状态）
  Future<void> updatePlaylist(List<Song> songs) async {
    await _playbackController.updatePlaylist(songs);
  }

  /// 切换播放/暂停
  Future<void> togglePlayPause() async {
    await _playbackController.togglePlayPause();
  }

  /// 播放下一首
  Future<void> playNext() async {
    await _playbackController.playNext();
  }

  /// 播放上一首
  Future<void> playPrevious() async {
    await _playbackController.playPrevious();
  }

  /// 跳转到指定位置
  Future<void> seekTo(Duration position) async {
    await _playbackController.seekTo(position);
  }

  /// 跳转到指定位置（seekTo 的简写）
  Future<void> seek(Duration position) async {
    await seekTo(position);
  }

  /// 暂停播放（仅在播放中生效）
  Future<void> pause() async {
    if (isPlaying) {
      await togglePlayPause();
    }
  }

  /// 强制暂停播放（不检查当前状态）
  Future<void> forcePause() async {
    await _playbackController.pauseDirect();
  }

  /// 停止播放并重置状态
  Future<void> stop() async {
    await _playbackController.stop();
  }

  /// 跳转到指定歌曲
  Future<void> jumpToSong(Song song) async {
    await _playbackController.jumpToSong(song);
  }

  /// 跳转到指定索引
  Future<void> jumpToIndex(int index) async {
    await _playbackController.jumpToIndex(index);
  }

  // ========== 播放列表管理 ==========

  /// 添加歌曲到播放列表并预加载播放链接
  Future<void> addToPlaylist(Song song) async {
    _playlistManager.addSong(song);

    unawaited(_urlService.getSongUrl(song).catchError((e) {
      Logger.warning('预加载播放链接失败: ${song.title}', 'MusicProvider');
      return null;
    }));
  }

  /// 从播放列表移除指定索引的歌曲
  Future<void> removeFromPlaylist(int index) async {
    _playlistManager.removeSongAt(index);
  }

  /// 清空播放列表并停止播放
  Future<void> clearPlaylist() async {
    _playlistManager.clearPlaylist();
    await _playbackController.stop();
  }

  /// 移动播放列表中的歌曲位置
  void moveSong(int oldIndex, int newIndex) {
    _playlistManager.moveSong(oldIndex, newIndex);
  }

  // ========== 播放模式控制 ==========

  /// 设置播放模式并同步到系统媒体控制
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

  /// 循环切换播放模式（顺序 → 单曲 → 随机 → 顺序）
  Future<void> togglePlayMode() async {
    final newMode = _playlistManager.playMode.next;
    await setPlayMode(newMode);
  }

  // ========== 音频设置 ==========

  /// 设置音量
  Future<void> setVolume(double volume) async {
    await _playbackController.setVolume(volume);
  }

  /// 设置播放速度并持久化
  Future<void> setSpeed(double speed) async {
    await _playbackController.setSpeed(speed);
    await _prefs.setPlaybackSpeed(speed);
  }

  /// 通过 PlaybackSpeed 枚举设置播放速度
  Future<void> setPlaybackSpeed(PlaybackSpeed speed) async {
    await setSpeed(speed.value);
  }

  Future<void> _restorePlaybackSpeed() async {
    try {
      final savedSpeed = await _prefs.getPlaybackSpeed();
      if (savedSpeed != 1.0) {
        _playbackController.setSpeed(savedSpeed);
        Logger.info('恢复播放速度: ${savedSpeed}x', 'MusicProvider');
      }
    } catch (e) {
      Logger.warning('恢复播放速度失败', 'MusicProvider');
    }
  }

  // ========== 会话管理 ==========

  /// 防抖保存会话：歌曲切换时立即保存，播放位置变化时延迟 3 秒保存
  void _debouncedSaveSession(Song currentSong) {
    final songChanged = _lastSavedSong?.id != currentSong.id;
    _saveSessionTimer?.cancel();

    if (songChanged) {
      // 歌曲切换时立即保存
      _lastSavedSong = currentSong;
      unawaited(_saveLastSession());
    } else {
      // 播放位置变化时延迟保存，避免频繁写入
      _saveSessionTimer = Timer(const Duration(seconds: 3), () {
        unawaited(_saveLastSession());
      });
    }
  }

  Future<void> _saveLastSession() async {
    try {
      if (_playlistManager.isEmpty) {
        await _prefs.clearLastSession();
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
      await _prefs.setLastSession(jsonStr);
    } catch (e) {
      Logger.error('保存上次播放会话失败', e, null, 'MusicProvider');
    }
  }

  Future<void> _restoreLastSession() async {
    await _restoreLastSessionInternal();
  }

  Future<void> _restoreLastSessionInternal() async {
    try {
      final sessionStr = await _prefs.getLastSession();
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

      final currentSong = _playlistManager.currentSong;
      if (currentSong != null) {
        final songDuration = currentSong.duration != null
            ? Duration(seconds: currentSong.duration!)
            : null;
        _playbackController.restoreSessionState(
          Duration(seconds: positionSeconds),
          songDuration,
        );
      }

      Logger.info(
        '恢复上次播放会话: ${songs.length} 首歌曲， '
        '索引: $startIndex, 位置: ${positionSeconds}s',
        'MusicProvider',
      );
    } catch (e) {
      Logger.error('恢复上次播放会话失败', e, null, 'MusicProvider');
    }
  }

  // ========== 资源清理 ==========

  @override
  void dispose() {
    Logger.info('释放 MusicProvider 资源', 'MusicProvider');

    _saveSessionTimer?.cancel();
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
