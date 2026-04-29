import 'dart:io';

import '../../utils/logger.dart';
import '../core/core.dart';

class LyricsCacheService {
  static final LyricsCacheService _instance = LyricsCacheService._internal();
  factory LyricsCacheService() => _instance;
  LyricsCacheService._internal();

  final PreferencesService _prefs = PreferencesService();
  final StoragePathManager _pathManager = StoragePathManager();

  static const int _cacheExpiryMs = 7 * 24 * 60 * 60 * 1000;

  Future<Map<String, String?>?> get(
    ({String cacheKey, String cacheKeyTrans, String timestampKey}) keys,
  ) async {
    try {
      await _prefs.init();
      final cachedTimestamp = await _prefs.getInt(keys.timestampKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final cacheExpired = (now - cachedTimestamp) > _cacheExpiryMs;

      if (cacheExpired) return null;

      final lrcFile = await _getLyricFile(keys.cacheKey);
      if (!lrcFile.existsSync()) return null;

      final lrc = await lrcFile.readAsString();
      if (lrc.isEmpty) return null;

      String? trans;
      final transFile = await _getLyricFile(keys.cacheKeyTrans);
      if (transFile.existsSync()) {
        trans = await transFile.readAsString();
        if (trans.isEmpty) trans = null;
      }

      return {'lrc': lrc, 'trans': trans};
    } catch (e) {
      Logger.error('读取歌词缓存失败', e, null, 'LyricsCache');
      return null;
    }
  }

  Future<void> put(
    ({String cacheKey, String cacheKeyTrans, String timestampKey}) keys,
    String lrc,
    String? trans,
  ) async {
    try {
      final lrcFile = await _getLyricFile(keys.cacheKey);
      await lrcFile.parent.create(recursive: true);
      await lrcFile.writeAsString(lrc);

      if (trans != null && trans.isNotEmpty) {
        final transFile = await _getLyricFile(keys.cacheKeyTrans);
        await transFile.parent.create(recursive: true);
        await transFile.writeAsString(trans);
      } else {
        final transFile = await _getLyricFile(keys.cacheKeyTrans);
        if (transFile.existsSync()) {
          await transFile.delete();
        }
      }

      await _prefs.setInt(keys.timestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      Logger.error('保存歌词缓存失败', e, null, 'LyricsCache');
    }
  }

  Future<File> _getLyricFile(String cacheKey) async {
    final dir = await _pathManager.getLyricsCacheDir();
    return File('${dir.path}/$cacheKey.lrc');
  }

  Future<void> cleanExpired() async {
    try {
      await _prefs.init();
      final keys = await _prefs.getKeys();
      final timeKeys = keys.where((k) => k.startsWith('lyric_time_')).toList();
      final now = DateTime.now().millisecondsSinceEpoch;
      int cleaned = 0;

      for (final timeKey in timeKeys) {
        final timestamp = await _prefs.getInt(timeKey) ?? 0;
        if ((now - timestamp) > _cacheExpiryMs) {
          final suffix = timeKey.replaceFirst('lyric_time_', '');
          final cacheKey = 'lyric_$suffix';
          final cacheKeyTrans = 'lyric_trans_$suffix';

          final lrcFile = await _getLyricFile(cacheKey);
          if (lrcFile.existsSync()) await lrcFile.delete();

          final transFile = await _getLyricFile(cacheKeyTrans);
          if (transFile.existsSync()) await transFile.delete();

          await _prefs.remove(cacheKey);
          await _prefs.remove(cacheKeyTrans);
          await _prefs.remove(timeKey);
          cleaned++;
        }
      }

      if (cleaned > 0) {
        Logger.info('清理了 $cleaned 个过期歌词缓存', 'LyricsCache');
      }
    } catch (e) {
      Logger.error('清理歌词缓存失败', e, null, 'LyricsCache');
    }
  }

  Future<void> migrateFromSharedPreferences() async {
    try {
      await _prefs.init();
      final keys = await _prefs.getKeys();
      final lyricKeys = keys
          .where((k) =>
              k.startsWith('lyric_') &&
              !k.startsWith('lyric_time_') &&
              !k.contains('_trans_'))
          .toList();

      int migrated = 0;
      for (final cacheKey in lyricKeys) {
        final cachedLyric = await _prefs.getString(cacheKey);
        if (cachedLyric == null || cachedLyric.isEmpty) continue;

        final timestampKey = cacheKey.replaceFirst('lyric_', 'lyric_time_');
        final cachedTimestamp = await _prefs.getInt(timestampKey) ?? 0;
        final now = DateTime.now().millisecondsSinceEpoch;

        if ((now - cachedTimestamp) > _cacheExpiryMs) {
          await _prefs.remove(cacheKey);
          await _prefs.remove(timestampKey);
          final transKey = cacheKey.replaceFirst('lyric_', 'lyric_trans_');
          await _prefs.remove(transKey);
          continue;
        }

        final lrcFile = await _getLyricFile(cacheKey);
        await lrcFile.parent.create(recursive: true);
        await lrcFile.writeAsString(cachedLyric);

        final transKey = cacheKey.replaceFirst('lyric_', 'lyric_trans_');
        final cachedTrans = await _prefs.getString(transKey);
        if (cachedTrans != null && cachedTrans.isNotEmpty) {
          final transFile = await _getLyricFile(transKey);
          await transFile.parent.create(recursive: true);
          await transFile.writeAsString(cachedTrans);
          await _prefs.remove(transKey);
        }

        await _prefs.remove(cacheKey);
        migrated++;
      }

      if (migrated > 0) {
        Logger.info('迁移了 $migrated 个歌词缓存从SP到文件存储', 'LyricsCache');
      }
    } catch (e) {
      Logger.error('迁移歌词缓存失败', e, null, 'LyricsCache');
    }
  }
}
