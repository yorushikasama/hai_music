import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song.dart';
import '../utils/logger.dart';
import '../config/app_constants.dart';
import 'music_api_service.dart';

/// 智能缓存服务
/// 自动缓存最近播放的歌曲，支持 LRU 清理策略
class SmartCacheService {
  static final SmartCacheService _instance = SmartCacheService._internal();
  factory SmartCacheService() => _instance;
  SmartCacheService._internal();

  final Dio _dio = Dio();
  final MusicApiService _apiService = MusicApiService();
  SharedPreferences? _prefs;

  // 缓存配置
  static const int maxPlayCacheCount = 50; // 最多缓存 50 首歌
  static const int maxPlayCacheSize = 500 * 1024 * 1024; // 最大 500MB
  static const String playCacheKey = 'play_cache_list';

  /// 播放歌曲时自动缓存
  Future<void> cacheOnPlay(Song song, {int? audioQuality}) async {
    try {
      Logger.info('🎵 [缓存] 开始缓存播放歌曲: ${song.title} (ID: ${song.id})', 'SmartCache');
      Logger.debug('🎵 [缓存] 歌曲信息 - 标题: ${song.title}, 艺术家: ${song.artist}, audioUrl: ${song.audioUrl.isNotEmpty ? "有" : "无"}', 'SmartCache');
      
      // 1. 检查是否已缓存
      final cacheFile = await _getPlayCacheFile(song.id);
      Logger.debug('🎵 [缓存] 缓存文件路径: ${cacheFile.path}', 'SmartCache');
      
      if (await cacheFile.exists()) {
        final fileSize = await cacheFile.length();
        Logger.info('🎵 [缓存] 歌曲已缓存 (${formatSize(fileSize)})，更新访问时间', 'SmartCache');
        await _updateAccessTime(song.id);
        return;
      }

      Logger.info('🎵 [缓存] 歌曲未缓存，开始下载...', 'SmartCache');

      // 2. 检查缓存空间
      Logger.debug('🎵 [缓存] 检查缓存空间...', 'SmartCache');
      await _ensureCacheSpace();

      // 3. 下载并缓存
      Logger.info('🎵 [缓存] 开始下载音频文件...', 'SmartCache');
      await _downloadToPlayCache(song, audioQuality: audioQuality);

      // 4. 验证下载结果
      if (await cacheFile.exists()) {
        final fileSize = await cacheFile.length();
        Logger.success('🎵 [缓存] 音频文件下载成功: ${formatSize(fileSize)}', 'SmartCache');
      } else {
        Logger.error('🎵 [缓存] 音频文件下载失败: 文件不存在', null, null, 'SmartCache');
        return;
      }

      // 5. 更新缓存列表
      Logger.debug('🎵 [缓存] 更新缓存列表...', 'SmartCache');
      await _addToCacheList(song);

      Logger.success('🎵 [缓存] 歌曲缓存完成: ${song.title}', 'SmartCache');
    } catch (e, stackTrace) {
      Logger.error('🎵 [缓存] 缓存歌曲失败: ${song.title}', e, stackTrace, 'SmartCache');
    }
  }

  /// 获取缓存的歌曲文件路径
  Future<String?> getCachedAudioPath(String songId) async {
    try {
      final playFile = await _getPlayCacheFile(songId);
      if (await playFile.exists()) {
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
    Logger.debug('🎵 [下载] 检查音频URL - 原始URL: ${audioUrl.isNotEmpty ? "有(${audioUrl.length}字符)" : "无"}', 'SmartCache');
    
    if (audioUrl.isEmpty) {
      final quality = audioQuality ?? AppConstants.qualityHigh;
      Logger.info('🎵 [下载] 获取音频URL - 歌曲ID: ${song.id}, 音质: $quality', 'SmartCache');
      audioUrl = await _apiService.getSongUrl(songId: song.id, quality: quality);
      Logger.debug('🎵 [下载] API返回URL: ${audioUrl?.isNotEmpty == true ? "有(${audioUrl!.length}字符)" : "无"}', 'SmartCache');
    }

    if (audioUrl == null || audioUrl.isEmpty) {
      throw Exception('无法获取音频URL - songId: ${song.id}');
    }

    Logger.info('🎵 [下载] 开始下载音频: ${song.title} -> $filePath', 'SmartCache');
    Logger.debug('🎵 [下载] 下载URL: ${audioUrl.substring(0, math.min(100, audioUrl.length))}...', 'SmartCache');
    
    try {
      await _dio.download(audioUrl, filePath);
      Logger.success('🎵 [下载] 下载完成: ${song.title}', 'SmartCache');
    } catch (e) {
      Logger.error('🎵 [下载] 下载失败: ${song.title}', e, null, 'SmartCache');
      rethrow;
    }
  }

  /// 确保缓存空间足够
  Future<void> _ensureCacheSpace() async {
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

  /// 初始化 SharedPreferences
  Future<void> _ensurePrefsInitialized() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// 获取缓存列表
  Future<List<Map<String, dynamic>>> _getCacheList() async {
    try {
      await _ensurePrefsInitialized();
      final jsonStr = _prefs!.getString(playCacheKey);
      if (jsonStr == null || jsonStr.isEmpty) return [];
      
      final List<dynamic> list = jsonDecode(jsonStr);
      return list.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  /// 保存缓存列表
  Future<void> _saveCacheList(List<Map<String, dynamic>> list) async {
    await _ensurePrefsInitialized();
    final jsonStr = jsonEncode(list);
    await _prefs!.setString(playCacheKey, jsonStr);
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
      
      Logger.debug('🎵 [统计] 检查缓存目录: ${cacheDir.path}', 'SmartCache');
      
      if (!await cacheDir.exists()) {
        Logger.debug('🎵 [统计] 缓存目录不存在，返回大小 0', 'SmartCache');
        return 0;
      }

      int totalSize = 0;
      int fileCount = 0;
      await for (var entity in cacheDir.list()) {
        if (entity is File) {
          final fileSize = await entity.length();
          totalSize += fileSize;
          fileCount++;
          Logger.debug('🎵 [统计] 缓存文件: ${path.basename(entity.path)} - ${formatSize(fileSize)}', 'SmartCache');
        }
      }
      
      Logger.info('🎵 [统计] 播放缓存统计: $fileCount 个文件, 总大小: ${formatSize(totalSize)}', 'SmartCache');
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
      
      await _ensurePrefsInitialized();
      await _prefs!.remove(playCacheKey);
      Logger.success('播放缓存清理完成', 'SmartCache');
      return true;
    } catch (e) {
      Logger.error('清理播放缓存失败', e, null, 'SmartCache');
      return false;
    }
  }

  /// 获取缓存统计信息
  Future<Map<String, dynamic>> getCacheStats() async {
    final playSize = await _getPlayCacheSize();
    final cacheList = await _getCacheList();
    
    return {
      'playCache': {
        'size': playSize,
        'count': cacheList.length,
        'maxCount': maxPlayCacheCount,
        'maxSize': maxPlayCacheSize,
      },
    };
  }

  /// 格式化文件大小
  String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}