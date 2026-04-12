import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/audio_quality.dart';
import '../models/song.dart';
import '../utils/format_utils.dart';
import '../utils/logger.dart';
import 'audio_quality_service.dart';
import 'dio_client.dart';
import 'music_api_service.dart';
import 'preferences_service.dart';
import 'storage_path_manager.dart';

class _CacheEntry {
  final String songId;
  final String title;
  final String artist;
  int lastAccess;
  int cacheTime;

  _CacheEntry({
    required this.songId,
    required this.title,
    required this.artist,
    required this.lastAccess,
    required this.cacheTime,
  });

  factory _CacheEntry.fromMap(Map<String, dynamic> map) {
    return _CacheEntry(
      songId: map['songId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      artist: map['artist'] as String? ?? '',
      lastAccess: map['lastAccess'] as int? ?? 0,
      cacheTime: map['cacheTime'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'songId': songId,
      'title': title,
      'artist': artist,
      'lastAccess': lastAccess,
      'cacheTime': cacheTime,
    };
  }
}

class SmartCacheService {
  static final SmartCacheService _instance = SmartCacheService._internal();
  factory SmartCacheService() => _instance;
  SmartCacheService._internal();

  final DioClient _dioClient = DioClient();
  final MusicApiService _apiService = MusicApiService();
  final PreferencesService _prefsCache = PreferencesService();

  static const int maxPlayCacheCount = 50;
  static const int maxPlayCacheSize = 500 * 1024 * 1024;
  static const int cacheExpiryDays = 7;
  static const String playCacheKey = 'play_cache_list';

  static const List<String> _cacheExtensions = ['.mp3', '.flac', '.ec3'];

  Completer<void>? _lock;

  List<_CacheEntry>? _memoryCache;
  bool _memoryCacheDirty = false;
  Timer? _persistTimer;

  int _cacheHits = 0;
  int _cacheMisses = 0;

  Future<T> _synchronized<T>(Future<T> Function() action) async {
    while (_lock != null) {
      try {
        await _lock!.future;
      } catch (e) {
        Logger.debug('缓存锁等待中断', 'SmartCache');
      }
    }
    _lock = Completer<void>();
    try {
      final result = await action();
      return result;
    } finally {
      final lock = _lock!;
      _lock = null;
      lock.complete();
    }
  }

  Future<List<_CacheEntry>> _getCacheList() async {
    if (_memoryCache != null) {
      return _memoryCache!;
    }

    try {
      final jsonStr = await _prefsCache.getString(playCacheKey);
      if (jsonStr == null || jsonStr.isEmpty) {
        _memoryCache = [];
        return _memoryCache!;
      }

      final List<dynamic> list = jsonDecode(jsonStr) as List<dynamic>;
      _memoryCache = list
          .map((item) => _CacheEntry.fromMap(item as Map<String, dynamic>))
          .toList();
      return _memoryCache!;
    } catch (e) {
      _memoryCache = [];
      return _memoryCache!;
    }
  }

  Future<void> _markDirty() async {
    _memoryCacheDirty = true;
    _persistTimer ??= Timer(const Duration(seconds: 5), _persistToDisk);
  }

  Future<void> _persistToDisk() async {
    _persistTimer?.cancel();
    _persistTimer = null;

    if (!_memoryCacheDirty || _memoryCache == null) return;

    try {
      final jsonList = _memoryCache!.map((e) => e.toMap()).toList();
      final jsonStr = jsonEncode(jsonList);
      await _prefsCache.setString(playCacheKey, jsonStr);
      _memoryCacheDirty = false;
    } catch (e) {
      Logger.error('持久化缓存列表失败', e, null, 'SmartCache');
    }
  }

  Future<void> cacheOnPlay(Song song, {AudioQuality? audioQuality}) async {
    await _synchronized(() async {
      try {
        final quality = audioQuality ?? AudioQualityService.instance.getCurrentQuality();

        final cacheFile = await _getPlayCacheFile(song.id, quality: quality);
        if (cacheFile.existsSync()) {
          _cacheHits++;
          await _updateAccessTime(song.id);
          return;
        }

        await _ensureCacheSpace();

        await _downloadToPlayCache(song, audioQuality: quality);

        if (cacheFile.existsSync()) {
          final fileSize = cacheFile.lengthSync();
          Logger.info('🎵 [缓存] 音频文件缓存成功: ${song.title} (${FormatUtils.formatSize(fileSize)})', 'SmartCache');
        } else {
          Logger.error('🎵 [缓存] 音频文件下载失败: 文件不存在', null, null, 'SmartCache');
          return;
        }

        await _addToCacheList(song);
      } catch (e, stackTrace) {
        Logger.error('🎵 [缓存] 缓存歌曲失败: ${song.title}', e, stackTrace, 'SmartCache');
      }
    });
  }

  Future<String?> getCachedAudioPath(String songId) async {
    return _synchronized(() async {
      try {
        final quality = AudioQualityService.instance.getCurrentQuality();
        final playFile = await _getPlayCacheFile(songId, quality: quality);
        if (playFile.existsSync()) {
          if (_isCacheExpiredInMemory(songId)) {
            Logger.info('🎵 [缓存] 缓存已过期，删除: $songId', 'SmartCache');
            await _removeCacheItemInternal(songId);
            _cacheMisses++;
            return null;
          }
          _cacheHits++;
          await _updateAccessTime(songId);
          return playFile.path;
        }

        _cacheMisses++;
        return null;
      } catch (e) {
        Logger.error('获取缓存路径失败', e, null, 'SmartCache');
        _cacheMisses++;
        return null;
      }
    });
  }

  bool _isCacheExpiredInMemory(String songId) {
    if (_memoryCache == null) return false;

    final entry = _memoryCache!.where((e) => e.songId == songId).firstOrNull;
    if (entry == null) return true;

    final now = DateTime.now().millisecondsSinceEpoch;
    const expiryTime = cacheExpiryDays * 24 * 60 * 60 * 1000;
    return now - entry.cacheTime > expiryTime;
  }

  Future<File> _getPlayCacheFile(String songId, {AudioQuality? quality}) async {
    final filePath = await StoragePathManager().getCacheFilePath(songId, quality: quality);
    return File(filePath);
  }

  Future<void> _deleteAllQualityVariants(String songId) async {
    final cacheDir = await StoragePathManager().getPlayCacheDir();
    for (final ext in _cacheExtensions) {
      final file = File('${cacheDir.path}${Platform.pathSeparator}$songId$ext');
      if (file.existsSync()) {
        file.deleteSync();
        Logger.info('清理音质变体缓存: $songId$ext', 'SmartCache');
      }
    }
  }

  Future<void> _downloadToPlayCache(Song song, {AudioQuality? audioQuality}) async {
    final quality = audioQuality ?? AudioQualityService.instance.getCurrentQuality();
    final file = await _getPlayCacheFile(song.id, quality: quality);
    await _downloadAudio(song, file.path, audioQuality: quality);
  }

  Future<void> _downloadAudio(Song song, String filePath, {AudioQuality? audioQuality}) async {
    String? audioUrl = song.audioUrl;
    if (audioUrl.isEmpty) {
      final quality = audioQuality ?? AudioQualityService.instance.getCurrentQuality();
      Logger.debug('智能缓存下载，使用音质代码: ${quality.value}', 'SmartCache');
      audioUrl = await _apiService.getSongUrl(songId: song.id, quality: quality.value);
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

  Future<void> _ensureCacheSpace() async {
    await _cleanExpiredCache();

    final cacheList = await _getCacheList();

    if (cacheList.length >= maxPlayCacheCount) {
      await _cleanOldCache(cacheList.length - maxPlayCacheCount + 1);
    }

    final cacheSize = await _getPlayCacheSize();
    if (cacheSize > maxPlayCacheSize) {
      await _cleanOldCache(5);
    }
  }

  Future<void> _cleanExpiredCache() async {
    final cacheList = await _getCacheList();
    final now = DateTime.now().millisecondsSinceEpoch;
    const expiryTime = cacheExpiryDays * 24 * 60 * 60 * 1000;

    final expiredIds = <String>[];
    for (final entry in cacheList) {
      if (now - entry.cacheTime > expiryTime) {
        expiredIds.add(entry.songId);
      }
    }

    for (final songId in expiredIds) {
      try {
        await _deleteAllQualityVariants(songId);
        Logger.info('清理过期缓存: $songId', 'SmartCache');
      } catch (e) {
        Logger.warning('清理过期缓存失败: $songId', 'SmartCache');
      }
    }

    if (expiredIds.isNotEmpty) {
      _memoryCache?.removeWhere((e) => expiredIds.contains(e.songId));
      await _markDirty();
    }
  }

  Future<void> _cleanOldCache(int count) async {
    final cacheList = await _getCacheList();

    cacheList.sort((a, b) => a.lastAccess.compareTo(b.lastAccess));

    for (int i = 0; i < count && i < cacheList.length; i++) {
      final songId = cacheList[i].songId;
      try {
        await _deleteAllQualityVariants(songId);
        Logger.info('清理旧缓存: $songId', 'SmartCache');
      } catch (e) {
        Logger.warning('清理缓存失败: $songId', 'SmartCache');
      }
    }

    final removeCount = count.clamp(0, cacheList.length);
    _memoryCache?.sort((a, b) => a.lastAccess.compareTo(b.lastAccess));
    if (_memoryCache != null && removeCount <= _memoryCache!.length) {
      _memoryCache!.removeRange(0, removeCount);
    }
    await _markDirty();
  }

  Future<void> _removeCacheItemInternal(String songId) async {
    try {
      await _deleteAllQualityVariants(songId);
      _memoryCache?.removeWhere((e) => e.songId == songId);
      await _markDirty();
    } catch (e) {
      Logger.error('移除缓存项失败: $songId', e, null, 'SmartCache');
    }
  }

  Future<void> _addToCacheList(Song song) async {
    final cacheList = await _getCacheList();
    final now = DateTime.now().millisecondsSinceEpoch;

    cacheList.removeWhere((e) => e.songId == song.id);
    cacheList.add(_CacheEntry(
      songId: song.id,
      title: song.title,
      artist: song.artist,
      lastAccess: now,
      cacheTime: now,
    ));

    await _markDirty();
  }

  Future<void> _updateAccessTime(String songId) async {
    final cacheList = await _getCacheList();
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final entry in cacheList) {
      if (entry.songId == songId) {
        entry.lastAccess = now;
        break;
      }
    }

    await _markDirty();
  }

  Future<int> getPlayCacheSize() {
    return _getPlayCacheSize();
  }

  Future<int> _getPlayCacheSize() async {
    try {
      final cacheDir = await StoragePathManager().getPlayCacheDir();

      if (!cacheDir.existsSync()) {
        return 0;
      }

      int totalSize = 0;
      await for (final entity in cacheDir.list()) {
        if (entity is File) {
          totalSize += entity.lengthSync();
        }
      }

      return totalSize;
    } catch (e) {
      Logger.error('🎵 [统计] 获取缓存大小失败', e, null, 'SmartCache');
      return 0;
    }
  }

  Future<bool> clearPlayCache() async {
    try {
      final cacheDir = await StoragePathManager().getPlayCacheDir();

      if (cacheDir.existsSync()) {
        cacheDir.deleteSync(recursive: true);
      }

      _memoryCache = [];
      _memoryCacheDirty = false;
      _persistTimer?.cancel();
      _persistTimer = null;

      await _prefsCache.remove(playCacheKey);
      Logger.success('播放缓存清理完成', 'SmartCache');
      return true;
    } catch (e) {
      Logger.error('清理播放缓存失败', e, null, 'SmartCache');
      return false;
    }
  }

  Future<Map<String, dynamic>> getCacheStats() async {
    final playSize = await _getPlayCacheSize();
    final cacheList = await _getCacheList();
    final now = DateTime.now().millisecondsSinceEpoch;
    const expiryTime = cacheExpiryDays * 24 * 60 * 60 * 1000;

    final expiredCount = cacheList.where((entry) {
      return now - entry.cacheTime > expiryTime;
    }).length;

    final totalRequests = _cacheHits + _cacheMisses;
    final hitRate = totalRequests > 0 ? _cacheHits / totalRequests : 0.0;

    return {
      'playCache': {
        'size': playSize,
        'count': cacheList.length,
        'expiredCount': expiredCount,
        'maxCount': maxPlayCacheCount,
        'maxSize': maxPlayCacheSize,
        'expiryDays': cacheExpiryDays,
        'hitRate': hitRate,
        'hits': _cacheHits,
        'misses': _cacheMisses,
      },
    };
  }

  Future<void> persistIfNeeded() async {
    await _persistToDisk();
  }

  Future<void> dispose() async {
    if (_memoryCacheDirty && _memoryCache != null) {
      await _persistToDisk();
    }
    _persistTimer?.cancel();
    _persistTimer = null;
    _memoryCache = null;
  }
}
