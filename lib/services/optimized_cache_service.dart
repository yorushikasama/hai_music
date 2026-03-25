import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/song.dart';
import '../utils/logger.dart';
import '../config/app_constants.dart';
import 'dio_client.dart';

/// 缓存操作消息
class CacheOperationMessage {
  final String operation;
  final String songId;
  final String? filePath;
  final String? audioUrl;
  final SendPort sendPort;

  CacheOperationMessage({
    required this.operation,
    required this.songId,
    required this.sendPort,
    this.filePath,
    this.audioUrl,
  });
}

/// 优化的缓存服务
/// 使用Isolate进行异步缓存操作，避免UI阻塞
class OptimizedCacheService {
  static final OptimizedCacheService _instance = OptimizedCacheService._internal();
  factory OptimizedCacheService() => _instance;
  OptimizedCacheService._internal();

  final DioClient _dioClient = DioClient();

  // 缓存配置
  static const int maxPlayCacheCount = 50;
  static const int maxPlayCacheSize = 500 * 1024 * 1024;
  static const int cacheExpiryDays = 7;
  static const String playCacheKey = 'optimized_play_cache_list';



  /// 播放歌曲时自动缓存（异步）
  Future<void> cacheOnPlayAsync(Song song, {int? audioQuality}) async {
    try {
      // 检查是否已缓存
      final cacheFile = await _getPlayCacheFile(song.id);
      if (await cacheFile.exists()) {
        await _updateAccessTimeAsync(song.id);
        return;
      }

      // 异步执行缓存操作
      await _executeCacheOperation('cache', song, audioQuality: audioQuality);

    } catch (e, stackTrace) {
      Logger.error('🎵 [缓存] 异步缓存歌曲失败: ${song.title}', e, stackTrace, 'OptimizedCache');
    }
  }

  /// 执行缓存操作
  Future<void> _executeCacheOperation(String operation, Song song, {int? audioQuality}) async {
    final receivePort = ReceivePort();
    
    try {
      // 准备缓存数据
      String? audioUrl = song.audioUrl;
      if (audioUrl == null || audioUrl.isEmpty) {
        Logger.warning('🎵 [缓存] 音频URL为空，无法缓存: ${song.title}', 'OptimizedCache');
        return;
      }

      final cacheFile = await _getPlayCacheFile(song.id);

      // 在Isolate中执行下载
      await Isolate.spawn(
        _downloadInIsolate,
        CacheOperationMessage(
          operation: operation,
          songId: song.id,
          filePath: cacheFile.path,
          audioUrl: audioUrl,
          sendPort: receivePort.sendPort,
        ),
      );

      // 等待操作完成
      final result = await receivePort.first;
      
      if (result == 'success') {
        await _addToCacheListAsync(song);
        Logger.info('🎵 [缓存] 音频文件缓存成功: ${song.title}', 'OptimizedCache');
      } else {
        Logger.error('🎵 [缓存] 音频文件下载失败: $result', null, null, 'OptimizedCache');
      }

    } catch (e, stackTrace) {
      Logger.error('🎵 [缓存] 缓存操作失败: ${song.title}', e, stackTrace, 'OptimizedCache');
    } finally {
      receivePort.close();
    }
  }

  /// 在Isolate中执行下载
  static void _downloadInIsolate(CacheOperationMessage message) async {
    try {
      if (message.audioUrl == null || message.filePath == null) {
        message.sendPort.send('error: missing url or path');
        return;
      }

      final dio = DioClient().dio;
      await dio.download(message.audioUrl!, message.filePath!);
      
      message.sendPort.send('success');
    } catch (e) {
      message.sendPort.send('error: $e');
    }
  }

  /// 获取缓存的歌曲文件路径
  Future<String?> getCachedAudioPath(String songId) async {
    try {
      final playFile = await _getPlayCacheFile(songId);
      if (await playFile.exists()) {
        // 检查缓存是否过期
        if (await _isCacheExpiredAsync(songId)) {
          Logger.info('🎵 [缓存] 缓存已过期，删除: $songId', 'OptimizedCache');
          await _removeCacheItemAsync(songId);
          return null;
        }
        await _updateAccessTimeAsync(songId);
        return playFile.path;
      }

      return null;
    } catch (e) {
      Logger.error('获取缓存路径失败', e, null, 'OptimizedCache');
      return null;
    }
  }

  /// 获取播放缓存文件
  Future<File> _getPlayCacheFile(String songId) async {
    final dir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory(path.join(dir.path, 'music', 'optimized_play_cache'));
    await cacheDir.create(recursive: true);
    return File(path.join(cacheDir.path, '$songId.mp3'));
  }

  /// 异步更新访问时间
  Future<void> _updateAccessTimeAsync(String songId) async {
    try {
      final cacheList = await _getCacheListAsync();
      
      for (final item in cacheList) {
        if (item['songId'] == songId) {
          item['lastAccess'] = DateTime.now().millisecondsSinceEpoch;
          break;
        }
      }
      
      await _saveCacheListAsync(cacheList);
    } catch (e) {
      Logger.error('更新访问时间失败: $songId', e, null, 'OptimizedCache');
    }
  }

  /// 异步添加到缓存列表
  Future<void> _addToCacheListAsync(Song song) async {
    try {
      final cacheList = await _getCacheListAsync();
      
      // 移除已存在的记录
      cacheList.removeWhere((item) => item['songId'] == song.id);
      
      // 添加新记录
      cacheList.add({
        'songId': song.id,
        'title': song.title,
        'artist': song.artist,
        'lastAccess': DateTime.now().millisecondsSinceEpoch,
        'cacheTime': DateTime.now().millisecondsSinceEpoch,
      });
      
      await _saveCacheListAsync(cacheList);
      
      // 触发缓存空间检查
      await _ensureCacheSpaceAsync();
      
    } catch (e) {
      Logger.error('添加到缓存列表失败: ${song.id}', e, null, 'OptimizedCache');
    }
  }

  /// 异步获取缓存列表
  Future<List<Map<String, dynamic>>> _getCacheListAsync() async {
    try {
      // 这里应该使用SharedPreferences或其他持久化存储
      // 简化实现，实际项目中应该使用更健壮的存储方案
      return [];
    } catch (e) {
      return [];
    }
  }

  /// 异步保存缓存列表
  Future<void> _saveCacheListAsync(List<Map<String, dynamic>> list) async {
    try {
      // 这里应该使用SharedPreferences或其他持久化存储
      // 简化实现，实际项目中应该使用更健壮的存储方案
    } catch (e) {
      Logger.error('保存缓存列表失败', e, null, 'OptimizedCache');
    }
  }

  /// 异步检查缓存是否过期
  Future<bool> _isCacheExpiredAsync(String songId) async {
    try {
      final cacheList = await _getCacheListAsync();
      final item = cacheList.firstWhere(
        (item) => item['songId'] == songId,
        orElse: () => {},
      );
      
      if (item.isEmpty) return true;
      
      final cacheTime = item['cacheTime'] as int;
      final now = DateTime.now().millisecondsSinceEpoch;
      final expiryTime = cacheExpiryDays * 24 * 60 * 60 * 1000;
      
      return now - cacheTime > expiryTime;
    } catch (e) {
      return true;
    }
  }

  /// 异步移除缓存项
  Future<void> _removeCacheItemAsync(String songId) async {
    try {
      final file = await _getPlayCacheFile(songId);
      if (await file.exists()) {
        await file.delete();
      }
      
      final cacheList = await _getCacheListAsync();
      cacheList.removeWhere((item) => item['songId'] == songId);
      await _saveCacheListAsync(cacheList);
    } catch (e) {
      Logger.error('移除缓存项失败: $songId', e, null, 'OptimizedCache');
    }
  }

  /// 异步确保缓存空间足够
  Future<void> _ensureCacheSpaceAsync() async {
    try {
      // 先清理过期缓存
      await _cleanExpiredCacheAsync();
      
      final cacheList = await _getCacheListAsync();
      
      // 检查数量限制
      if (cacheList.length >= maxPlayCacheCount) {
        await _cleanOldCacheAsync(cacheList.length - maxPlayCacheCount + 1);
      }

      // 检查大小限制
      final cacheSize = await _getPlayCacheSizeAsync();
      if (cacheSize > maxPlayCacheSize) {
        await _cleanOldCacheAsync(5);
      }
    } catch (e) {
      Logger.error('确保缓存空间失败', e, null, 'OptimizedCache');
    }
  }

  /// 异步清理过期缓存
  Future<void> _cleanExpiredCacheAsync() async {
    try {
      final cacheList = await _getCacheListAsync();
      final now = DateTime.now().millisecondsSinceEpoch;
      final expiryTime = cacheExpiryDays * 24 * 60 * 60 * 1000;
      
      final expiredItems = cacheList.where((item) {
        final cacheTime = item['cacheTime'] as int;
        return now - cacheTime > expiryTime;
      }).toList();
      
      for (final item in expiredItems) {
        final songId = item['songId'];
        await _removeCacheItemAsync(songId);
      }
    } catch (e) {
      Logger.error('清理过期缓存失败', e, null, 'OptimizedCache');
    }
  }

  /// 异步清理旧缓存
  Future<void> _cleanOldCacheAsync(int count) async {
    try {
      final cacheList = await _getCacheListAsync();
      
      // 按访问时间排序，最旧的在前面
      cacheList.sort((a, b) => a['lastAccess'].compareTo(b['lastAccess']));
      
      for (int i = 0; i < count && i < cacheList.length; i++) {
        final item = cacheList[i];
        final songId = item['songId'];
        await _removeCacheItemAsync(songId);
      }
    } catch (e) {
      Logger.error('清理旧缓存失败', e, null, 'OptimizedCache');
    }
  }

  /// 异步获取播放缓存大小
  Future<int> _getPlayCacheSizeAsync() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory(path.join(dir.path, 'music', 'optimized_play_cache'));
      
      if (!await cacheDir.exists()) {
        return 0;
      }

      int totalSize = 0;
      await for (var entity in cacheDir.list()) {
        if (entity is File) {
          final fileSize = await entity.length();
          totalSize += fileSize;
        }
      }
      
      return totalSize;
    } catch (e) {
      Logger.error('获取缓存大小失败', e, null, 'OptimizedCache');
      return 0;
    }
  }

  /// 获取缓存统计信息
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final playSize = await _getPlayCacheSizeAsync();
      final cacheList = await _getCacheListAsync();
      final now = DateTime.now().millisecondsSinceEpoch;
      final expiryTime = cacheExpiryDays * 24 * 60 * 60 * 1000;
      
      // 统计过期缓存数量
      final expiredCount = cacheList.where((item) {
        final cacheTime = item['cacheTime'] as int;
        return now - cacheTime > expiryTime;
      }).length;
      
      return {
        'playCache': {
          'size': playSize,
          'count': cacheList.length,
          'expiredCount': expiredCount,
          'maxCount': maxPlayCacheCount,
          'maxSize': maxPlayCacheSize,
          'expiryDays': cacheExpiryDays,
        },
      };
    } catch (e) {
      Logger.error('获取缓存统计失败', e, null, 'OptimizedCache');
      return {
        'playCache': {
          'size': 0,
          'count': 0,
          'expiredCount': 0,
          'maxCount': maxPlayCacheCount,
          'maxSize': maxPlayCacheSize,
          'expiryDays': cacheExpiryDays,
        },
      };
    }
  }

  /// 清理播放缓存
  Future<bool> clearPlayCache() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory(path.join(dir.path, 'music', 'optimized_play_cache'));
      
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }

      Logger.success('播放缓存清理完成', 'OptimizedCache');
      return true;
    } catch (e) {
      Logger.error('清理播放缓存失败', e, null, 'OptimizedCache');
      return false;
    }
  }

  /// 优化缓存（清理过期和不必要的缓存）
  Future<void> optimizeCache() async {
    try {
      Logger.info('开始优化缓存...', 'OptimizedCache');
      
      // 清理过期缓存
      await _cleanExpiredCacheAsync();
      
      // 确保缓存空间
      await _ensureCacheSpaceAsync();
      
      final stats = await getCacheStats();
      Logger.success('缓存优化完成', 'OptimizedCache');
      Logger.info('缓存统计: ${stats['playCache']}', 'OptimizedCache');
    } catch (e) {
      Logger.error('缓存优化失败', e, null, 'OptimizedCache');
    }
  }
}
