import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;

import '../../utils/format_utils.dart';
import '../../utils/logger.dart';
import '../core/core.dart';

/// 封面持久化服务
///
/// 负责封面图片的下载、复制、索引和删除，确保封面在应用重装后仍然可用。
/// 采用双路径策略: Music/HaiMusic/covers(主路径) + Pictures/HaiMusic/covers(Android 16 回退路径)。
/// 在 Android 16+ 上，Dart File API 写入失败时自动回退到平台通道(MediaStore API)。
class CoverPersistenceService {
  static final CoverPersistenceService _instance =
      CoverPersistenceService._internal();
  factory CoverPersistenceService() => _instance;
  CoverPersistenceService._internal();

  final StoragePathManager _pathManager = StoragePathManager();
  final PreferencesService _prefs = PreferencesService();
  final Dio _dio = DioClient().dio;
  final _mediaScanService = MediaScanService();

  static const String _indexKey = 'cover_persistence_index';

  Map<String, String> _index = {};
  bool _initialized = false;
  Completer<void>? _initCompleter;

  Future<void> init() async {
    if (_initialized) return;
    _initCompleter ??= Completer<void>();
    if (_initCompleter!.isCompleted) return;

    try {
      await _prefs.init();
      await _loadIndex();
      _initialized = true;
      _initCompleter!.complete();
      Logger.info('封面持久化服务初始化完成，已索引 ${_index.length} 个封面', 'CoverPersist');
    } catch (e) {
      _initCompleter!.completeError(e);
      _initCompleter = null;
      rethrow;
    }
  }

  Future<void> _loadIndex() async {
    try {
      final jsonStr = await _prefs.getString(_indexKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final Map<String, dynamic> decoded =
            jsonDecode(jsonStr) as Map<String, dynamic>;
        _index = decoded.map((k, v) => MapEntry(k, v as String));
      }
    } catch (e) {
      Logger.warning('加载封面索引失败: $e', 'CoverPersist');
      _index = {};
    }
  }

  Future<void> _saveIndex() async {
    try {
      await _prefs.setString(_indexKey, jsonEncode(_index));
    } catch (e) {
      Logger.error('保存封面索引失败', e, null, 'CoverPersist');
    }
  }

  Future<String?> getLocalCoverPath(String songId) async {
    if (!_initialized) await init();

    final localPath = _index[songId];
    if (localPath == null) return null;

    final file = File(localPath);
    if (await file.exists()) return localPath;

    Logger.cache('封面文件不存在，移除索引: $songId', 'CoverPersist');
    _index.remove(songId);
    await _saveIndex();
    return null;
  }

  Future<String?> persistCover(String songId, String coverUrl) async {
    if (!_initialized) await init();

    if (coverUrl.isEmpty) return null;

    try {
      final existing = await getLocalCoverPath(songId);
      if (existing != null) {
        Logger.cache('封面已持久化: $songId', 'CoverPersist');
        return existing;
      }

      if (coverUrl.startsWith('file://')) {
        final filePath = Uri.parse(coverUrl).toFilePath();
        final sourceFile = File(filePath);
        if (await sourceFile.exists()) {
          final savedPath = await _copyToPersistentDir(songId, sourceFile);
          if (savedPath != null) {
            _index[songId] = savedPath;
            await _saveIndex();
            Logger.success('本地封面已持久化: $songId', 'CoverPersist');
          }
          return savedPath;
        }
        return null;
      }

      final coverDir = await _pathManager.getMusicCoversDir();
      final targetPath = path.join(coverDir.path, '$songId.jpg');
      final targetFile = File(targetPath);

      try {
        await _dio.download(coverUrl, targetPath);

        if (await targetFile.exists()) {
          final size = await targetFile.length();
          if (size > 0) {
            _index[songId] = targetPath;
            await _saveIndex();
            Logger.success(
                '封面持久化成功: $songId (${FormatUtils.formatSize(size)})', 'CoverPersist');
            return targetPath;
          } else {
            await targetFile.delete();
            Logger.warning('下载的封面文件为空: $songId', 'CoverPersist');
          }
        }
      } catch (e) {
        Logger.warning('Dart下载封面失败，尝试平台通道: $songId', 'CoverPersist');
      }

      try {
        final response = await _dio.get<List<int>>(
          coverUrl,
          options: Options(responseType: ResponseType.bytes),
        );
        final bytes = Uint8List.fromList(response.data!);
        final picturesDir = await _pathManager.getPicturesCoversDir();
        final picturesPath = path.join(picturesDir.path, '$songId.jpg');
        final savedPath = await _mediaScanService.saveFile(picturesPath, bytes);
        if (savedPath != null) {
          _index[songId] = savedPath;
          await _saveIndex();
          Logger.success(
              '封面持久化成功(平台通道): $songId (${FormatUtils.formatSize(bytes.length)})', 'CoverPersist');
          return savedPath;
        }
      } catch (e) {
        Logger.error('平台通道封面持久化失败: $songId', e, null, 'CoverPersist');
      }

      return null;
    } catch (e) {
      Logger.error('封面持久化失败: $songId', e, null, 'CoverPersist');
      return null;
    }
  }

  Future<String?> persistCoverFromBytes(
      String songId, List<int> bytes) async {
    if (!_initialized) await init();

    if (bytes.isEmpty) return null;

    try {
      final existing = await getLocalCoverPath(songId);
      if (existing != null) return existing;

      final coverDir = await _pathManager.getMusicCoversDir();
      final targetPath = path.join(coverDir.path, '$songId.jpg');
      final targetFile = File(targetPath);

      try {
        await targetFile.writeAsBytes(bytes);
        _index[songId] = targetPath;
        await _saveIndex();
        Logger.success(
            '封面字节持久化成功: $songId (${FormatUtils.formatSize(bytes.length)})',
            'CoverPersist');
        return targetPath;
      } catch (e) {
        Logger.warning('Dart写入封面失败，尝试平台通道: $songId', 'CoverPersist');
      }

      try {
        final picturesDir = await _pathManager.getPicturesCoversDir();
        final picturesPath = path.join(picturesDir.path, '$songId.jpg');
        final savedPath = await _mediaScanService.saveFile(
          picturesPath,
          Uint8List.fromList(bytes),
        );
        if (savedPath != null) {
          _index[songId] = savedPath;
          await _saveIndex();
          Logger.success(
              '封面字节持久化成功(平台通道): $songId (${FormatUtils.formatSize(bytes.length)})',
              'CoverPersist');
          return savedPath;
        }
      } catch (e) {
        Logger.error('平台通道封面字节持久化失败: $songId', e, null, 'CoverPersist');
      }

      return null;
    } catch (e) {
      Logger.error('封面字节持久化失败: $songId', e, null, 'CoverPersist');
      return null;
    }
  }

  Future<String?> _copyToPersistentDir(String songId, File sourceFile) async {
    try {
      final coverDir = await _pathManager.getMusicCoversDir();
      final ext = path.extension(sourceFile.path);
      final targetPath = path.join(coverDir.path, '$songId$ext');
      await sourceFile.copy(targetPath);
      return targetPath;
    } catch (e) {
      Logger.error('复制封面到持久化目录失败', e, null, 'CoverPersist');
      return null;
    }
  }

  Future<bool> deleteCover(String songId) async {
    if (!_initialized) await init();

    final localPath = _index.remove(songId);
    if (localPath == null) return true;

    bool fileDeleted = true;
    try {
      final file = File(localPath);
      if (await file.exists()) {
        try {
          await file.delete();
          Logger.info('封面已删除: $songId', 'CoverPersist');
        } catch (e) {
          Logger.warning('Dart删除封面失败，尝试平台通道: $songId', 'CoverPersist');
          final deleted = await _mediaScanService.deleteFile(localPath);
          if (deleted) {
            Logger.info('封面已删除(平台通道): $songId', 'CoverPersist');
          } else {
            Logger.warning('平台通道删除封面也失败: $songId', 'CoverPersist');
            fileDeleted = false;
          }
        }
      }
      await _saveIndex();
      if (!fileDeleted) {
        // 文件删除失败，恢复索引以便后续重试
        _index[songId] = localPath;
        await _saveIndex();
        return false;
      }
      return true;
    } catch (e) {
      Logger.error('删除封面失败: $songId', e, null, 'CoverPersist');
      // 恢复索引
      _index[songId] = localPath;
      return false;
    }
  }

  Future<void> rebuildIndex() async {
    if (!_initialized) await init();

    Logger.info('开始重建封面持久化索引...', 'CoverPersist');
    _index.clear();

    try {
      int count = 0;

      final coverDir = await _pathManager.getMusicCoversDir();
      count += await _scanCoverDir(coverDir);

      try {
        final picturesDir = await _pathManager.getPicturesCoversDir();
        if (picturesDir.path != coverDir.path) {
          count += await _scanCoverDir(picturesDir);
        }
      } catch (_) {}

      await _saveIndex();
      Logger.success('封面索引重建完成，共 $count 个封面', 'CoverPersist');
    } catch (e) {
      Logger.error('重建封面索引失败', e, null, 'CoverPersist');
    }
  }

  Future<int> getPersistentCoverCount() async {
    if (!_initialized) await init();
    return _index.length;
  }

  Future<int> getPersistentCoverSize() async {
    if (!_initialized) await init();

    int totalSize = 0;
    for (final localPath in _index.values) {
      try {
        final file = File(localPath);
        if (await file.exists()) {
          totalSize += await file.length();
        }
      } catch (_) {}
    }
    return totalSize;
  }

  Future<void> clearAll() async {
    if (!_initialized) await init();

    Logger.info('开始清除所有持久化封面...', 'CoverPersist');

    final dartDeleted = <String>[];
    final needPlatformDelete = <String>[];

    for (final localPath in _index.values) {
      try {
        final file = File(localPath);
        if (await file.exists()) {
          try {
            await file.delete();
            dartDeleted.add(localPath);
          } catch (e) {
            needPlatformDelete.add(localPath);
          }
        }
      } catch (e) {
        Logger.warning('检查封面文件失败: $localPath', 'CoverPersist');
      }
    }

    if (needPlatformDelete.isNotEmpty) {
      try {
        await _mediaScanService.deleteFiles(needPlatformDelete);
      } catch (e) {
        Logger.warning('批量删除封面失败: ${needPlatformDelete.length}个文件', 'CoverPersist');
      }
    }

    _index.clear();
    await _saveIndex();
    Logger.success('所有持久化封面已清除', 'CoverPersist');
  }

  Future<int> _scanCoverDir(Directory dir) async {
    if (!await dir.exists()) return 0;
    int count = 0;
    await for (final entity in dir.list()) {
      if (entity is File) {
        final ext = path.extension(entity.path).toLowerCase();
        if (ext == '.jpg' || ext == '.jpeg' || ext == '.png' || ext == '.webp') {
          final fileName = path.basenameWithoutExtension(entity.path);
          _index[fileName] = entity.path;
          count++;
        }
      }
    }
    return count;
  }

}
