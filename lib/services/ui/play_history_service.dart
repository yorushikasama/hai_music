import 'dart:async';
import 'dart:convert';

import '../../config/app_constants.dart';
import '../../models/play_history.dart';
import '../../models/song.dart';
import '../../utils/logger.dart';
import '../core/preferences_service.dart';

class PlayHistoryService {
  static final PlayHistoryService _instance = PlayHistoryService._internal();
  factory PlayHistoryService() => _instance;
  PlayHistoryService._internal();

  static const String _historyKey = 'play_history';
  final _prefs = PreferencesService();

  Completer<void>? _lock;

  Future<T> _synchronized<T>(Future<T> Function() action) async {
    while (_lock != null) {
      try {
        await _lock!.future;
      } catch (e) {
        // 前一个操作异常完成，继续等待获取锁
      }
    }
    _lock = Completer<void>();
    try {
      final result = await action();
      return result;
    } catch (e) {
      // 操作异常时通过 completeError 通知等待者
      final lock = _lock!;
      _lock = null;
      lock.completeError(e);
      rethrow;
    } finally {
      // 只有在未通过 catch 分支完成时才正常 complete
      if (_lock != null) {
        final lock = _lock!;
        _lock = null;
        lock.complete();
      }
    }
  }

  Future<void> addHistory(Song song) async {
    await _synchronized(() async {
      try {
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

        if (historyList.length > AppConstants.maxPlayHistory) {
          historyList.removeRange(AppConstants.maxPlayHistory, historyList.length);
        }

        final jsonStr = json.encode(historyList.map((h) => h.toJson()).toList());
        await _prefs.setString(_historyKey, jsonStr);
      } catch (e) {
        Logger.error('添加播放历史失败', e, null, 'PlayHistory');
      }
    });
  }

  Future<List<PlayHistory>> getHistory() async {
    try {
      final jsonStr = await _prefs.getString(_historyKey);
      if (jsonStr == null || jsonStr.isEmpty) return [];

      final jsonList = json.decode(jsonStr) as List<dynamic>;
      return jsonList.map((map) => PlayHistory.fromJson(map as Map<String, dynamic>)).toList();
    } catch (e) {
      Logger.error('获取播放历史失败', e, null, 'PlayHistory');
      return [];
    }
  }

  Future<void> clearHistory() async {
    await _synchronized(() async {
      try {
        await _prefs.remove(_historyKey);
      } catch (e) {
        Logger.error('清空播放历史失败', e, null, 'PlayHistory');
      }
    });
  }

  Future<void> removeHistory(String songId) async {
    await _synchronized(() async {
      try {
        final historyList = await getHistory();
        historyList.removeWhere((h) => h.id == songId);

        final jsonStr = json.encode(historyList.map((h) => h.toJson()).toList());
        await _prefs.setString(_historyKey, jsonStr);
      } catch (e) {
        Logger.error('删除播放历史失败', e, null, 'PlayHistory');
      }
    });
  }
}
