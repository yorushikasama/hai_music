import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// 缓存管理服务
class CacheManagerService {
  /// 获取缓存大小
  Future<int> getCacheSize() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final musicDir = Directory('${dir.path}/music');
      
      if (!await musicDir.exists()) {
        return 0;
      }
      
      int totalSize = 0;
      await for (var entity in musicDir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
      
      return totalSize;
    } catch (e) {
      print('获取缓存大小失败: $e');
      return 0;
    }
  }

  /// 清理所有缓存
  Future<bool> clearAllCache() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final musicDir = Directory('${dir.path}/music');
      
      if (await musicDir.exists()) {
        await musicDir.delete(recursive: true);
        print('✅ 缓存清理完成');
        return true;
      }
      
      return true;
    } catch (e) {
      print('❌ 清理缓存失败: $e');
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
        print('✅ 音频缓存清理完成');
        return true;
      }
      
      return true;
    } catch (e) {
      print('❌ 清理音频缓存失败: $e');
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
        print('✅ 封面缓存清理完成');
        return true;
      }
      
      return true;
    } catch (e) {
      print('❌ 清理封面缓存失败: $e');
      return false;
    }
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
