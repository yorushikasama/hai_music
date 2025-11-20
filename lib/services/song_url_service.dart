import 'dart:async';
import '../models/song.dart';
import '../utils/logger.dart';
import 'music_api_service.dart';
import 'preferences_cache_service.dart';

/// 歌曲 URL 管理服务
/// 负责获取和缓存歌曲播放链接
class SongUrlService {
  final MusicApiService _musicService = MusicApiService();
  final PreferencesCacheService _cache = PreferencesCacheService();
  
  // URL 缓存
  final Map<String, String> _urlCache = {};
  final Map<String, DateTime> _urlCacheTimestamp = {};
  static const int _urlCacheExpiryMinutes = 30;
  
  // 并发控制
  final Map<String, Completer<String?>> _pendingRequests = {};
  
  /// 获取歌曲播放 URL（带缓存和并发控制）
  Future<String?> getSongUrl(Song song) async {
    // 优先使用直链
    if (song.audioUrl.isNotEmpty && 
        (song.audioUrl.startsWith('http') || song.audioUrl.startsWith('file://'))) {
      Logger.debug('使用直链: ${song.audioUrl}', 'SongUrlService');
      return song.audioUrl;
    }
    
    // 检查内存缓存
    final cachedUrl = _getCachedUrl(song.id);
    if (cachedUrl != null) {
      Logger.debug('使用内存缓存: ${song.title}', 'SongUrlService');
      return cachedUrl;
    }
    
    // 检查持久化缓存
    final persistentUrl = await _getPersistentCachedUrl(song.id);
    if (persistentUrl != null) {
      Logger.debug('使用持久化缓存: ${song.title}', 'SongUrlService');
      _setCachedUrl(song.id, persistentUrl);
      return persistentUrl;
    }
    
    // 并发控制：如果已有相同请求在进行中，等待结果
    if (_pendingRequests.containsKey(song.id)) {
      Logger.debug('等待进行中的请求: ${song.title}', 'SongUrlService');
      return await _pendingRequests[song.id]!.future;
    }
    
    // 创建新的请求
    final completer = Completer<String?>();
    _pendingRequests[song.id] = completer;
    
    try {
      Logger.info('从 API 获取播放链接: ${song.title}', 'SongUrlService');
      
      final url = await _musicService.getSongUrl(songId: song.id);
      
      if (url != null && url.isNotEmpty) {
        // 缓存 URL
        _setCachedUrl(song.id, url);
        await _setPersistentCachedUrl(song.id, url);
        
        Logger.success('获取播放链接成功: ${song.title}', 'SongUrlService');
        completer.complete(url);
        return url;
      } else {
        Logger.warning('获取播放链接失败: ${song.title}', 'SongUrlService');
        completer.complete(null);
        return null;
      }
    } catch (e) {
      Logger.error('获取播放链接异常: ${song.title}', e, null, 'SongUrlService');
      completer.complete(null);
      return null;
    } finally {
      _pendingRequests.remove(song.id);
    }
  }
  
  /// 批量预加载歌曲 URL
  Future<void> preloadUrls(List<Song> songs) async {
    Logger.info('开始预加载 ${songs.length} 首歌曲的播放链接', 'SongUrlService');
    
    final futures = songs.map((song) async {
      try {
        await getSongUrl(song);
      } catch (e) {
        Logger.warning('预加载失败: ${song.title}', 'SongUrlService');
      }
    });
    
    await Future.wait(futures);
    Logger.success('预加载完成', 'SongUrlService');
  }
  
  /// 获取内存缓存的 URL
  String? _getCachedUrl(String songId) {
    if (_urlCache.containsKey(songId)) {
      final timestamp = _urlCacheTimestamp[songId];
      if (timestamp != null) {
        final age = DateTime.now().difference(timestamp).inMinutes;
        if (age < _urlCacheExpiryMinutes) {
          return _urlCache[songId];
        } else {
          // 缓存过期，清理
          _urlCache.remove(songId);
          _urlCacheTimestamp.remove(songId);
        }
      }
    }
    return null;
  }
  
  /// 设置内存缓存的 URL
  void _setCachedUrl(String songId, String url) {
    _urlCache[songId] = url;
    _urlCacheTimestamp[songId] = DateTime.now();
  }
  
  /// 获取持久化缓存的 URL
  Future<String?> _getPersistentCachedUrl(String songId) async {
    try {
      await _cache.init();
      
      final cacheKey = 'song_url_$songId';
      final timestampKey = 'song_url_time_$songId';
      
      final cachedUrl = await _cache.getString(cacheKey);
      final cachedTimestamp = await _cache.getInt(timestampKey) ?? 0;
      
      if (cachedUrl != null && cachedUrl.isNotEmpty) {
        final age = DateTime.now().millisecondsSinceEpoch - cachedTimestamp;
        final ageMinutes = age / (1000 * 60);
        
        if (ageMinutes < _urlCacheExpiryMinutes) {
          return cachedUrl;
        } else {
          // 缓存过期，清理
          await _cache.remove(cacheKey);
          await _cache.remove(timestampKey);
        }
      }
    } catch (e) {
      Logger.error('读取持久化缓存失败', e, null, 'SongUrlService');
    }
    
    return null;
  }
  
  /// 设置持久化缓存的 URL
  Future<void> _setPersistentCachedUrl(String songId, String url) async {
    try {
      await _cache.init();
      
      final cacheKey = 'song_url_$songId';
      final timestampKey = 'song_url_time_$songId';
      
      await _cache.setString(cacheKey, url);
      await _cache.setInt(timestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      Logger.error('保存持久化缓存失败', e, null, 'SongUrlService');
    }
  }
  
  /// 清理过期缓存
  Future<void> cleanExpiredCache() async {
    Logger.info('清理过期的 URL 缓存', 'SongUrlService');
    
    // 清理内存缓存
    final now = DateTime.now();
    final expiredKeys = <String>[];
    
    _urlCacheTimestamp.forEach((key, timestamp) {
      if (now.difference(timestamp).inMinutes >= _urlCacheExpiryMinutes) {
        expiredKeys.add(key);
      }
    });
    
    for (final key in expiredKeys) {
      _urlCache.remove(key);
      _urlCacheTimestamp.remove(key);
    }
    
    Logger.info('清理了 ${expiredKeys.length} 个过期的内存缓存', 'SongUrlService');
    
    // 清理持久化缓存的逻辑可以在这里添加
    // 由于需要遍历所有缓存键，这里暂时省略
  }
  
  /// 清空所有缓存
  void clearAllCache() {
    Logger.info('清空所有 URL 缓存', 'SongUrlService');
    _urlCache.clear();
    _urlCacheTimestamp.clear();
    _pendingRequests.clear();
  }
  
  /// 获取缓存统计信息
  Map<String, dynamic> getCacheStats() {
    return {
      'memoryCacheSize': _urlCache.length,
      'pendingRequests': _pendingRequests.length,
      'cacheExpiryMinutes': _urlCacheExpiryMinutes,
    };
  }
}
