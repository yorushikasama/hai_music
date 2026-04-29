import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../models/audio_quality.dart';
import '../../utils/logger.dart';

/// 存储路径管理器
///
/// 统一管理应用所有文件存储路径的全局单例服务。
/// 提供下载目录、封面目录(Music+Pictures双路径)、缓存目录、歌词目录的路径获取，
/// 并自动处理 Android 外部存储迁移和目录创建。
/// 被下载/缓存/收藏/存储等模块广泛依赖。
class StoragePathManager {
  static final StoragePathManager _instance = StoragePathManager._internal();
  factory StoragePathManager() => _instance;
  StoragePathManager._internal();

  static const String _appFolder = 'HaiMusic';
  static const String _musicFolder = 'music';
  static const String _audioFolder = 'audio';
  static const String _coverFolder = 'covers';
  static const String _playCacheFolder = 'play_cache';
  static const String _lyricsCacheFolder = 'lyrics_cache';
  static const String _downloadsFolder = 'Downloads';
  static const String _imageCacheFolder = 'libCachedImageData';

  static const String _androidPublicMusicFolder = 'HaiMusic';

  late Directory _documentsDir;
  late Directory _temporaryDir;
  bool _initialized = false;

  Directory? _androidDownloadsDir;
  Directory? _androidCoversDir;
  Directory? _picturesCoversDir;
  Directory? _androidLyricsCacheDir;

  Future<void> init() async {
    if (_initialized) return;
    _documentsDir = await getApplicationDocumentsDirectory();
    _temporaryDir = await getTemporaryDirectory();
    _initialized = true;
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) await init();
  }

  Future<Directory> _ensureDir(Directory dir) async {
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory?> _getAndroidPublicMusicDir() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    final possiblePaths = ['/storage/emulated/0/Music', '/sdcard/Music'];
    for (final p in possiblePaths) {
      final dir = Directory(p);
      if (await dir.exists()) return dir;
    }
    return null;
  }

  Future<Directory?> _getAndroidPublicPicturesDir() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    final possiblePaths = ['/storage/emulated/0/Pictures', '/sdcard/Pictures'];
    for (final p in possiblePaths) {
      final dir = Directory(p);
      if (await dir.exists()) return dir;
    }
    return null;
  }

  Future<Directory?> getLegacyDownloadsDir() async {
    await _ensureInitialized();
    if (kIsWeb || !Platform.isAndroid) return null;
    return Directory(path.join(_documentsDir.path, _appFolder, _downloadsFolder));
  }

  Future<Directory> getDownloadsDir() async {
    await _ensureInitialized();

    if (!kIsWeb && Platform.isAndroid) {
      if (_androidDownloadsDir != null) {
        return _ensureDir(_androidDownloadsDir!);
      }
      final publicMusicDir = await _getAndroidPublicMusicDir();
      if (publicMusicDir != null) {
        final downloadDir = Directory(path.join(publicMusicDir.path, _androidPublicMusicFolder));
        _androidDownloadsDir = downloadDir;
        Logger.info('Android 下载目录: ${downloadDir.path} (外部存储，卸载不丢失)', 'StoragePath');
        return _ensureDir(downloadDir);
      }
      Logger.warning('无法访问外部存储 Music 目录，降级到应用内部目录', 'StoragePath');
    }

    return _ensureDir(Directory(path.join(_documentsDir.path, _appFolder, _downloadsFolder)));
  }

  Future<int> migrateDownloadsIfNeeded() async {
    if (kIsWeb || !Platform.isAndroid) return 0;

    final publicMusicDir = await _getAndroidPublicMusicDir();
    if (publicMusicDir == null) return 0;

    final oldDir = Directory(path.join(_documentsDir.path, _appFolder, _downloadsFolder));
    if (!await oldDir.exists()) return 0;

    final newDir = Directory(path.join(publicMusicDir.path, _androidPublicMusicFolder));
    int migratedCount = 0;

    try {
      await for (final entity in oldDir.list(recursive: true)) {
        if (entity is File) {
          final relativePath = path.relative(entity.path, from: oldDir.path);
          final newPath = path.join(newDir.path, relativePath);
          final newFileDir = Directory(path.dirname(newPath));
          if (!await newFileDir.exists()) {
            await newFileDir.create(recursive: true);
          }
          if (!await File(newPath).exists()) {
            await entity.copy(newPath);
            migratedCount++;
            Logger.info('迁移文件: $relativePath -> $newPath', 'StoragePath');
          }
        }
      }

      if (migratedCount > 0) {
        await for (final entity in oldDir.list(recursive: true)) {
          if (entity is File) {
            final relativePath = path.relative(entity.path, from: oldDir.path);
            final newPath = path.join(newDir.path, relativePath);
            if (await File(newPath).exists()) {
              await entity.delete();
            }
          }
        }
        if (await _isDirEmpty(oldDir)) {
          await oldDir.delete();
        }
        Logger.success('下载目录迁移完成，共迁移 $migratedCount 个文件', 'StoragePath');
      }
    } catch (e) {
      Logger.error('迁移下载目录失败', e, null, 'StoragePath');
    }

    return migratedCount;
  }

  Future<int> migrateCoversIfNeeded() async {
    if (kIsWeb || !Platform.isAndroid) return 0;

    final publicMusicDir = await _getAndroidPublicMusicDir();
    if (publicMusicDir == null) return 0;

    final oldDir = Directory(path.join(_documentsDir.path, _musicFolder, _coverFolder));
    if (!await oldDir.exists()) return 0;

    final newDir = Directory(path.join(publicMusicDir.path, _androidPublicMusicFolder, _coverFolder));
    int migratedCount = 0;

    try {
      await for (final entity in oldDir.list(recursive: true)) {
        if (entity is File) {
          final relativePath = path.relative(entity.path, from: oldDir.path);
          final newPath = path.join(newDir.path, relativePath);
          final newFileDir = Directory(path.dirname(newPath));
          if (!await newFileDir.exists()) {
            await newFileDir.create(recursive: true);
          }
          if (!await File(newPath).exists()) {
            await entity.copy(newPath);
            migratedCount++;
          }
        }
      }

      if (migratedCount > 0) {
        await for (final entity in oldDir.list(recursive: true)) {
          if (entity is File) {
            final relativePath = path.relative(entity.path, from: oldDir.path);
            final newPath = path.join(newDir.path, relativePath);
            if (await File(newPath).exists()) {
              await entity.delete();
            }
          }
        }
        if (await _isDirEmpty(oldDir)) {
          await oldDir.delete(recursive: true);
        }
        Logger.success('封面目录迁移完成，共迁移 $migratedCount 个文件', 'StoragePath');
      }
    } catch (e) {
      Logger.error('迁移封面目录失败', e, null, 'StoragePath');
    }

    return migratedCount;
  }

  Future<int> migrateLyricsCacheIfNeeded() async {
    if (kIsWeb || !Platform.isAndroid) return 0;

    final publicMusicDir = await _getAndroidPublicMusicDir();
    if (publicMusicDir == null) return 0;

    final oldDir = Directory(path.join(_documentsDir.path, _musicFolder, _lyricsCacheFolder));
    if (!await oldDir.exists()) return 0;

    final newDir = Directory(path.join(publicMusicDir.path, _androidPublicMusicFolder, _lyricsCacheFolder));
    int migratedCount = 0;

    try {
      await for (final entity in oldDir.list(recursive: true)) {
        if (entity is File) {
          final relativePath = path.relative(entity.path, from: oldDir.path);
          final newPath = path.join(newDir.path, relativePath);
          final newFileDir = Directory(path.dirname(newPath));
          if (!await newFileDir.exists()) {
            await newFileDir.create(recursive: true);
          }
          if (!await File(newPath).exists()) {
            await entity.copy(newPath);
            migratedCount++;
          }
        }
      }

      if (migratedCount > 0) {
        await for (final entity in oldDir.list(recursive: true)) {
          if (entity is File) {
            final relativePath = path.relative(entity.path, from: oldDir.path);
            final newPath = path.join(newDir.path, relativePath);
            if (await File(newPath).exists()) {
              await entity.delete();
            }
          }
        }
        if (await _isDirEmpty(oldDir)) {
          await oldDir.delete(recursive: true);
        }
        Logger.success('歌词缓存目录迁移完成，共迁移 $migratedCount 个文件', 'StoragePath');
      }
    } catch (e) {
      Logger.error('迁移歌词缓存目录失败', e, null, 'StoragePath');
    }

    return migratedCount;
  }

  Future<bool> _isDirEmpty(Directory dir) async {
    return await dir.list().isEmpty;
  }

  Future<Directory> getMusicAudioDir() async {
    await _ensureInitialized();
    return _ensureDir(Directory(path.join(_documentsDir.path, _musicFolder, _audioFolder)));
  }

  Future<Directory> getMusicCoversDir() async {
    await _ensureInitialized();

    if (!kIsWeb && Platform.isAndroid) {
      if (_androidCoversDir != null) {
        return _ensureDir(_androidCoversDir!);
      }
      final publicMusicDir = await _getAndroidPublicMusicDir();
      if (publicMusicDir != null) {
        final coversDir = Directory(path.join(publicMusicDir.path, _androidPublicMusicFolder, _coverFolder));
        _androidCoversDir = coversDir;
        Logger.info('Android 封面目录: ${coversDir.path} (外部存储，卸载不丢失)', 'StoragePath');
        return _ensureDir(coversDir);
      }
      Logger.warning('无法访问外部存储 Music 目录，封面降级到应用内部目录', 'StoragePath');
    }

    return _ensureDir(Directory(path.join(_documentsDir.path, _musicFolder, _coverFolder)));
  }

  Future<Directory> getPicturesCoversDir() async {
    await _ensureInitialized();

    if (!kIsWeb && Platform.isAndroid) {
      if (_picturesCoversDir != null) {
        return _ensureDir(_picturesCoversDir!);
      }
      final publicPicturesDir = await _getAndroidPublicPicturesDir();
      if (publicPicturesDir != null) {
        final coversDir = Directory(path.join(publicPicturesDir.path, _androidPublicMusicFolder, _coverFolder));
        _picturesCoversDir = coversDir;
        Logger.info('Android Pictures 封面目录: ${coversDir.path} (MediaStore 兼容)', 'StoragePath');
        return _ensureDir(coversDir);
      }
    }

    return getMusicCoversDir();
  }

  Future<Directory> getPlayCacheDir() async {
    await _ensureInitialized();
    return _ensureDir(Directory(path.join(_documentsDir.path, _musicFolder, _playCacheFolder)));
  }

  Future<Directory> getImageCacheDir() async {
    await _ensureInitialized();
    return _ensureDir(Directory(path.join(_temporaryDir.path, _imageCacheFolder)));
  }

  Future<String> getAudioFilePath(String songId, {AudioQuality? quality}) async {
    final dir = await getMusicAudioDir();
    final ext = quality?.fileExtension ?? '.mp3';
    return path.join(dir.path, '$songId$ext');
  }

  Future<String> getCoverFilePath(String songId) async {
    final dir = await getMusicCoversDir();
    return path.join(dir.path, '$songId.jpg');
  }

  Future<String> getCacheFilePath(String songId, {AudioQuality? quality}) async {
    final dir = await getPlayCacheDir();
    final ext = quality?.fileExtension ?? '.mp3';
    return path.join(dir.path, '$songId$ext');
  }

  Future<Directory> getLyricsCacheDir() async {
    await _ensureInitialized();

    if (!kIsWeb && Platform.isAndroid) {
      if (_androidLyricsCacheDir != null) {
        return _ensureDir(_androidLyricsCacheDir!);
      }
      final publicMusicDir = await _getAndroidPublicMusicDir();
      if (publicMusicDir != null) {
        final lyricsDir = Directory(path.join(publicMusicDir.path, _androidPublicMusicFolder, _lyricsCacheFolder));
        _androidLyricsCacheDir = lyricsDir;
        Logger.info('Android 歌词缓存目录: ${lyricsDir.path} (外部存储，卸载不丢失)', 'StoragePath');
        return _ensureDir(lyricsDir);
      }
      Logger.warning('无法访问外部存储 Music 目录，歌词降级到应用内部目录', 'StoragePath');
    }

    return _ensureDir(Directory(path.join(_documentsDir.path, _musicFolder, _lyricsCacheFolder)));
  }

  /// 获取所有应用管理的目录路径前缀，用于文件删除前的路径合法性验证
  Future<List<String>> getManagedPathPrefixes() async {
    await _ensureInitialized();
    final prefixes = <String>[];

    try {
      prefixes.add((await getDownloadsDir()).path);
    } catch (_) {}
    try {
      prefixes.add((await getMusicAudioDir()).path);
    } catch (_) {}
    try {
      prefixes.add((await getMusicCoversDir()).path);
    } catch (_) {}
    try {
      prefixes.add((await getPicturesCoversDir()).path);
    } catch (_) {}
    try {
      prefixes.add((await getPlayCacheDir()).path);
    } catch (_) {}
    try {
      prefixes.add((await getLyricsCacheDir()).path);
    } catch (_) {}
    try {
      prefixes.add((await getImageCacheDir()).path);
    } catch (_) {}
    // 临时目录
    prefixes.add(_temporaryDir.path);
    // 文档目录下的应用子目录
    prefixes.add(path.join(_documentsDir.path, _appFolder));
    prefixes.add(path.join(_documentsDir.path, _musicFolder));

    return prefixes;
  }

  /// 验证文件路径是否在应用管理的目录范围内，防止路径遍历攻击
  Future<bool> isPathWithinManagedDir(String filePath) async {
    if (filePath.isEmpty) return false;
    final normalizedPath = path.normalize(filePath);
    final prefixes = await getManagedPathPrefixes();
    for (final prefix in prefixes) {
      final normalizedPrefix = path.normalize(prefix);
      if (normalizedPath.startsWith(normalizedPrefix)) {
        return true;
      }
    }
    return false;
  }
}
