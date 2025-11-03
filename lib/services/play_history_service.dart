import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/play_history.dart';
import '../models/song.dart';

/// 播放历史服务
class PlayHistoryService {
  static const String _historyKey = 'play_history';
  static const int _maxHistoryCount = 100; // 最多保存100条记录

  /// 添加播放记录
  Future<void> addHistory(Song song) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyList = await getHistory();

      // 移除相同歌曲的旧记录
      historyList.removeWhere((h) => h.id == song.id);

      // 添加新记录到开头
      final newHistory = PlayHistory(
        id: song.id,
        title: song.title,
        artist: song.artist,
        album: song.album,
        coverUrl: song.coverUrl,
        duration: song.duration,
        platform: song.platform,
        playedAt: DateTime.now(),
      );

      historyList.insert(0, newHistory);

      // 限制最大数量
      if (historyList.length > _maxHistoryCount) {
        historyList.removeRange(_maxHistoryCount, historyList.length);
      }

      // 保存到本地
      final jsonList = historyList.map((h) => json.encode(h.toJson())).toList();
      await prefs.setStringList(_historyKey, jsonList);
    } catch (e) {
      print('添加播放历史失败: $e');
    }
  }

  /// 获取播放历史列表
  Future<List<PlayHistory>> getHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_historyKey) ?? [];
      
      return jsonList.map((jsonStr) {
        final map = json.decode(jsonStr) as Map<String, dynamic>;
        return PlayHistory.fromJson(map);
      }).toList();
    } catch (e) {
      print('获取播放历史失败: $e');
      return [];
    }
  }

  /// 清空播放历史
  Future<void> clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_historyKey);
    } catch (e) {
      print('清空播放历史失败: $e');
    }
  }

  /// 删除单条记录
  Future<void> removeHistory(String songId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyList = await getHistory();
      
      historyList.removeWhere((h) => h.id == songId);
      
      final jsonList = historyList.map((h) => json.encode(h.toJson())).toList();
      await prefs.setStringList(_historyKey, jsonList);
    } catch (e) {
      print('删除播放历史失败: $e');
    }
  }
}
