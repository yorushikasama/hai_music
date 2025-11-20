import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/song.dart';
import '../models/play_mode.dart';
import '../utils/logger.dart';

/// 播放列表管理服务
/// 负责管理播放列表、播放模式和播放顺序
class PlaylistManagerService extends ChangeNotifier {
  // 播放列表
  List<Song> _playlist = [];
  int _currentIndex = 0;
  PlayMode _playMode = PlayMode.sequence;
  
  // 随机播放历史（避免重复）
  final List<int> _shuffleHistory = [];
  final int _maxShuffleHistory = 10;
  
  // Getters
  List<Song> get playlist => List.unmodifiable(_playlist);
  int get currentIndex => _currentIndex;
  Song? get currentSong => _playlist.isNotEmpty && _currentIndex >= 0 && _currentIndex < _playlist.length 
      ? _playlist[_currentIndex] 
      : null;
  PlayMode get playMode => _playMode;
  bool get isEmpty => _playlist.isEmpty;
  int get length => _playlist.length;
  bool get hasPrevious => _currentIndex > 0;
  bool get hasNext => _currentIndex < _playlist.length - 1;
  
  /// 设置播放列表
  void setPlaylist(List<Song> songs, {int startIndex = 0}) {
    Logger.info('设置播放列表: ${songs.length} 首歌曲，起始索引: $startIndex', 'PlaylistManager');
    
    _playlist = List.from(songs);
    _currentIndex = startIndex.clamp(0, _playlist.length - 1);
    _shuffleHistory.clear();
    
    notifyListeners();
  }
  
  /// 添加歌曲到播放列表
  void addSong(Song song) {
    _playlist.add(song);
    Logger.info('添加歌曲到播放列表: ${song.title}', 'PlaylistManager');
    notifyListeners();
  }
  
  /// 添加多首歌曲到播放列表
  void addSongs(List<Song> songs) {
    _playlist.addAll(songs);
    Logger.info('添加 ${songs.length} 首歌曲到播放列表', 'PlaylistManager');
    notifyListeners();
  }
  
  /// 更新整个播放列表（保持当前播放位置）
  void updatePlaylist(List<Song> songs, int newCurrentIndex) {
    _playlist.clear();
    _playlist.addAll(songs);
    _currentIndex = newCurrentIndex.clamp(0, songs.length - 1);
    
    Logger.info('更新播放列表: ${songs.length} 首歌曲，当前索引: $_currentIndex', 'PlaylistManager');
    notifyListeners();
  }
  
  /// 插入歌曲到指定位置
  void insertSong(int index, Song song) {
    if (index >= 0 && index <= _playlist.length) {
      _playlist.insert(index, song);
      
      // 调整当前索引
      if (index <= _currentIndex) {
        _currentIndex++;
      }
      
      Logger.info('在位置 $index 插入歌曲: ${song.title}', 'PlaylistManager');
      notifyListeners();
    }
  }
  
  /// 移除指定位置的歌曲
  void removeSongAt(int index) {
    if (index >= 0 && index < _playlist.length) {
      final song = _playlist.removeAt(index);
      
      // 调整当前索引
      if (index < _currentIndex) {
        _currentIndex--;
      } else if (index == _currentIndex && _playlist.isNotEmpty) {
        _currentIndex = _currentIndex.clamp(0, _playlist.length - 1);
      }
      
      Logger.info('移除歌曲: ${song.title}', 'PlaylistManager');
      notifyListeners();
    }
  }
  
  /// 移除歌曲
  void removeSong(Song song) {
    final index = _playlist.indexWhere((s) => s.id == song.id);
    if (index >= 0) {
      removeSongAt(index);
    }
  }
  
  /// 移动歌曲位置
  void moveSong(int oldIndex, int newIndex) {
    if (oldIndex >= 0 && oldIndex < _playlist.length && 
        newIndex >= 0 && newIndex < _playlist.length && 
        oldIndex != newIndex) {
      
      final song = _playlist.removeAt(oldIndex);
      _playlist.insert(newIndex, song);
      
      // 调整当前索引
      if (oldIndex == _currentIndex) {
        _currentIndex = newIndex;
      } else if (oldIndex < _currentIndex && newIndex >= _currentIndex) {
        _currentIndex--;
      } else if (oldIndex > _currentIndex && newIndex <= _currentIndex) {
        _currentIndex++;
      }
      
      Logger.info('移动歌曲: $oldIndex -> $newIndex', 'PlaylistManager');
      notifyListeners();
    }
  }
  
  /// 清空播放列表
  void clearPlaylist() {
    _playlist.clear();
    _currentIndex = 0;
    _shuffleHistory.clear();
    Logger.info('清空播放列表', 'PlaylistManager');
    notifyListeners();
  }
  
  /// 设置播放模式
  void setPlayMode(PlayMode mode) {
    if (_playMode != mode) {
      _playMode = mode;
      _shuffleHistory.clear();
      Logger.info('设置播放模式: $mode', 'PlaylistManager');
      notifyListeners();
    }
  }
  
  /// 切换播放模式
  void togglePlayMode() {
    setPlayMode(_playMode.next);
  }
  
  /// 跳转到指定索引
  bool jumpToIndex(int index) {
    if (index >= 0 && index < _playlist.length && index != _currentIndex) {
      _currentIndex = index;
      Logger.info('跳转到索引: $index', 'PlaylistManager');
      notifyListeners();
      return true;
    }
    return false;
  }
  
  /// 跳转到指定歌曲
  bool jumpToSong(Song song) {
    final index = _playlist.indexWhere((s) => s.id == song.id);
    if (index >= 0) {
      return jumpToIndex(index);
    }
    return false;
  }
  
  /// 获取下一首歌曲的索引
  int? getNextIndex() {
    if (_playlist.isEmpty) return null;
    
    switch (_playMode) {
      case PlayMode.single:
        // 单曲循环：返回当前索引
        return _currentIndex;
        
      case PlayMode.sequence:
        // 顺序播放：下一首或结束
        if (_currentIndex < _playlist.length - 1) {
          return _currentIndex + 1;
        }
        return null; // 播放列表结束
        
      case PlayMode.shuffle:
        // 随机播放：随机选择（避免重复）
        return _getRandomIndex();
    }
  }
  
  /// 获取上一首歌曲的索引
  int? getPreviousIndex() {
    if (_playlist.isEmpty) return null;
    
    switch (_playMode) {
      case PlayMode.single:
        // 单曲循环：返回当前索引
        return _currentIndex;
        
      case PlayMode.sequence:
        // 顺序播放：上一首或开头
        if (_currentIndex > 0) {
          return _currentIndex - 1;
        }
        return null; // 播放列表开头
        
      case PlayMode.shuffle:
        // 随机播放：从历史中获取或随机选择
        if (_shuffleHistory.length > 1) {
          // 移除当前索引，返回上一个
          _shuffleHistory.removeLast();
          return _shuffleHistory.last;
        }
        return _getRandomIndex();
    }
  }
  
  /// 移动到下一首
  bool moveToNext() {
    final nextIndex = getNextIndex();
    if (nextIndex != null) {
      _currentIndex = nextIndex;
      
      // 随机模式下记录历史
      if (_playMode == PlayMode.shuffle) {
        _addToShuffleHistory(_currentIndex);
      }
      
      Logger.info('移动到下一首: $_currentIndex', 'PlaylistManager');
      notifyListeners();
      return true;
    }
    return false;
  }
  
  /// 移动到上一首
  bool moveToPrevious() {
    final prevIndex = getPreviousIndex();
    if (prevIndex != null) {
      _currentIndex = prevIndex;
      Logger.info('移动到上一首: $_currentIndex', 'PlaylistManager');
      notifyListeners();
      return true;
    }
    return false;
  }
  
  /// 获取随机索引（避免重复）
  int _getRandomIndex() {
    if (_playlist.length <= 1) return 0;
    
    final random = Random();
    int nextIndex;
    int attempts = 0;
    const maxAttempts = 10;
    
    do {
      nextIndex = random.nextInt(_playlist.length);
      attempts++;
    } while (attempts < maxAttempts && 
             (nextIndex == _currentIndex || _shuffleHistory.contains(nextIndex)));
    
    _addToShuffleHistory(nextIndex);
    return nextIndex;
  }
  
  /// 添加到随机播放历史
  void _addToShuffleHistory(int index) {
    _shuffleHistory.add(index);
    
    // 限制历史长度
    while (_shuffleHistory.length > _maxShuffleHistory) {
      _shuffleHistory.removeAt(0);
    }
  }
  
  /// 查找歌曲索引
  int findSongIndex(String songId) {
    return _playlist.indexWhere((song) => song.id == songId);
  }
  
  /// 检查歌曲是否在播放列表中
  bool containsSong(String songId) {
    return findSongIndex(songId) >= 0;
  }
  
  /// 获取播放列表信息
  Map<String, dynamic> getPlaylistInfo() {
    return {
      'totalSongs': _playlist.length,
      'currentIndex': _currentIndex,
      'playMode': _playMode.toString(),
      'isEmpty': _playlist.isEmpty,
      'currentSong': currentSong?.toJson(),
    };
  }
}
