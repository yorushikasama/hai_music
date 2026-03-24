import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../utils/logger.dart';
import '../utils/format_utils.dart';
import 'smart_cache_service.dart';

/// 缓存信息模型
class CacheInfo {
  final int playCacheSize;      // 播放缓存
  final int imageSize;          // 图片缓存
  final int downloadSize;       // 下载文件
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
  
  // 兼容性属性
  int get audioSize => playCacheSize;
  int get coverSize => imageSize;
  
  /// 获取详细信息
  Map<String, int> get details => {
    'playCache': playCacheSize,
    'image': imageSize,
    'download': downloadSize,
  };
}

/// 缓存管理服务 (单例模式)
class CacheManagerService {
  static final CacheManagerService _instance = CacheManagerService._internal();

  factory CacheManagerService() => _instance;

  CacheManagerService._internal();

  // 缓存大小信息
  CacheInfo? _cachedInfo;

  // 缓存有效期 (秒)
  static const int _cacheValiditySeconds = 30;

  /// 获取缓存信息 (带缓存机制)
  ///
  /// [forceRefresh] 是否强制刷新,默认 false
  Future<CacheInfo> getCacheInfo({bool forceRefresh = false}) async {
    // 检查缓存是否有效
    if (!forceRefresh && _cachedInfo != null) {
      final age = DateTime.now().difference(_cachedInfo!.timestamp).inSeconds;
      if (age < _cacheValiditySeconds) {
        Logger.cache('使用缓存的大小信息 ($age秒前)', 'CacheManager');
        return _cachedInfo!;
      }
    }

    // 重新计算所有缓存
    Logger.cache('重新计算缓存大小...', 'CacheManager');
    final smartCache = SmartCacheService();
    
    Logger.debug('🎵 [缓存管理器] 开始计算各类缓存大小...', 'CacheManager');
    
    final playCacheSize = await smartCache.getPlayCacheSize();
    Logger.debug('🎵 [缓存管理器] 播放缓存大小: ${FormatUtils.formatSize(playCacheSize)}', 'CacheManager');

    final imageSize = await getImageCacheSize();
    Logger.debug('🎵 [缓存管理器] 图片缓存大小: ${FormatUtils.formatSize(imageSize)}', 'CacheManager');

    final downloadSize = await getDownloadCacheSize();
    Logger.debug('🎵 [缓存管理器] 下载文件大小: ${FormatUtils.formatSize(downloadSize)}', 'CacheManager');
    
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

  /// 获取总缓存大小 (兼容旧接口)
  Future<int> getCacheSize() async {
    final info = await getCacheInfo();
    return info.totalSize;
  }

  /// 获取图片缓存大小 (CachedNetworkImage 使用的缓存)
  Future<int> getImageCacheSize() async {
    try {
      // CachedNetworkImage 使用 flutter_cache_manager
      // 缓存在临时目录下的 libCachedImageData 文件夹
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory(path.join(tempDir.path, 'libCachedImageData'));
      
      if (!await cacheDir.exists()) {
        return 0;
      }

      int totalSize = 0;
      await for (var entity in cacheDir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          try {
            totalSize += await entity.length();
          } catch (e) {
            // 忽略无法访问的文件
          }
        }
      }
      return totalSize;
    } catch (e) {
      Logger.error('获取图片缓存大小失败', e, null, 'CacheManager');
      return 0;
    }
  }

  /// 获取下载文件大小
  Future<int> getDownloadCacheSize() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final downloadDir = Directory(path.join(dir.path, 'HaiMusic', 'Downloads'));

      if (!await downloadDir.exists()) {
        return 0;
      }

      int totalSize = 0;
      await for (var entity in downloadDir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
      return totalSize;
    } catch (e) {
      Logger.error('获取下载文件大小失败', e, null, 'CacheManager');
      return 0;
    }
  }

  /// 清理所有缓存
  Future<bool> clearAllCache() async {
    bool success = true;
    
    try {
      Logger.info('开始清理所有缓存...', 'CacheManager');
      final smartCache = SmartCacheService();
      
      // 1. 清理播放缓存
      try {
        await smartCache.clearPlayCache();
        Logger.success('播放缓存已清理', 'CacheManager');
      } catch (e) {
        Logger.error('清理播放缓存失败', e, null, 'CacheManager');
        success = false;
      }

      // 2. 清理图片缓存 (CachedNetworkImage)
      try {
        final cacheManager = DefaultCacheManager();
        await cacheManager.emptyCache();
        
        // 直接删除缓存目录（更彻底）
        final tempDir = await getTemporaryDirectory();
        final cacheDir = Directory(path.join(tempDir.path, 'libCachedImageData'));
        if (await cacheDir.exists()) {
          await cacheDir.delete(recursive: true);
        }
        
        Logger.success('图片缓存已清理', 'CacheManager');
      } catch (e) {
        Logger.error('清理图片缓存失败', e, null, 'CacheManager');
        success = false;
      }

      // 3. 不清理下载文件（保护用户数据）

      // 清除缓存信息
      _invalidateCache();

      Logger.success('所有缓存清理完成', 'CacheManager');
      return success;
    } catch (e) {
      Logger.error('清理缓存失败', e, null, 'CacheManager');
      return false;
    }
  }

  /// 清理播放缓存
  Future<bool> clearPlayCache() async {
    try {
      await SmartCacheService().clearPlayCache();
      _invalidateCache();
      return true;
    } catch (e) {
      Logger.error('清理播放缓存失败', e, null, 'CacheManager');
      return false;
    }
  }

  /// 清理图片缓存 (CachedNetworkImage)
  Future<bool> clearImageCache() async {
    try {
      // 方法1：使用 DefaultCacheManager 清理
      final cacheManager = DefaultCacheManager();
      await cacheManager.emptyCache();
      
      // 方法2：直接删除缓存目录（更彻底）
      try {
        final tempDir = await getTemporaryDirectory();
        final cacheDir = Directory(path.join(tempDir.path, 'libCachedImageData'));
        if (await cacheDir.exists()) {
          await cacheDir.delete(recursive: true);
        }
      } catch (e) {
        Logger.warning('删除缓存目录失败: $e', 'CacheManager');
      }
      
      Logger.success('图片缓存清理完成', 'CacheManager');

      // 清除缓存信息
      _invalidateCache();

      return true;
    } catch (e) {
      Logger.error('清理图片缓存失败', e, null, 'CacheManager');
      return false;
    }
  }

  /// 清理下载文件
  Future<bool> clearDownloadCache() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final downloadDir = Directory(path.join(dir.path, 'HaiMusic', 'Downloads'));

      if (await downloadDir.exists()) {
        await downloadDir.delete(recursive: true);
        Logger.success('下载文件清理完成', 'CacheManager');

        // 清除缓存信息
        _invalidateCache();

        return true;
      }

      return true;
    } catch (e) {
      Logger.error('清理下载文件失败', e, null, 'CacheManager');
      return false;
    }
  }

  /// 使缓存信息失效
  void _invalidateCache() {
    _cachedInfo = null;
    Logger.cache('缓存信息已失效', 'CacheManager');
  }
}
