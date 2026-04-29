import 'dart:async';
import '../../models/song.dart';
import '../../utils/logger.dart';
import '../core/core.dart';
import '../network/network.dart';

/// 歌曲 URL 获取与缓存服务
///
/// 负责音频播放 URL 的获取、缓存和请求去重。
/// 采用内存缓存 + 持久化缓存双级策略(30分钟过期)，
/// 通过 Completer 实现请求去重，避免同一歌曲的并发重复请求。
/// 被 PlaybackControllerService/AudioHandlerService/DownloadManager 依赖。
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
        (song.audioUrl.startsWith('http') ||
            song.audioUrl.startsWith('file://') ||
            song.audioUrl.startsWith('content://'))) {
      return song.audioUrl;
    }

    final effectiveQuality = qualityCode ?? await AudioQualityService.instance.getCurrentQualityCode();
    final key = _cacheKey(song.id, effectiveQuality);

    final cachedUrl = _getCachedUrl(key);
    if (cachedUrl != null) {
      return cachedUrl;
    }

    final persistentUrl = await _getPersistentCachedUrl(key);
    if (persistentUrl != null) {
      _setCachedUrl(key, persistentUrl);
      return persistentUrl;
    }

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
      ).timeout(const Duration(seconds: 10));

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
