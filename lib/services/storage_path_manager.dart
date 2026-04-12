import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../models/audio_quality.dart';
import '../utils/logger.dart';

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

  // Android 外部存储公共目录下的下载文件夹名
  static const String _androidPublicMusicFolder = 'HaiMusic';

  late Directory _documentsDir;
  late Directory _temporaryDir;
  bool _initialized = false;

  // 缓存 Android 外部存储下载目录
  Directory? _androidDownloadsDir;

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
    // ignore: avoid_slow_async_io
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Android 上获取外部存储公共 Music 目录，其他平台返回 null
  Directory? _getAndroidPublicMusicDir() {
    if (kIsWeb || !Platform.isAndroid) return null;
    // Android 标准外部存储 Music 目录
    final List<String> possiblePaths = [
      '/storage/emulated/0/Music',
      '/sdcard/Music',
    ];
    for (final p in possiblePaths) {
      final dir = Directory(p);
      if (dir.existsSync()) return dir;
    }
    return null;
  }

  /// 获取旧版下载目录（应用内部），用于迁移时路径替换
  /// 仅 Android 上有意义，其他平台返回 null
  Future<Directory?> getLegacyDownloadsDir() async {
    await _ensureInitialized();
    if (kIsWeb || !Platform.isAndroid) return null;
    return Directory(path.join(_documentsDir.path, _appFolder, _downloadsFolder));
  }

  /// 获取下载目录
  /// Android: 使用外部存储公共目录 /Music/HaiMusic，卸载应用不会删除
  /// 其他平台: 使用应用文档目录下的 HaiMusic/Downloads
  Future<Directory> getDownloadsDir() async {
    await _ensureInitialized();

    // Android 使用外部存储公共目录，避免卸载后丢失
    if (!kIsWeb && Platform.isAndroid) {
      if (_androidDownloadsDir != null) {
        return _ensureDir(_androidDownloadsDir!);
      }
      final publicMusicDir = _getAndroidPublicMusicDir();
      if (publicMusicDir != null) {
        final downloadDir = Directory(path.join(publicMusicDir.path, _androidPublicMusicFolder));
        _androidDownloadsDir = downloadDir;
        Logger.info('Android 下载目录: ${downloadDir.path} (外部存储，卸载不丢失)', 'StoragePath');
        return _ensureDir(downloadDir);
      }
      // 降级到应用内部目录
      Logger.warning('无法访问外部存储 Music 目录，降级到应用内部目录', 'StoragePath');
    }

    return _ensureDir(Directory(path.join(_documentsDir.path, _appFolder, _downloadsFolder)));
  }

  /// 迁移旧下载目录中的文件到新目录（Android 外部存储）
  /// 返回迁移的文件数量
  Future<int> migrateDownloadsIfNeeded() async {
    if (kIsWeb || !Platform.isAndroid) return 0;

    final publicMusicDir = _getAndroidPublicMusicDir();
    if (publicMusicDir == null) return 0;

    final oldDir = Directory(path.join(_documentsDir.path, _appFolder, _downloadsFolder));
    if (!oldDir.existsSync()) return 0;

    final newDir = Directory(path.join(publicMusicDir.path, _androidPublicMusicFolder));
    int migratedCount = 0;

    try {
      await for (final entity in oldDir.list()) {
        if (entity is File) {
          final fileName = path.basename(entity.path);
          final newPath = path.join(newDir.path, fileName);
          if (!File(newPath).existsSync()) {
            await entity.copy(newPath);
            migratedCount++;
            Logger.info('迁移文件: $fileName -> $newPath', 'StoragePath');
          }
        }
      }

      // 迁移完成后删除旧目录中的文件（仅删除已成功迁移的）
      if (migratedCount > 0) {
        await for (final entity in oldDir.list()) {
          if (entity is File) {
            final fileName = path.basename(entity.path);
            final newPath = path.join(newDir.path, fileName);
            if (File(newPath).existsSync()) {
              await entity.delete();
            }
          }
        }
        // 尝试删除空目录
        if (oldDir.listSync().isEmpty) {
          await oldDir.delete();
        }
        Logger.success('下载目录迁移完成，共迁移 $migratedCount 个文件', 'StoragePath');
      }
    } catch (e) {
      Logger.error('迁移下载目录失败', e, null, 'StoragePath');
    }

    return migratedCount;
  }

  Future<Directory> getMusicAudioDir() async {
    await _ensureInitialized();
    return _ensureDir(Directory(path.join(_documentsDir.path, _musicFolder, _audioFolder)));
  }

  Future<Directory> getMusicCoversDir() async {
    await _ensureInitialized();
    return _ensureDir(Directory(path.join(_documentsDir.path, _musicFolder, _coverFolder)));
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
    return _ensureDir(Directory(path.join(_documentsDir.path, _musicFolder, _lyricsCacheFolder)));
  }
}
