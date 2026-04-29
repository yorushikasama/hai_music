import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../utils/format_utils.dart';
import '../../utils/logger.dart';
import '../storage/storage.dart';
import '../cache/cache.dart';
import '../download/download.dart';
import '../core/core.dart';

enum PurgeCategory {
  playCache,
  imageCache,
  lyricsCache,
  dataCache,
  coverPersistence,
  downloadedSongs,
  preferences,
  secureStorage,
}

class PurgeResult {
  final Map<PurgeCategory, bool> results;
  final Map<PurgeCategory, String> messages;
  final DateTime timestamp;

  PurgeResult({
    required this.results,
    required this.messages,
    required this.timestamp,
  });

  bool get allSuccess => results.values.every((v) => v);
  int get successCount => results.values.where((v) => v).length;
  int get totalCount => results.length;

  String get summary {
    final success = successCount;
    final total = totalCount;
    return '$success/$total 项清理成功';
  }
}

class DataPurgeService {
  static final DataPurgeService _instance = DataPurgeService._internal();
  factory DataPurgeService() => _instance;
  DataPurgeService._internal();

  final StoragePathManager _pathManager = StoragePathManager();
  final CacheManagerService _cacheManager = CacheManagerService();

  /// 获取缓存大小信息（代理 CacheManagerService，供 Screen 层使用）
  Future<CacheInfo> getCacheInfo({bool forceRefresh = false}) async {
    return _cacheManager.getCacheInfo(forceRefresh: forceRefresh);
  }

  /// 清理所有缓存（代理 CacheManagerService，供 Screen 层使用）
  Future<bool> clearAllCache() async {
    return _cacheManager.clearAllCache();
  }

  /// 全量数据清除 - 不可逆操作！
  ///
  /// 此方法会删除所有应用数据（缓存、下载、偏好设置、安全存储等）。
  /// 调用方必须在 UI 层提供二次确认对话框后才能调用此方法。
  Future<PurgeResult> purgeAll() async {
    Logger.warning('开始执行全量数据清除...', 'DataPurge');

    final results = <PurgeCategory, bool>{};
    final messages = <PurgeCategory, String>{};

    await _purgeCategory(
      PurgeCategory.playCache,
      () => _purgePlayCache(),
      results,
      messages,
    );

    await _purgeCategory(
      PurgeCategory.imageCache,
      () => _purgeImageCache(),
      results,
      messages,
    );

    await _purgeCategory(
      PurgeCategory.lyricsCache,
      () => _purgeLyricsCache(),
      results,
      messages,
    );

    await _purgeCategory(
      PurgeCategory.dataCache,
      () => _purgeDataCache(),
      results,
      messages,
    );

    await _purgeCategory(
      PurgeCategory.coverPersistence,
      () => _purgeCoverPersistence(),
      results,
      messages,
    );

    await _purgeCategory(
      PurgeCategory.downloadedSongs,
      () => _purgeDownloadedSongs(),
      results,
      messages,
    );

    await _purgeCategory(
      PurgeCategory.preferences,
      () => _purgePreferences(),
      results,
      messages,
    );

    await _purgeCategory(
      PurgeCategory.secureStorage,
      () => _purgeSecureStorage(),
      results,
      messages,
    );

    final result = PurgeResult(
      results: results,
      messages: messages,
      timestamp: DateTime.now(),
    );

    Logger.success(
      '全量数据清除完成: ${result.summary}',
      'DataPurge',
    );

    return result;
  }

  Future<void> _purgeCategory(
    PurgeCategory category,
    Future<String> Function() action,
    Map<PurgeCategory, bool> results,
    Map<PurgeCategory, String> messages,
  ) async {
    try {
      final msg = await action();
      results[category] = true;
      messages[category] = msg;
      Logger.success(msg, 'DataPurge');
    } catch (e) {
      results[category] = false;
      messages[category] = '${_categoryLabel(category)}失败: $e';
      Logger.error('${_categoryLabel(category)}失败', e, null, 'DataPurge');
    }
  }

  Future<String> _purgePlayCache() async {
    final service = SmartCacheService();
    final size = await service.getPlayCacheSize();
    await service.clearPlayCache();
    return '播放缓存已清除 (${FormatUtils.formatSize(size)})';
  }

  Future<String> _purgeImageCache() async {
    final cacheDir = await _pathManager.getImageCacheDir();
    int size = 0;
    if (await cacheDir.exists()) {
      await for (final entity
          in cacheDir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          try {
            size += await entity.length();
          } catch (_) {}
        }
      }
    }

    final cacheManager = DefaultCacheManager();
    await cacheManager.emptyCache();

    if (await cacheDir.exists()) {
      await cacheDir.delete(recursive: true);
    }

    return '图片缓存已清除 (${FormatUtils.formatSize(size)})';
  }

  Future<String> _purgeLyricsCache() async {
    final lyricsDir = await _pathManager.getLyricsCacheDir();
    int count = 0;
    int size = 0;

    if (await lyricsDir.exists()) {
      await for (final entity in lyricsDir.list()) {
        if (entity is File) {
          try {
            size += await entity.length();
            await entity.delete();
            count++;
          } catch (_) {}
        }
      }
    }

    final prefs = PreferencesService();
    await prefs.init();
    final keys = await prefs.getKeys();
    final lyricKeys =
        keys.where((k) => k.startsWith('lyric_') || k.startsWith('lyric_time_'));
    for (final key in lyricKeys) {
      await prefs.remove(key);
    }

    return '歌词缓存已清除 ($count 个文件, ${FormatUtils.formatSize(size)})';
  }

  Future<String> _purgeDataCache() async {
    final service = DataCacheService();
    await service.init();
    await service.clearAllCache();
    return '数据缓存已清除';
  }

  Future<String> _purgeCoverPersistence() async {
    final service = CoverPersistenceService();
    await service.init();
    final count = await service.getPersistentCoverCount();
    final size = await service.getPersistentCoverSize();
    await service.clearAll();
    return '持久化封面已清除 ($count 个, ${FormatUtils.formatSize(size)})';
  }

  Future<String> _purgeDownloadedSongs() async {
    final downloadService = DownloadService();
    final recordCount = await downloadService.getDownloadedCount();

    final downloadDir = await _pathManager.getDownloadsDir();
    int fileCount = 0;
    int size = 0;

    if (await downloadDir.exists()) {
      await for (final entity
          in downloadDir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          try {
            size += await entity.length();
            fileCount++;
          } catch (_) {}
        }
      }
      await downloadDir.delete(recursive: true);
    }

    // 清空数据库记录并删除数据库文件（合并操作，避免 db.deleteAll 后又被其他操作重新写入）
    final dbPath = await downloadService.getDatabasePath();
    await downloadService.closeDatabase();

    if (dbPath != null) {
      final dbFile = File(dbPath);
      if (await dbFile.exists()) {
        await dbFile.delete();
      }
    }

    return '下载文件已清除 ($fileCount 个文件, $recordCount 条记录, ${FormatUtils.formatSize(size)})';
  }

  Future<String> _purgePreferences() async {
    final prefs = PreferencesService();
    await prefs.init();
    final keys = await prefs.getKeys();
    final count = keys.length;
    await prefs.emergencyClear();
    return '偏好设置已清除 ($count 项)';
  }

  Future<String> _purgeSecureStorage() async {
    try {
      const storage = FlutterSecureStorage();
      await storage.deleteAll();
      return '安全存储已清除';
    } catch (e) {
      Logger.warning('安全存储清除失败（可能平台不支持）: $e', 'DataPurge');
      throw Exception('安全存储清除跳过（平台不支持）');
    }
  }

  String _categoryLabel(PurgeCategory category) {
    switch (category) {
      case PurgeCategory.playCache:
        return '播放缓存';
      case PurgeCategory.imageCache:
        return '图片缓存';
      case PurgeCategory.lyricsCache:
        return '歌词缓存';
      case PurgeCategory.dataCache:
        return '数据缓存';
      case PurgeCategory.coverPersistence:
        return '持久化封面';
      case PurgeCategory.downloadedSongs:
        return '下载文件';
      case PurgeCategory.preferences:
        return '偏好设置';
      case PurgeCategory.secureStorage:
        return '安全存储';
    }
  }

}
