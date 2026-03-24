import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/song.dart';
import '../utils/logger.dart';
import '../utils/format_utils.dart';
import '../config/app_constants.dart';
import 'music_api_service.dart';
import 'dio_client.dart';
import 'preferences_cache_service.dart';

/// 智能缓存服务
/// 自动缓存最近播放的歌曲，支持 LRU 清理策略和缓存过期管理
class SmartCacheService {
  static final SmartCacheService _instance = SmartCacheService._internal();
  factory SmartCacheService() => _instance;
  SmartCacheService._internal();

  final DioClient _dioClient = DioClient();
  final MusicApiService _apiService = MusicApiService();
  final PreferencesCacheService _prefsCache = PreferencesCacheService();

  // 缓存配置
  static const int maxPlayCacheCount = 50; // 最多缓存 50 首歌
  static const int maxPlayCacheSize = 500 * 1024 * 1024; // 最大 500MB
  static const int cacheExpiryDays = 7; // 缓存过期时间（天）
  static const String playCacheKey = 'play_cache_list';

  /// 播放歌曲时自动缓存
  Future<void> cacheOnPlay(Song song, {int? audioQuality}) async {
    try {
      // 1. 检查是否已缓存
      final cacheFile = await _getPlayCacheFile(song.id);
      if (await cacheFile.exists()) {
        await _updateAccessTime(song.id);
        return;
      }

      // 2. 检查缓存空间
      await _ensureCacheSpace();

      // 3. 下载并缓存
      await _downloadToPlayCache(song, audioQuality: audioQuality);

      // 4. 验证下载结果
      if (await cacheFile.exists()) {
        final fileSize = await cacheFile.length();
        Logger.info('🎵 [缓存] 音频文件缓存成功: ${song.title} (${FormatUtils.formatSize(fileSize)})', 'SmartCache');
      } else {
        Logger.error('🎵 [缓存] 音频文件下载失败: 文件不存在', null, null, 'SmartCache');
        return;
      }

      // 5. 更新缓存列表
      await _addToCacheList(song);

      } catch (e, stackTrace) {
      Logger.error('🎵 [缓存] 缓存歌曲失败: ${song.title}', e, stackTrace, 'SmartCache');
    }
  }

  /// 获取缓存的歌曲文件路径
  Future<String?> getCachedAudioPath(String songId) async {
    try {
      final playFile = await _getPlayCacheFile(songId);
      if (await playFile.exists()) {
        // 检查缓存是否过期
        if (await _isCacheExpired(songId)) {
          Logger.info('🎵 [缓存] 缓存已过期，删除: $songId', 'SmartCache');
          await _removeCacheItem(songId);
          return null;
        }
        await _updateAccessTime(songId);
        return playFile.path;
      }

      return null;
    } catch (e) {
      Logger.error('获取缓存路径失败', e, null, 'SmartCache');
      return null;
    }
  }

  /// 获取播放缓存文件
  Future<File> _getPlayCacheFile(String songId) async {
    final dir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory(path.join(dir.path, 'music', 'play_cache'));
    await cacheDir.create(recursive: true);
    return File(path.join(cacheDir.path, '$songId.mp3'));
  }

  /// 下载到播放缓存
  Future<void> _downloadToPlayCache(Song song, {int? audioQuality}) async {
    final file = await _getPlayCacheFile(song.id);
    await _downloadAudio(song, file.path, audioQuality: audioQuality);
  }

  /// 下载音频文件
  Future<void> _downloadAudio(Song song, String filePath, {int? audioQuality}) async {
    String? audioUrl = song.audioUrl;
    if (audioUrl.isEmpty) {
      final quality = audioQuality ?? AppConstants.qualityHigh;
      audioUrl = await _apiService.getSongUrl(songId: song.id, quality: quality);
      }

    if (audioUrl == null || audioUrl.isEmpty) {
      throw Exception('无法获取音频URL - songId: ${song.id}');
    }

    try {
      await _dioClient.dio.download(audioUrl, filePath);
    } catch (e) {
      Logger.error('🎵 [下载] 下载失败: ${song.title}', e, null, 'SmartCache');
      rethrow;
    }
  }

  /// 确保缓存空间足够
  Future<void> _ensureCacheSpace() async {
    // 先清理过期缓存
    await _cleanExpiredCache();
    
    final cacheList = await _getCacheList();
    
    // 检查数量限制
    if (cacheList.length >= maxPlayCacheCount) {
      await _cleanOldCache(cacheList.length - maxPlayCacheCount + 1);
    }

    // 检查大小限制
    final cacheSize = await _getPlayCacheSize();
    if (cacheSize > maxPlayCacheSize) {
      await _cleanOldCache(5); // 清理 5 个最旧的
    }
  }

  /// 清理过期缓存
  Future<void> _cleanExpiredCache() async {
    final cacheList = await _getCacheList();
    final now = DateTime.now().millisecondsSinceEpoch;
    final expiryTime = cacheExpiryDays * 24 * 60 * 60 * 1000;
    
    final expiredItems = cacheList.where((item) {
      final cacheTime = item['cacheTime'] as int;
      return now - cacheTime > expiryTime;
    }).toList();
    
    for (final item in expiredItems) {
      final songId = item['songId'];
      try {
        final file = await _getPlayCacheFile(songId);
        if (await file.exists()) {
          await file.delete();
          Logger.info('清理过期缓存: $songId', 'SmartCache');
        }
      } catch (e) {
        Logger.warning('清理过期缓存失败: $songId', 'SmartCache');
      }
    }
    
    // 移除过期记录
    cacheList.removeWhere((item) {
      final cacheTime = item['cacheTime'] as int;
      return now - cacheTime > expiryTime;
    });
    
    await _saveCacheList(cacheList);
  }

  /// 检查缓存是否过期
  Future<bool> _isCacheExpired(String songId) async {
    final cacheList = await _getCacheList();
    final item = cacheList.firstWhere((item) => item['songId'] == songId, orElse: () => {});
    
    if (item.isEmpty) return true;
    
    final cacheTime = item['cacheTime'] as int;
    final now = DateTime.now().millisecondsSinceEpoch;
    final expiryTime = cacheExpiryDays * 24 * 60 * 60 * 1000;
    
    return now - cacheTime > expiryTime;
  }

  /// 清理旧缓存
  Future<void> _cleanOldCache(int count) async {
    final cacheList = await _getCacheList();
    
    // 按访问时间排序，最旧的在前面
    cacheList.sort((a, b) => a['lastAccess'].compareTo(b['lastAccess']));
    
    for (int i = 0; i < count && i < cacheList.length; i++) {
      final item = cacheList[i];
      final songId = item['songId'];
      
      try {
        final file = await _getPlayCacheFile(songId);
        if (await file.exists()) {
          await file.delete();
          Logger.info('清理旧缓存: $songId', 'SmartCache');
        }
      } catch (e) {
        Logger.warning('清理缓存失败: $songId', 'SmartCache');
      }
    }

    // 更新缓存列表
    cacheList.removeRange(0, count);
    await _saveCacheList(cacheList);
  }

  /// 移除单个缓存项
  Future<void> _removeCacheItem(String songId) async {
    try {
      final file = await _getPlayCacheFile(songId);
      if (await file.exists()) {
        await file.delete();
      }
      
      final cacheList = await _getCacheList();
      cacheList.removeWhere((item) => item['songId'] == songId);
      await _saveCacheList(cacheList);
    } catch (e) {
      Logger.error('移除缓存项失败: $songId', e, null, 'SmartCache');
    }
  }

  /// 获取缓存列表
  Future<List<Map<String, dynamic>>> _getCacheList() async {
    try {
      final jsonStr = await _prefsCache.getString(playCacheKey);
      if (jsonStr == null || jsonStr.isEmpty) return [];

      final List<dynamic> list = jsonDecode(jsonStr);
      return list.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  /// 保存缓存列表
  Future<void> _saveCacheList(List<Map<String, dynamic>> list) async {
    final jsonStr = jsonEncode(list);
    await _prefsCache.setString(playCacheKey, jsonStr);
  }

  /// 添加到缓存列表
  Future<void> _addToCacheList(Song song) async {
    final cacheList = await _getCacheList();
    
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
    
    await _saveCacheList(cacheList);
  }

  /// 更新访问时间
  Future<void> _updateAccessTime(String songId) async {
    final cacheList = await _getCacheList();
    
    for (final item in cacheList) {
      if (item['songId'] == songId) {
        item['lastAccess'] = DateTime.now().millisecondsSinceEpoch;
        break;
      }
    }
    
    await _saveCacheList(cacheList);
  }

  /// 获取播放缓存大小（公开方法）
  Future<int> getPlayCacheSize() async {
    return await _getPlayCacheSize();
  }

  /// 获取播放缓存大小（私有方法）
  Future<int> _getPlayCacheSize() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory(path.join(dir.path, 'music', 'play_cache'));
      
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
      Logger.error('🎵 [统计] 获取缓存大小失败', e, null, 'SmartCache');
      return 0;
    }
  }

  /// 清理播放缓存
  Future<bool> clearPlayCache() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory(path.join(dir.path, 'music', 'play_cache'));
      
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }

      await _prefsCache.remove(playCacheKey);
      Logger.success('播放缓存清理完成', 'SmartCache');
      return true;
    } catch (e) {
      Logger.error('清理播放缓存失败', e, null, 'SmartCache');
      return false;
    }
  }

  /// 清理指定歌曲的缓存
  Future<bool> clearSongCache(String songId) async {
    try {
      await _removeCacheItem(songId);
      Logger.success('清理歌曲缓存完成: $songId', 'SmartCache');
      return true;
    } catch (e) {
      Logger.error('清理歌曲缓存失败: $songId', e, null, 'SmartCache');
      return false;
    }
  }

  /// 获取缓存统计信息
  Future<Map<String, dynamic>> getCacheStats() async {
    final playSize = await _getPlayCacheSize();
    final cacheList = await _getCacheList();
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
  }

  /// 优化缓存（清理过期和不必要的缓存）
  Future<void> optimizeCache() async {
    try {
      Logger.info('开始优化缓存...', 'SmartCache');
      
      // 清理过期缓存
      await _cleanExpiredCache();
      
      // 确保缓存空间
      await _ensureCacheSpace();
      
      final stats = await getCacheStats();
      Logger.success('缓存优化完成', 'SmartCache');
      Logger.info('缓存统计: ${stats['playCache']}', 'SmartCache');
    } catch (e) {
      Logger.error('缓存优化失败', e, null, 'SmartCache');
    }
  }
}
