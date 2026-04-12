import 'dart:async';
import '../models/song.dart';
import '../utils/logger.dart';
import 'audio_quality_service.dart';
import 'music_api_service.dart';
import 'preferences_service.dart';

class SongUrlService {
  static final SongUrlService _instance = SongUrlService._internal();
  factory SongUrlService() => _instance;
  SongUrlService._internal() {
    _startPeriodicCleanup();
  }

  static final MusicApiService _musicService = MusicApiService();
  static final PreferencesService _cache = PreferencesService();

  final Map<String, String> _urlCache = {};
  final Map<String, DateTime> _urlCacheTimestamp = {};
  static const int _urlCacheExpiryMinutes = 30;
  static const int _maxCacheSize = 200;

  final Map<String, Completer<String?>> _pendingRequests = {};

  int _cacheHits = 0;
  int _cacheMisses = 0;

  Timer? _cleanupTimer;

  void _startPeriodicCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      cleanExpiredCache();
    });
  }

  String _cacheKey(String songId, int qualityCode) => '${songId}_q$qualityCode';

  Future<String?> getSongUrl(Song song, {int? qualityCode, bool forceRefresh = false}) async {
    if (!forceRefresh &&
        song.audioUrl.isNotEmpty &&
        (song.audioUrl.startsWith('http') || song.audioUrl.startsWith('file://'))) {
      _cacheHits++;
      return song.audioUrl;
    }

    final effectiveQuality = qualityCode ?? AudioQualityService.instance.getCurrentQualityCode();
    final key = _cacheKey(song.id, effectiveQuality);

    final cachedUrl = _getCachedUrl(key);
    if (cachedUrl != null) {
      _cacheHits++;
      return cachedUrl;
    }

    final persistentUrl = await _getPersistentCachedUrl(key);
    if (persistentUrl != null) {
      _cacheHits++;
      _setCachedUrl(key, persistentUrl);
      return persistentUrl;
    }

    _cacheMisses++;

    if (_pendingRequests.containsKey(key)) {
      return _pendingRequests[key]!.future;
    }

    final completer = Completer<String?>();
    _pendingRequests[key] = completer;

    try {
      Logger.info('从 API 获取播放链接: ${song.title} (音质: $effectiveQuality)', 'SongUrlService');

      final url = await _musicService.getSongUrl(
        songId: song.id,
        quality: effectiveQuality,
      );

      if (url != null && url.isNotEmpty) {
        _setCachedUrl(key, url);
        await _setPersistentCachedUrl(key, url);
        Logger.success('获取播放链接成功: ${song.title} (音质: $effectiveQuality)', 'SongUrlService');
        if (!completer.isCompleted) completer.complete(url);
        return url;
      } else {
        Logger.warning('获取播放链接失败: ${song.title}', 'SongUrlService');
        if (!completer.isCompleted) completer.complete(null);
        return null;
      }
    } catch (e) {
      Logger.error('获取播放链接异常: ${song.title}', e, null, 'SongUrlService');
      if (!completer.isCompleted) completer.complete(null);
      return null;
    } finally {
      _pendingRequests.remove(key);
    }
  }

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

  void invalidateSongCache(String songId) {
    final keysToRemove = _urlCache.keys.where((k) => k.startsWith('${songId}_q')).toList();
    for (final key in keysToRemove) {
      _urlCache.remove(key);
      _urlCacheTimestamp.remove(key);
      _removePersistentCachedUrl(key);
    }
    if (keysToRemove.isNotEmpty) {
      Logger.debug('已清除歌曲 $songId 的 ${keysToRemove.length} 个缓存条目', 'SongUrlService');
    }
  }

  void invalidateAllCache() {
    Logger.info('清空所有 URL 缓存', 'SongUrlService');
    _urlCache.clear();
    _urlCacheTimestamp.clear();
    _pendingRequests.clear();
    _clearAllPersistentCache();
  }

  String? _getCachedUrl(String key) {
    if (_urlCache.containsKey(key)) {
      final timestamp = _urlCacheTimestamp[key];
      if (timestamp != null) {
        final age = DateTime.now().difference(timestamp).inMinutes;
        if (age < _urlCacheExpiryMinutes) {
          return _urlCache[key];
        } else {
          _urlCache.remove(key);
          _urlCacheTimestamp.remove(key);
        }
      }
    }
    return null;
  }

  void _setCachedUrl(String key, String url) {
    if (_urlCache.length >= _maxCacheSize) {
      _evictOldestCache();
    }
    _urlCache[key] = url;
    _urlCacheTimestamp[key] = DateTime.now();
  }

  void _evictOldestCache() {
    String? oldestKey;
    DateTime? oldestTime;
    for (final entry in _urlCacheTimestamp.entries) {
      if (oldestTime == null || entry.value.isBefore(oldestTime)) {
        oldestKey = entry.key;
        oldestTime = entry.value;
      }
    }
    if (oldestKey != null) {
      _urlCache.remove(oldestKey);
      _urlCacheTimestamp.remove(oldestKey);
    }
  }

  Future<String?> _getPersistentCachedUrl(String key) async {
    try {
      await _cache.init();

      final cacheKey = 'song_url_$key';
      final timestampKey = 'song_url_time_$key';

      final cachedUrl = await _cache.getString(cacheKey);
      final cachedTimestamp = await _cache.getInt(timestampKey) ?? 0;

      if (cachedUrl != null && cachedUrl.isNotEmpty) {
        final age = DateTime.now().millisecondsSinceEpoch - cachedTimestamp;
        final ageMinutes = age / (1000 * 60);

        if (ageMinutes < _urlCacheExpiryMinutes) {
          return cachedUrl;
        } else {
          await _cache.remove(cacheKey);
          await _cache.remove(timestampKey);
        }
      }
    } catch (e) {
      Logger.error('读取持久化缓存失败', e, null, 'SongUrlService');
    }

    return null;
  }

  Future<void> _setPersistentCachedUrl(String key, String url) async {
    try {
      await _cache.init();

      final cacheKey = 'song_url_$key';
      final timestampKey = 'song_url_time_$key';

      await _cache.setString(cacheKey, url);
      await _cache.setInt(timestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      Logger.error('保存持久化缓存失败', e, null, 'SongUrlService');
    }
  }

  Future<void> cleanExpiredCache() async {
    Logger.info('清理过期的 URL 缓存', 'SongUrlService');

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

    await _cleanExpiredPersistentCache();
  }

  Future<void> _cleanExpiredPersistentCache() async {
    try {
      await _cache.init();
      final keys = await _cache.getKeys();
      final urlKeys = keys.where((k) => k.startsWith('song_url_') && !k.endsWith('_time')).toList();
      final now = DateTime.now().millisecondsSinceEpoch;
      int cleaned = 0;

      for (final cacheKey in urlKeys) {
        final timestampKey = '${cacheKey}_time';
        final cachedTimestamp = await _cache.getInt(timestampKey) ?? 0;
        final ageMinutes = (now - cachedTimestamp) / (1000 * 60);

        if (ageMinutes >= _urlCacheExpiryMinutes) {
          await _cache.remove(cacheKey);
          await _cache.remove(timestampKey);
          cleaned++;
        }
      }

      if (cleaned > 0) {
        Logger.info('清理了 $cleaned 个过期的持久化 URL 缓存', 'SongUrlService');
      }
    } catch (e) {
      Logger.error('清理持久化缓存失败', e, null, 'SongUrlService');
    }
  }

  void clearAllCache() {
    Logger.info('清空所有 URL 缓存', 'SongUrlService');
    _urlCache.clear();
    _urlCacheTimestamp.clear();
    _pendingRequests.clear();
    _clearAllPersistentCache();
  }

  Future<void> _removePersistentCachedUrl(String key) async {
    try {
      await _cache.remove('song_url_$key');
      await _cache.remove('song_url_time_$key');
    } catch (e) {
      Logger.debug('清除缓存 URL 失败', 'SongUrl');
    }
  }

  Future<void> _clearAllPersistentCache() async {
    try {
      final keys = await _cache.getKeys();
      final urlKeys = keys.where((k) => k.startsWith('song_url_')).toList();
      for (final key in urlKeys) {
        await _cache.remove(key);
      }
      if (urlKeys.isNotEmpty) {
        Logger.info('清除了 ${urlKeys.length} 个持久化 URL 缓存', 'SongUrlService');
      }
    } catch (e) {
      Logger.error('清除持久化缓存失败', e, null, 'SongUrlService');
    }
  }

  Map<String, dynamic> getCacheStats() {
    final totalRequests = _cacheHits + _cacheMisses;
    final hitRate = totalRequests > 0 ? _cacheHits / totalRequests : 0.0;

    return {
      'memoryCacheSize': _urlCache.length,
      'maxCacheSize': _maxCacheSize,
      'pendingRequests': _pendingRequests.length,
      'cacheExpiryMinutes': _urlCacheExpiryMinutes,
      'hits': _cacheHits,
      'misses': _cacheMisses,
      'hitRate': hitRate,
    };
  }

  void dispose() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('SongUrlService 已释放'));
      }
    }
    _pendingRequests.clear();
  }
}
