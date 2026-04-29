import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../models/play_mode.dart';
import '../../models/song.dart';
import '../../utils/logger.dart';

/// 播放列表管理服务
/// 负责管理播放列表、播放模式和播放顺序
class PlaylistManagerService extends ChangeNotifier {
  // 播放列表
  List<Song> _playlist = [];
  int _currentIndex = 0;
  PlayMode _playMode = PlayMode.sequence;
  
  // 随机播放历史（避免重复）
  final List<int> _shuffleHistory = [];
  static const int _maxShuffleHistory = 50;
  
  // Getters
  /// 当前播放列表（不可修改副本）
  List<Song> get playlist => List.unmodifiable(_playlist);

  /// 当前播放索引
  int get currentIndex => _currentIndex;

  /// 当前播放的歌曲
  Song? get currentSong => _playlist.isNotEmpty && _currentIndex >= 0 && _currentIndex < _playlist.length 
      ? _playlist[_currentIndex] 
      : null;

  /// 当前播放模式
  PlayMode get playMode => _playMode;

  /// 播放列表是否为空
  bool get isEmpty => _playlist.isEmpty;

  /// 播放列表长度
  int get length => _playlist.length;

  /// 是否有上一首
  bool get hasPrevious => _playMode == PlayMode.shuffle ? _shuffleHistory.length > 1 : _currentIndex > 0;

  /// 是否有下一首
  bool get hasNext => _playMode == PlayMode.shuffle ? _playlist.isNotEmpty : _currentIndex < _playlist.length - 1;
  
  /// 设置播放列表
  void setPlaylist(List<Song> songs, {int startIndex = 0}) {
    Logger.info('设置播放列表: ${songs.length} 首歌曲，起始索引: $startIndex', 'PlaylistManager');
    
    _playlist = List.from(songs);
    _currentIndex = _playlist.isEmpty ? 0 : startIndex.clamp(0, _playlist.length - 1);
    _shuffleHistory.clear();
    
    notifyListeners();
  }
  
  /// 添加歌曲到播放列表
  void addSong(Song song) {
    _playlist.add(song);
    Logger.info('添加歌曲到播放列表: ${song.title}', 'PlaylistManager');
    notifyListeners();
  }
  
  /// 更新整个播放列表（保持当前播放位置）
  void updatePlaylist(List<Song> songs, int newCurrentIndex) {
    _playlist.clear();
    _playlist.addAll(songs);
    _currentIndex = songs.isEmpty ? 0 : newCurrentIndex.clamp(0, songs.length - 1);
    
    Logger.info('更新播放列表: ${songs.length} 首歌曲，当前索引: $_currentIndex', 'PlaylistManager');
    notifyListeners();
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
      if (_playMode == PlayMode.shuffle && _playlist.isNotEmpty) {
        _addToShuffleHistory(_currentIndex);
      }
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
        if (_shuffleHistory.length > 1) {
          return _shuffleHistory[_shuffleHistory.length - 2];
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
      if (_playMode == PlayMode.shuffle && _shuffleHistory.length > 1) {
        _shuffleHistory.removeLast();
      }
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

    final availableIndices = <int>[];
    for (int i = 0; i < _playlist.length; i++) {
      if (i != _currentIndex && !_shuffleHistory.contains(i)) {
        availableIndices.add(i);
      }
    }

    if (availableIndices.isEmpty) {
      _shuffleHistory.clear();
      for (int i = 0; i < _playlist.length; i++) {
        if (i != _currentIndex) {
          availableIndices.add(i);
        }
      }
    }

    if (availableIndices.isEmpty) return 0;

    final random = Random();
    final nextIndex = availableIndices[random.nextInt(availableIndices.length)];
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
