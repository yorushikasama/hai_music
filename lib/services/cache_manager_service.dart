import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../utils/format_utils.dart';
import '../utils/logger.dart';
import 'smart_cache_service.dart';
import 'storage_path_manager.dart';

class CacheInfo {
  final int playCacheSize;
  final int imageSize;
  final int downloadSize;
  final int totalSize;
  final DateTime timestamp;

  CacheInfo({
    required this.playCacheSize,
    required this.imageSize,
    required this.downloadSize,
    required this.totalSize,
    required this.timestamp,
  });

  int get total => totalSize;
  int get audioSize => playCacheSize;
  int get coverSize => imageSize;

  Map<String, int> get details => {
    'playCache': playCacheSize,
    'image': imageSize,
    'download': downloadSize,
  };
}

class CacheManagerService {
  static final CacheManagerService _instance = CacheManagerService._internal();

  factory CacheManagerService() => _instance;

  CacheManagerService._internal();

  CacheInfo? _cachedInfo;

  static const int _cacheValiditySeconds = 30;

  final _pathManager = StoragePathManager();

  Future<CacheInfo> getCacheInfo({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedInfo != null) {
      final age = DateTime.now().difference(_cachedInfo!.timestamp).inSeconds;
      if (age < _cacheValiditySeconds) {
        Logger.cache('使用缓存的大小信息 ($age秒前)', 'CacheManager');
        return _cachedInfo!;
      }
    }

    Logger.cache('重新计算缓存大小...', 'CacheManager');
    final smartCache = SmartCacheService();

    final playCacheSize = await smartCache.getPlayCacheSize();
    final imageSize = await _getImageCacheSize();
    final downloadSize = await _getDownloadCacheSize();
    final totalSize = playCacheSize + imageSize + downloadSize;

    _cachedInfo = CacheInfo(
      playCacheSize: playCacheSize,
      imageSize: imageSize,
      downloadSize: downloadSize,
      totalSize: totalSize,
      timestamp: DateTime.now(),
    );

    Logger.cache(
      '缓存统计 - 播放: ${FormatUtils.formatSize(playCacheSize)}, '
      '图片: ${FormatUtils.formatSize(imageSize)}, 下载: ${FormatUtils.formatSize(downloadSize)}, '
      '总计: ${FormatUtils.formatSize(totalSize)}',
      'CacheManager',
    );

    return _cachedInfo!;
  }

  Future<int> _getImageCacheSize() async {
    try {
      final cacheDir = await _pathManager.getImageCacheDir();

      if (!cacheDir.existsSync()) {
        return 0;
      }

      int totalSize = 0;
      await for (final entity in cacheDir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          try {
            totalSize += entity.lengthSync();
          } catch (e) {
            Logger.debug('跳过无法访问的文件: ${entity.path}', 'CacheManager');
          }
        }
      }
      return totalSize;
    } catch (e) {
      Logger.error('获取图片缓存大小失败', e, null, 'CacheManager');
      return 0;
    }
  }

  Future<int> _getDownloadCacheSize() async {
    try {
      final downloadDir = await _pathManager.getDownloadsDir();

      if (!downloadDir.existsSync()) {
        return 0;
      }

      int totalSize = 0;
      await for (final entity in downloadDir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          totalSize += entity.lengthSync();
        }
      }
      return totalSize;
    } catch (e) {
      Logger.error('获取下载文件大小失败', e, null, 'CacheManager');
      return 0;
    }
  }

  Future<bool> clearAllCache() async {
    bool success = true;

    try {
      Logger.info('开始清理所有缓存...', 'CacheManager');
      final smartCache = SmartCacheService();

      try {
        await smartCache.clearPlayCache();
        Logger.success('播放缓存已清理', 'CacheManager');
      } catch (e) {
        Logger.error('清理播放缓存失败', e, null, 'CacheManager');
        success = false;
      }

      try {
        final cacheManager = DefaultCacheManager();
        await cacheManager.emptyCache();

        final cacheDir = await _pathManager.getImageCacheDir();
        if (cacheDir.existsSync()) {
          cacheDir.deleteSync(recursive: true);
        }

        Logger.success('图片缓存已清理', 'CacheManager');
      } catch (e) {
        Logger.error('清理图片缓存失败', e, null, 'CacheManager');
        success = false;
      }

      _invalidateCache();

      Logger.success('所有缓存清理完成', 'CacheManager');
      return success;
    } catch (e) {
      Logger.error('清理缓存失败', e, null, 'CacheManager');
      return false;
    }
  }

  void _invalidateCache() {
    _cachedInfo = null;
    Logger.cache('缓存信息已失效', 'CacheManager');
  }
}
