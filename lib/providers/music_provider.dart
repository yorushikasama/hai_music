import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:math' show Random;
import '../models/song.dart';
import '../models/audio_quality.dart';
import '../models/play_mode.dart';
import '../services/music_api_service.dart';
import '../services/preferences_service.dart';
import '../services/favorite_manager_service.dart';
import '../services/play_history_service.dart';

class MusicProvider with ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final MusicApiService _apiService = MusicApiService();
  final PreferencesService _prefs = PreferencesService();
  final FavoriteManagerService _favoriteManager = FavoriteManagerService();
  final PlayHistoryService _historyService = PlayHistoryService();
  
  Song? _currentSong;
  List<Song> _playlist = [];
  int _currentIndex = 0;
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  bool _isLoading = false;
  AudioQuality _audioQuality = AudioQuality.high; // 默认HQ高音质
  PlayMode _playMode = PlayMode.sequence; // 默认顺序播放
  final Random _random = Random();
  double _volume = 1.0; // 音量 0.0 - 1.0
  final Set<String> _favoriteSongIds = {}; // 收藏的歌曲ID集合

  MusicProvider() {
    _initAudioPlayer();
    _loadSettings();
    _loadFavorites();
    _initFavoriteManager();
  }

  // 初始化收藏管理服务
  void _initFavoriteManager() async {
    await _favoriteManager.initialize();
  }

  // 从本地加载设置
  void _loadSettings() {
    _volume = _prefs.getVolume();
    _audioPlayer.setVolume(_volume);
    
    final modeStr = _prefs.getPlayMode();
    _playMode = _parsePlayMode(modeStr);
    
    final qualityStr = _prefs.getAudioQuality();
    _audioQuality = _parseAudioQuality(qualityStr);
    
    notifyListeners();
  }

  PlayMode _parsePlayMode(String mode) {
    switch (mode) {
      case 'single':
        return PlayMode.single;
      case 'shuffle':
        return PlayMode.shuffle;
      default:
        return PlayMode.sequence;
    }
  }

  AudioQuality _parseAudioQuality(String quality) {
    switch (quality) {
      case 'standard':
        return AudioQuality.standard;
      case 'high':
        return AudioQuality.high;
      case 'lossless':
        return AudioQuality.lossless;
      default:
        return AudioQuality.high;
    }
  }

  void _initAudioPlayer() {
    // 监听播放状态
    _audioPlayer.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;
      notifyListeners();
    });

    // 监听播放进度
    _audioPlayer.onPositionChanged.listen((position) {
      _currentPosition = position;
      notifyListeners();
    });

    // 监听总时长
    _audioPlayer.onDurationChanged.listen((duration) {
      _totalDuration = duration;
      notifyListeners();
    });

    // 监听播放完成
    _audioPlayer.onPlayerComplete.listen((_) {
      _handlePlayComplete();
    });
  }

  Song? get currentSong => _currentSong;
  List<Song> get playlist => _playlist;
  int get currentIndex => _currentIndex;
  bool get isPlaying => _isPlaying;
  Duration get currentPosition => _currentPosition;
  Duration get totalDuration => _totalDuration;
  AudioQuality get audioQuality => _audioQuality;
  PlayMode get playMode => _playMode;
  double get volume => _volume;
  
  // 兼容旧代码
  bool get isRepeat => _playMode == PlayMode.single;
  bool get isShuffle => _playMode == PlayMode.shuffle;

  void playSong(Song song, {List<Song>? playlist}) async {
    _currentSong = song;
    if (playlist != null) {
      _playlist = playlist;
      _currentIndex = playlist.indexOf(song);
    }
    _isLoading = true;
    notifyListeners();

    try {
      // 获取播放链接（使用当前设置的音质）
      final audioUrl = await _apiService.getSongUrl(
        songId: song.id,
        quality: _audioQuality.value,
      );

      if (audioUrl != null && audioUrl.isNotEmpty) {
        await _audioPlayer.stop();
        await _audioPlayer.play(UrlSource(audioUrl));
        _isPlaying = true;
        
        // 添加到播放历史
        _historyService.addHistory(song);
      } else {
        print('无法获取播放链接');
        _isPlaying = false;
      }
    } catch (e) {
      print('播放歌曲出错: $e');
      _isPlaying = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void togglePlayPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.resume();
    }
  }

  void pause() async {
    await _audioPlayer.pause();
  }

  void play() async {
    await _audioPlayer.resume();
  }

  void _handlePlayComplete() {
    switch (_playMode) {
      case PlayMode.single:
        // 单曲循环：重新播放当前歌曲
        _audioPlayer.seek(Duration.zero);
        _audioPlayer.resume();
        break;
      case PlayMode.sequence:
        // 顺序播放：播放下一首，循环播放
        playNext();
        break;
      case PlayMode.shuffle:
        // 随机播放：随机选择下一首
        playNext();
        break;
    }
  }

  void playNext() {
    if (_playlist.isEmpty) return;
    
    if (_playMode == PlayMode.shuffle) {
      // 随机播放：随机选择一首（避免重复当前歌曲）
      if (_playlist.length > 1) {
        int nextIndex;
        do {
          nextIndex = _random.nextInt(_playlist.length);
        } while (nextIndex == _currentIndex);
        _currentIndex = nextIndex;
      }
    } else {
      // 其他模式：顺序播放下一首
      _currentIndex = (_currentIndex + 1) % _playlist.length;
    }
    
    _currentSong = _playlist[_currentIndex];
    playSong(_currentSong!, playlist: _playlist);
  }

  void playPrevious() {
    if (_playlist.isEmpty) return;
    
    _currentIndex = (_currentIndex - 1 + _playlist.length) % _playlist.length;
    _currentSong = _playlist[_currentIndex];
    playSong(_currentSong!, playlist: _playlist);
  }

  void seekTo(Duration position) async {
    await _audioPlayer.seek(position);
  }

  void updatePosition(Duration position) {
    _currentPosition = position;
    notifyListeners();
  }

  void togglePlayMode() async {
    _playMode = _playMode.next;
    await _prefs.setPlayMode(_playMode.toString().split('.').last); // 保存播放模式
    notifyListeners();
  }
  
  void setPlayMode(PlayMode mode) {
    _playMode = mode;
    notifyListeners();
  }

  // 兼容旧代码
  void toggleRepeat() {
    if (_playMode == PlayMode.single) {
      _playMode = PlayMode.sequence;
    } else {
      _playMode = PlayMode.single;
    }
    notifyListeners();
  }

  void toggleShuffle() {
    if (_playMode == PlayMode.shuffle) {
      _playMode = PlayMode.sequence;
    } else {
      _playMode = PlayMode.shuffle;
    }
    notifyListeners();
  }

  void setPlaylist(List<Song> songs) {
    _playlist = songs;
    notifyListeners();
  }

  bool get isLoading => _isLoading;

  void setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _audioPlayer.setVolume(_volume);
    await _prefs.setVolume(_volume); // 保存音量设置
    notifyListeners();
  }

  void setAudioQuality(AudioQuality quality) async {
    _audioQuality = quality;
    await _prefs.setAudioQuality(quality.toString().split('.').last); // 保存音质设置
    notifyListeners();
    
    // 如果正在播放，重新加载当前歌曲以应用新音质
    if (_currentSong != null && _isPlaying) {
      final currentSong = _currentSong;
      final currentPlaylist = _playlist;
      playSong(currentSong!, playlist: currentPlaylist.isNotEmpty ? currentPlaylist : null);
    }
  }

  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  // 加载收藏列表
  void _loadFavorites() {
    final favorites = _prefs.getFavoriteSongs();
    _favoriteSongIds.addAll(favorites);
    notifyListeners();
  }

  // 检查歌曲是否已收藏
  bool isFavorite(String songId) {
    return _favoriteSongIds.contains(songId);
  }

  // 切换收藏状态
  void toggleFavorite(String songId) async {
    if (_favoriteSongIds.contains(songId)) {
      _favoriteSongIds.remove(songId);
      await _favoriteManager.removeFavorite(songId);
    } else {
      _favoriteSongIds.add(songId);
      // 查找当前歌曲对象
      Song? song = _currentSong?.id == songId ? _currentSong : null;
      if (song == null) {
        song = _playlist.firstWhere((s) => s.id == songId, orElse: () => _currentSong!);
      }
      if (song != null) {
        await _favoriteManager.addFavorite(song);
      }
    }
    await _prefs.setFavoriteSongs(_favoriteSongIds.toList());
    notifyListeners();
  }

  // 获取收藏列表
  Set<String> get favoriteSongIds => _favoriteSongIds;

  // 获取收藏管理服务
  FavoriteManagerService get favoriteManager => _favoriteManager;
  
  // 获取播放历史服务
  PlayHistoryService get historyService => _historyService;

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
