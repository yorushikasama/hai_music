import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../models/audio_quality.dart';
import '../../models/song.dart';
import '../../utils/format_utils.dart';
import '../../utils/logger.dart';
import '../download/download.dart';
import '../core/core.dart';

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

/// 智能播放缓存服务
///
/// 播放时自动缓存音频文件的全局单例服务，采用 LRU 淘汰策略。
/// 缓存上限: 50首歌曲 / 500MB，过期时间7天。
/// 被 PlaybackControllerService 和 MusicAudioHandler 直接依赖，
/// 实现播放即缓存的无感体验。
class SmartCacheService {
  static final SmartCacheService _instance = SmartCacheService._internal();
  factory SmartCacheService() => _instance;
  SmartCacheService._internal();

  final _audioDownloadService = AudioDownloadService();
  final PreferencesService _prefs = PreferencesService();

  static const int maxPlayCacheCount = 50;
  static const int maxPlayCacheSize = 500 * 1024 * 1024;
  static const int cacheExpiryDays = 7;
  static const String playCacheKey = 'play_cache_list';

  static const List<String> _cacheExtensions = ['.mp3', '.flac', '.ec3'];

  Completer<void>? _lock;

  List<_CacheEntry>? _memoryCache;
  bool _memoryCacheDirty = false;
  Timer? _persistTimer;

  Future<T> _synchronized<T>(Future<T> Function() action) async {
    while (_lock != null) {
      try {
        await _lock!.future;
      } catch (e) {
        // 前一个操作异常完成，继续等待获取锁
      }
    }
    _lock = Completer<void>();
    try {
      final result = await action();
      return result;
    } catch (e) {
      // 操作异常时通过 completeError 通知等待者
      final lock = _lock!;
      _lock = null;
      lock.completeError(e);
      rethrow;
    } finally {
      // 只有在未通过 catch 分支完成时才正常 complete
      if (_lock != null) {
        final lock = _lock!;
        _lock = null;
        lock.complete();
      }
    }
  }

  Future<List<_CacheEntry>> _getCacheList() async {
    if (_memoryCache != null) {
      return _memoryCache!;
    }

    try {
      final jsonStr = await _prefs.getString(playCacheKey);
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
      await _prefs.setString(playCacheKey, jsonStr);
      _memoryCacheDirty = false;
    } catch (e) {
      Logger.error('持久化缓存列表失败', e, null, 'SmartCache');
    }
  }

  /// 播放时缓存歌曲音频文件
  Future<void> cacheOnPlay(Song song, {AudioQuality? audioQuality}) async {
    if (song.audioUrl.startsWith('file://') || song.audioUrl.startsWith('content://')) {
      return;
    }

    await _synchronized(() async {
      try {
        final quality = audioQuality ?? await AudioQualityService.instance.getCurrentQuality();

        final cacheFile = await _getPlayCacheFile(song.id, quality: quality);
        if (await cacheFile.exists()) {
          await _updateAccessTime(song.id);
          return;
        }

        await _ensureCacheSpace();

        await _downloadToPlayCache(song, audioQuality: quality);

        if (await cacheFile.exists()) {
          final fileSize = await cacheFile.length();
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

  Future<File> _getPlayCacheFile(String songId, {AudioQuality? quality}) async {
    final filePath = await StoragePathManager().getCacheFilePath(songId, quality: quality);
    return File(filePath);
  }

  Future<void> _deleteAllQualityVariants(String songId) async {
    final cacheDir = await StoragePathManager().getPlayCacheDir();
    for (final ext in _cacheExtensions) {
      final file = File('${cacheDir.path}${Platform.pathSeparator}$songId$ext');
      if (await file.exists()) {
        await file.delete();
        Logger.info('清理音质变体缓存: $songId$ext', 'SmartCache');
      }
    }
  }

  Future<void> _downloadToPlayCache(Song song, {AudioQuality? audioQuality}) async {
    final quality = audioQuality ?? await AudioQualityService.instance.getCurrentQuality();
    final file = await _getPlayCacheFile(song.id, quality: quality);
    await _downloadAudio(song, file.path, audioQuality: quality);
  }

  Future<void> _downloadAudio(Song song, String filePath, {AudioQuality? audioQuality}) async {
    final quality = audioQuality ?? await AudioQualityService.instance.getCurrentQuality();
    await _audioDownloadService.downloadAudio(
      song: song,
      targetPath: filePath,
      audioQuality: quality,
    );
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

    // 按 lastAccess 排序，最久未访问的在前
    cacheList.sort((a, b) => a.lastAccess.compareTo(b.lastAccess));

    // 收集要移除的 songId
    final removeCount = count.clamp(0, cacheList.length);
    final idsToRemove = <String>{};
    for (int i = 0; i < removeCount; i++) {
      idsToRemove.add(cacheList[i].songId);
      try {
        await _deleteAllQualityVariants(cacheList[i].songId);
        Logger.info('清理旧缓存: ${cacheList[i].songId}', 'SmartCache');
      } catch (e) {
        Logger.warning('清理缓存失败: ${cacheList[i].songId}', 'SmartCache');
      }
    }

    // 统一根据 songId 从 _memoryCache 中移除，确保与文件操作一致
    if (_memoryCache != null) {
      _memoryCache!.removeWhere((e) => idsToRemove.contains(e.songId));
    }
    await _markDirty();
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

  /// 获取播放缓存总大小（字节）
  Future<int> getPlayCacheSize() {
    return _getPlayCacheSize();
  }

  Future<int> _getPlayCacheSize() async {
    try {
      final cacheDir = await StoragePathManager().getPlayCacheDir();

      if (!await cacheDir.exists()) {
        return 0;
      }

      int totalSize = 0;
      await for (final entity in cacheDir.list()) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }

      return totalSize;
    } catch (e) {
      Logger.error('🎵 [统计] 获取缓存大小失败', e, null, 'SmartCache');
      return 0;
    }
  }

  /// 清空所有播放缓存，返回是否成功
  Future<bool> clearPlayCache() async {
    try {
      final cacheDir = await StoragePathManager().getPlayCacheDir();

      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }

      _memoryCache = [];
      _memoryCacheDirty = false;
      _persistTimer?.cancel();
      _persistTimer = null;

      await _prefs.remove(playCacheKey);
      Logger.success('播放缓存清理完成', 'SmartCache');
      return true;
    } catch (e) {
      Logger.error('清理播放缓存失败', e, null, 'SmartCache');
      return false;
    }
  }

}
