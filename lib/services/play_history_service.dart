import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/play_history.dart';
import '../models/song.dart';
import '../utils/logger.dart';

class PlayHistoryService {
  static final PlayHistoryService _instance = PlayHistoryService._internal();
  factory PlayHistoryService() => _instance;
  PlayHistoryService._internal();

  static const String _historyKey = 'play_history';
  static const int _maxHistoryCount = 100;

  Completer<void>? _lock;

  Future<T> _synchronized<T>(Future<T> Function() action) async {
    while (_lock != null) {
      try {
        await _lock!.future;
      } catch (e) {
        Logger.debug('播放历史锁等待中断', 'PlayHistory');
      }
    }
    _lock = Completer<void>();
    try {
      final result = await action();
      return result;
    } finally {
      final lock = _lock!;
      _lock = null;
      lock.complete();
    }
  }

  Future<void> addHistory(Song song) async {
    await _synchronized(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final historyList = await getHistory();

        historyList.removeWhere((h) => h.id == song.id);

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

        if (historyList.length > _maxHistoryCount) {
          historyList.removeRange(_maxHistoryCount, historyList.length);
        }

        final jsonList = historyList.map((h) => json.encode(h.toJson())).toList();
        await prefs.setStringList(_historyKey, jsonList);
      } catch (e) {
        Logger.error('添加播放历史失败', e, null, 'PlayHistory');
      }
    });
  }

  Future<List<PlayHistory>> getHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_historyKey) ?? [];

      return jsonList.map((jsonStr) {
        final map = json.decode(jsonStr) as Map<String, dynamic>;
        return PlayHistory.fromJson(map);
      }).toList();
    } catch (e) {
      Logger.error('获取播放历史失败', e, null, 'PlayHistory');
      return [];
    }
  }

  Future<void> clearHistory() async {
    await _synchronized(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_historyKey);
      } catch (e) {
        Logger.error('清空播放历史失败', e, null, 'PlayHistory');
      }
    });
  }

  Future<void> removeHistory(String songId) async {
    await _synchronized(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final historyList = await getHistory();

        historyList.removeWhere((h) => h.id == songId);

        final jsonList = historyList.map((h) => json.encode(h.toJson())).toList();
        await prefs.setStringList(_historyKey, jsonList);
      } catch (e) {
        Logger.error('删除播放历史失败', e, null, 'PlayHistory');
      }
    });
  }
}
