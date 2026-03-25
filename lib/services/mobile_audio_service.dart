import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';
import '../models/song.dart';
import '../utils/logger.dart';
import 'audio_service_manager.dart';
import 'playlist_manager_service.dart';
import 'song_url_service.dart';
import 'smart_cache_service.dart';
import 'platform_audio_service.dart';

/// 移动端音频服务实现
/// 使用AudioService实现后台播放和系统通知
class MobileAudioService extends ChangeNotifier implements PlatformAudioService {
  final PlaylistManagerService _playlistManager;
  final SongUrlService _urlService;
  final SmartCacheService _cacheService = SmartCacheService();
  
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  double _volume = 1.0;
  double _speed = 1.0;
  Song? _currentPlayingSong;
  
  final List<StreamSubscription> _subscriptions = [];
  final StreamController<bool> _playingController = StreamController<bool>.broadcast();
  final StreamController<Duration> _positionController = StreamController<Duration>.broadcast();
  final StreamController<void> _completionController = StreamController<void>.broadcast();

  MobileAudioService({
    required PlaylistManagerService playlistManager,
    required SongUrlService urlService,
  }) : _playlistManager = playlistManager,
       _urlService = urlService {
    _initialize();
  }

  void _initialize() {
    Logger.info('初始化移动端音频服务', 'MobileAudioService');
    
    final handler = AudioServiceManager.instance.audioHandler;
    if (handler == null) {
      Logger.warning('AudioHandler为空，无法初始化移动端音频服务', 'MobileAudioService');
      return;
    }

    // 监听播放状态
    _subscriptions.add(handler.playbackState.listen((state) {
      _isPlaying = state.playing;
      if (state.playing) {
        _currentPosition = state.position;
      }
      _playingController.add(_isPlaying);
      notifyListeners();
    }));

    // 监听媒体项变化
    _subscriptions.add(handler.mediaItem.listen((item) {
      if (item != null) {
        final song = Song(
          id: item.id,
          title: item.title,
          artist: item.artist ?? '',
          album: item.album ?? '',
          duration: item.duration?.inSeconds,
          coverUrl: item.artUri?.toString() ?? '',
          audioUrl: item.extras?['audioUrl'] ?? '',
          platform: item.extras?['platform'],
          r2CoverUrl: item.extras?['r2CoverUrl'],
          lyricsLrc: item.extras?['lyricsLrc'],
        );

        _currentPlayingSong = song;
        _totalDuration = item.duration ?? Duration.zero;

        try {
          _playlistManager.jumpToSong(song);
        } catch (_) {
          // 如果当前播放列表里找不到对应歌曲，则忽略索引同步
        }
      } else {
        _currentPlayingSong = null;
        _totalDuration = Duration.zero;
        _currentPosition = Duration.zero;
      }
      notifyListeners();
    }));

    Logger.success('移动端音频服务初始化完成', 'MobileAudioService');
  }

  @override
  bool get isPlaying => _isPlaying;

  @override
  bool get isLoading => _isLoading;

  @override
  Duration get currentPosition => _currentPosition;

  @override
  Duration get totalDuration => _totalDuration;

  @override
  double get volume => _volume;

  @override
  double get speed => _speed;

  @override
  Song? get currentPlayingSong => _currentPlayingSong;

  @override
  Stream<bool> get playingStream => _playingController.stream;

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<void> get completionStream => _completionController.stream;

  @override
  Future<void> playSongs(List<Song> songs, {int startIndex = 0}) async {
    if (songs.isEmpty) {
      Logger.warning('歌曲列表为空', 'MobileAudioService');
      return;
    }

    Logger.info('播放歌曲列表: ${songs.length} 首，起始索引: $startIndex', 'MobileAudioService');
    
    final handler = AudioServiceManager.instance.audioHandler;
    if (handler == null) {
      Logger.warning('AudioHandler为空，无法播放', 'MobileAudioService');
      return;
    }

    try {
      _playlistManager.setPlaylist(songs, startIndex: startIndex);
      await handler.updatePlaylist(songs, initialIndex: startIndex);
      await handler.skipToQueueItem(startIndex);
      await handler.play();

      Logger.success('已通过AudioHandler播放列表（移动端）', 'MobileAudioService');
    } catch (e, stack) {
      Logger.error('通过AudioHandler播放列表失败', e, stack, 'MobileAudioService');
    }
  }

  @override
  Future<void> playSong(Song song, {List<Song>? playlist}) async {
    final songs = playlist ?? [song];
    int index = 0;
    
    if (playlist != null) {
      index = playlist.indexOf(song);
      if (index == -1) {
        index = playlist.indexWhere((s) => s.id == song.id);
      }
      if (index == -1) {
        index = 0;
      }
    }

    await playSongs(songs, startIndex: index);
  }

  @override
  Future<void> togglePlayPause() async {
    try {
      final handler = AudioServiceManager.instance.audioHandler;
      if (handler == null) {
        Logger.warning('AudioHandler为空，无法切换播放状态', 'MobileAudioService');
        return;
      }

      if (handler.isPlaying) {
        await handler.pause();
      } else {
        await handler.play();
      }
    } catch (e, stack) {
      Logger.error('播放/暂停切换失败', e, stack, 'MobileAudioService');
    }
  }

  @override
  Future<void> pause() async {
    try {
      final handler = AudioServiceManager.instance.audioHandler;
      if (handler != null) {
        await handler.pause();
      }
    } catch (e, stack) {
      Logger.error('暂停播放失败', e, stack, 'MobileAudioService');
    }
  }

  @override
  Future<void> resume() async {
    try {
      final handler = AudioServiceManager.instance.audioHandler;
      if (handler != null) {
        await handler.play();
      }
    } catch (e, stack) {
      Logger.error('继续播放失败', e, stack, 'MobileAudioService');
    }
  }

  @override
  Future<void> stop() async {
    try {
      final handler = AudioServiceManager.instance.audioHandler;
      if (handler != null) {
        await handler.stop();
      }
    } catch (e, stack) {
      Logger.error('停止播放失败', e, stack, 'MobileAudioService');
    }
  }

  @override
  Future<void> playNext() async {
    try {
      final handler = AudioServiceManager.instance.audioHandler;
      if (handler == null) {
        Logger.warning('AudioHandler为空，无法播放下一首', 'MobileAudioService');
        return;
      }

      await handler.skipToNext();
    } catch (e, stack) {
      Logger.error('播放下一首失败', e, stack, 'MobileAudioService');
    }
  }

  @override
  Future<void> playPrevious() async {
    try {
      final handler = AudioServiceManager.instance.audioHandler;
      if (handler == null) {
        Logger.warning('AudioHandler为空，无法播放上一首', 'MobileAudioService');
        return;
      }

      await handler.skipToPrevious();
    } catch (e, stack) {
      Logger.error('播放上一首失败', e, stack, 'MobileAudioService');
    }
  }

  @override
  Future<void> jumpToSong(Song song) async {
    final handler = AudioServiceManager.instance.audioHandler;
    if (handler == null) {
      Logger.warning('AudioHandler为空，无法跳转到指定歌曲', 'MobileAudioService');
      return;
    }

    final currentList = _playlistManager.playlist;
    final index = currentList.indexWhere((s) => s.id == song.id);
    if (index == -1) {
      Logger.warning('在当前播放列表中找不到歌曲: ${song.title}', 'MobileAudioService');
      return;
    }

    _playlistManager.jumpToIndex(index);
    await handler.skipToQueueItem(index);
    await handler.play();
  }

  @override
  Future<void> jumpToIndex(int index) async {
    final handler = AudioServiceManager.instance.audioHandler;
    if (handler == null) {
      Logger.warning('AudioHandler为空，无法跳转到指定索引', 'MobileAudioService');
      return;
    }

    if (_playlistManager.jumpToIndex(index)) {
      await handler.skipToQueueItem(index);
      await handler.play();
    }
  }

  @override
  Future<void> seekTo(Duration position) async {
    try {
      final handler = AudioServiceManager.instance.audioHandler;
      if (handler != null) {
        await handler.seek(position);
      }
      _currentPosition = position;
      notifyListeners();
    } catch (e, stack) {
      Logger.error('跳转失败', e, stack, 'MobileAudioService');
    }
  }

  @override
  Future<void> setVolume(double volume) async {
    try {
      _volume = volume.clamp(0.0, 1.0);
      final handler = AudioServiceManager.instance.audioHandler;
      if (handler != null) {
        await handler.setVolume(_volume);
      }
      notifyListeners();
    } catch (e, stack) {
      Logger.error('设置音量失败', e, stack, 'MobileAudioService');
    }
  }

  @override
  Future<void> setSpeed(double speed) async {
    try {
      _speed = speed.clamp(0.25, 3.0);
      final handler = AudioServiceManager.instance.audioHandler;
      if (handler != null) {
        await handler.setSpeed(_speed);
      }
      notifyListeners();
    } catch (e, stack) {
      Logger.error('设置播放速度失败', e, stack, 'MobileAudioService');
    }
  }

  @override
  Future<void> updatePlaylist(List<Song> songs) async {
    if (songs.isEmpty) return;
    
    final currentSong = _currentPlayingSong;
    if (currentSong == null) return;
    
    final currentIndex = songs.indexWhere((s) => s.id == currentSong.id);
    if (currentIndex == -1) {
      Logger.warning('当前播放的歌曲不在新播放列表中', 'MobileAudioService');
      return;
    }
    
    _playlistManager.updatePlaylist(songs, currentIndex);
    
    // 更新AudioHandler的播放列表
    final handler = AudioServiceManager.instance.audioHandler;
    if (handler != null) {
      await handler.updatePlaylist(songs, initialIndex: currentIndex);
    }
    
    Logger.info('播放列表已更新: ${songs.length} 首歌曲，当前索引: $currentIndex', 'MobileAudioService');
    notifyListeners();
  }

  @override
  Future<void> dispose() async {
    Logger.info('释放移动端音频服务资源', 'MobileAudioService');
    
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();

    await _playingController.close();
    await _positionController.close();
    await _completionController.close();

    super.dispose();
  }
}
