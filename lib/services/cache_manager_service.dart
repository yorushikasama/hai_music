import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../utils/logger.dart';

/// 缓存信息模型
class CacheInfo {
  final int audioSize;
  final int coverSize;
  final int totalSize;
  final DateTime timestamp;

  CacheInfo({
    required this.audioSize,
    required this.coverSize,
    required this.totalSize,
    required this.timestamp,
  });

  int get total => totalSize;
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

    // 重新计算
    Logger.cache('重新计算缓存大小...', 'CacheManager');
    final audioSize = await getAudioCacheSize();
    final coverSize = await getCoverCacheSize();
    final totalSize = audioSize + coverSize;

    _cachedInfo = CacheInfo(
      audioSize: audioSize,
      coverSize: coverSize,
      totalSize: totalSize,
      timestamp: DateTime.now(),
    );

    return _cachedInfo!;
  }

  /// 获取总缓存大小 (兼容旧接口)
  Future<int> getCacheSize() async {
    final info = await getCacheInfo();
    return info.totalSize;
  }

  /// 获取音频缓存大小
  Future<int> getAudioCacheSize() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${dir.path}/music/audio');

      if (!await audioDir.exists()) {
        return 0;
      }

      return await _calculateDirectorySize(audioDir);
    } catch (e) {
      Logger.error('获取音频缓存大小失败', e, null, 'CacheManager');
      return 0;
    }
  }

  /// 获取封面缓存大小
  Future<int> getCoverCacheSize() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final coverDir = Directory('${dir.path}/music/covers');

      if (!await coverDir.exists()) {
        return 0;
      }

      return await _calculateDirectorySize(coverDir);
    } catch (e) {
      Logger.error('获取封面缓存大小失败', e, null, 'CacheManager');
      return 0;
    }
  }

  /// 计算目录大小
  Future<int> _calculateDirectorySize(Directory dir) async {
    int totalSize = 0;
    await for (var entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        totalSize += await entity.length();
      }
    }
    return totalSize;
  }

  /// 清理所有缓存
  Future<bool> clearAllCache() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final musicDir = Directory('${dir.path}/music');

      if (await musicDir.exists()) {
        await musicDir.delete(recursive: true);
        Logger.success('缓存清理完成', 'CacheManager');

        // 清除缓存信息
        _invalidateCache();

        return true;
      }

      return true;
    } catch (e) {
      Logger.error('清理缓存失败', e, null, 'CacheManager');
      return false;
    }
  }

  /// 清理音频缓存
  Future<bool> clearAudioCache() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${dir.path}/music/audio');

      if (await audioDir.exists()) {
        await audioDir.delete(recursive: true);
        Logger.success('音频缓存清理完成', 'CacheManager');

        // 清除缓存信息
        _invalidateCache();

        return true;
      }

      return true;
    } catch (e) {
      Logger.error('清理音频缓存失败', e, null, 'CacheManager');
      return false;
    }
  }

  /// 清理封面缓存
  Future<bool> clearCoverCache() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final coverDir = Directory('${dir.path}/music/covers');

      if (await coverDir.exists()) {
        await coverDir.delete(recursive: true);
        Logger.success('封面缓存清理完成', 'CacheManager');

        // 清除缓存信息
        _invalidateCache();

        return true;
      }

      return true;
    } catch (e) {
      Logger.error('清理封面缓存失败', e, null, 'CacheManager');
      return false;
    }
  }

  /// 使缓存信息失效
  void _invalidateCache() {
    _cachedInfo = null;
    Logger.cache('缓存信息已失效', 'CacheManager');
  }

  /// 格式化文件大小
  String formatSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }
}
