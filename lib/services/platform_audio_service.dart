import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/song.dart';
import '../models/play_mode.dart';
import '../utils/logger.dart';
import 'audio_player_interface.dart';
import 'audio_player_factory.dart';
import 'playlist_manager_service.dart';
import 'song_url_service.dart';
import 'smart_cache_service.dart';

/// 统一的平台音频服务
/// 抽象平台差异，提供统一的音频播放接口
abstract class PlatformAudioService {
  /// 播放状态
  bool get isPlaying;
  
  /// 是否正在加载
  bool get isLoading;
  
  /// 当前播放位置
  Duration get currentPosition;
  
  /// 总时长
  Duration get totalDuration;
  
  /// 音量
  double get volume;
  
  /// 播放速度
  double get speed;
  
  /// 当前播放的歌曲
  Song? get currentPlayingSong;
  
  /// 播放状态流
  Stream<bool> get playingStream;
  
  /// 播放位置流
  Stream<Duration> get positionStream;
  
  /// 播放完成流
  Stream<void> get completionStream;
  
  /// 播放歌曲列表
  Future<void> playSongs(List<Song> songs, {int startIndex = 0});
  
  /// 播放单首歌曲
  Future<void> playSong(Song song, {List<Song>? playlist});
  
  /// 播放/暂停切换
  Future<void> togglePlayPause();
  
  /// 暂停播放
  Future<void> pause();
  
  /// 继续播放
  Future<void> resume();
  
  /// 停止播放
  Future<void> stop();
  
  /// 播放下一首
  Future<void> playNext();
  
  /// 播放上一首
  Future<void> playPrevious();
  
  /// 跳转到指定歌曲
  Future<void> jumpToSong(Song song);
  
  /// 跳转到指定索引
  Future<void> jumpToIndex(int index);
  
  /// 跳转到指定位置
  Future<void> seekTo(Duration position);
  
  /// 设置音量
  Future<void> setVolume(double volume);
  
  /// 设置播放速度
  Future<void> setSpeed(double speed);
  
  /// 更新播放列表
  Future<void> updatePlaylist(List<Song> songs);
  
  /// 释放资源
  Future<void> dispose();
}

/// 桌面端音频服务实现
class DesktopAudioService extends ChangeNotifier implements PlatformAudioService {
  AudioPlayerInterface? _audioPlayer;
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
  int _playRequestVersion = 0;
  
  final List<StreamSubscription> _subscriptions = [];
  final StreamController<bool> _playingController = StreamController<bool>.broadcast();
  final StreamController<Duration> _positionController = StreamController<Duration>.broadcast();
  final StreamController<void> _completionController = StreamController<void>.broadcast();

  DesktopAudioService({
    required PlaylistManagerService playlistManager,
    required SongUrlService urlService,
  }) : _playlistManager = playlistManager,
       _urlService = urlService {
    _initialize();
  }

  void _initialize() {
    Logger.info('初始化桌面端音频服务', 'DesktopAudioService');
    _audioPlayer = AudioPlayerFactory.createPlayer();
    
    _subscriptions.add(_audioPlayer!.playingStream.listen((playing) {
      if (_isPlaying != playing) {
        _isPlaying = playing;
        _playingController.add(playing);
        notifyListeners();
      }
    }));

    _subscriptions.add(_audioPlayer!.positionStream.listen((position) {
      _currentPosition = position;
      _positionController.add(position);
      notifyListeners();
    }));

    _subscriptions.add(_audioPlayer!.durationStream.listen((duration) {
      _totalDuration = duration ?? Duration.zero;
      notifyListeners();
    }));

    _subscriptions.add(_audioPlayer!.completionStream.listen((_) {
      _completionController.add(null);
      _handlePlaybackCompleted();
    }));
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
      Logger.warning('歌曲列表为空', 'DesktopAudioService');
      return;
    }

    Logger.info('播放歌曲列表: ${songs.length} 首，起始索引: $startIndex', 'DesktopAudioService');
    _playlistManager.setPlaylist(songs, startIndex: startIndex);
    await _playCurrentSong();
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

  Future<void> _playCurrentSong() async {
    final currentSong = _playlistManager.currentSong;
    if (currentSong == null) {
      Logger.warning('没有当前歌曲可播放', 'DesktopAudioService');
      return;
    }

    _playRequestVersion++;
    final currentVersion = _playRequestVersion;

    _isLoading = true;
    notifyListeners();

    try {
      final audioUrl = await _urlService.getSongUrl(currentSong);
      
      if (currentVersion != _playRequestVersion) {
        Logger.debug('播放请求已过期', 'DesktopAudioService');
        return;
      }

      if (audioUrl == null || audioUrl.isEmpty) {
        throw Exception('获取播放链接失败: ${currentSong.title}');
      }

      final songWithUrl = currentSong.copyWith(audioUrl: audioUrl);
      _currentPlayingSong = songWithUrl;

      await _audioPlayer?.play(songWithUrl);
      
      _cacheService.cacheOnPlay(songWithUrl).catchError((e) {
        Logger.error('缓存歌曲失败: ${songWithUrl.title}', e, null, 'DesktopAudioService');
      });

      Logger.success('播放成功: ${currentSong.title}', 'DesktopAudioService');
    } catch (e) {
      Logger.error('播放失败: ${currentSong.title}', e, null, 'DesktopAudioService');
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

  @override
  Future<void> togglePlayPause() async {
    try {
      if (_isPlaying) {
        await _audioPlayer?.pause();
      } else {
        if (_currentPlayingSong != null) {
          await _audioPlayer?.resume();
        } else {
          await _playCurrentSong();
        }
      }
    } catch (e) {
      Logger.error('播放/暂停切换失败', e, null, 'DesktopAudioService');
    }
  }

  @override
  Future<void> pause() async {
    try {
      await _audioPlayer?.pause();
    } catch (e) {
      Logger.error('暂停播放失败', e, null, 'DesktopAudioService');
    }
  }

  @override
  Future<void> resume() async {
    try {
      await _audioPlayer?.resume();
    } catch (e) {
      Logger.error('继续播放失败', e, null, 'DesktopAudioService');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _audioPlayer?.stop();
      _currentPlayingSong = null;
      _currentPosition = Duration.zero;
      _totalDuration = Duration.zero;
      notifyListeners();
    } catch (e) {
      Logger.error('停止播放失败', e, null, 'DesktopAudioService');
    }
  }

  @override
  Future<void> playNext() async {
    if (_playlistManager.moveToNext()) {
      await _playCurrentSong();
    } else {
      Logger.info('已到达播放列表末尾', 'DesktopAudioService');
      await stop();
    }
  }

  @override
  Future<void> playPrevious() async {
    if (_playlistManager.moveToPrevious()) {
      await _playCurrentSong();
    } else {
      Logger.info('已到达播放列表开头', 'DesktopAudioService');
    }
  }

  @override
  Future<void> jumpToSong(Song song) async {
    if (_playlistManager.jumpToSong(song)) {
      await _playCurrentSong();
    }
  }

  @override
  Future<void> jumpToIndex(int index) async {
    if (_playlistManager.jumpToIndex(index)) {
      await _playCurrentSong();
    }
  }

  @override
  Future<void> seekTo(Duration position) async {
    try {
      await _audioPlayer?.seek(position);
      _currentPosition = position;
      notifyListeners();
    } catch (e) {
      Logger.error('跳转失败', e, null, 'DesktopAudioService');
    }
  }

  @override
  Future<void> setVolume(double volume) async {
    try {
      _volume = volume.clamp(0.0, 1.0);
      await _audioPlayer?.setVolume(_volume);
      notifyListeners();
    } catch (e) {
      Logger.error('设置音量失败', e, null, 'DesktopAudioService');
    }
  }

  @override
  Future<void> setSpeed(double speed) async {
    try {
      _speed = speed.clamp(0.25, 3.0);
      await _audioPlayer?.setSpeed(_speed);
      notifyListeners();
    } catch (e) {
      Logger.error('设置播放速度失败', e, null, 'DesktopAudioService');
    }
  }

  @override
  Future<void> updatePlaylist(List<Song> songs) async {
    if (songs.isEmpty) return;
    
    final currentSong = _currentPlayingSong;
    if (currentSong == null) return;
    
    final currentIndex = songs.indexWhere((s) => s.id == currentSong.id);
    if (currentIndex == -1) {
      Logger.warning('当前播放的歌曲不在新播放列表中', 'DesktopAudioService');
      return;
    }
    
    _playlistManager.updatePlaylist(songs, currentIndex);
    Logger.info('播放列表已更新: ${songs.length} 首歌曲，当前索引: $currentIndex', 'DesktopAudioService');
    notifyListeners();
  }

  void _handlePlaybackCompleted() {
    Logger.info('播放完成: ${_currentPlayingSong?.title}', 'DesktopAudioService');
    
    if (_isLoading) {
      Logger.debug('正在加载中，忽略播放完成事件', 'DesktopAudioService');
      return;
    }
    
    switch (_playlistManager.playMode) {
      case PlayMode.single:
        _audioPlayer?.seek(Duration.zero);
        _audioPlayer?.resume();
        break;
      case PlayMode.sequence:
      case PlayMode.shuffle:
        _tryPlayNext();
        break;
    }
  }

  Future<void> _tryPlayNext() async {
    if (_playlistManager.moveToNext()) {
      await _playCurrentSong();
    } else {
      Logger.info('播放列表结束', 'DesktopAudioService');
      await stop();
    }
  }

  @override
  Future<void> dispose() async {
    Logger.info('释放桌面端音频服务资源', 'DesktopAudioService');
    
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();

    await _playingController.close();
    await _positionController.close();
    await _completionController.close();

    _audioPlayer?.dispose();
    
    super.dispose();
  }
}
