import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../models/downloaded_song.dart';
import '../../models/song.dart';
import '../../utils/logger.dart';
import '../core/core.dart';
import '../lyrics/lyrics.dart';
import '../network/network.dart';
import '../storage/storage.dart';
import 'audio_download_service.dart';
import 'download_database.dart';
import 'download_manager.dart';
import 'download_recovery_service.dart';
import 'download_song_worker.dart';

export 'download_manager.dart' show AddDownloadResult, DownloadStatus, DownloadTask;

class DownloadService {
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;
  DownloadService._internal();

  final _prefsCache = PreferencesService();
  final _lyricsService = LyricsService();
  final _apiService = MusicApiService();
  final _pathManager = StoragePathManager();
  final _db = DownloadDatabase();
  final _mediaScanService = MediaScanService();
  final _audioDownloadService = AudioDownloadService();

  String get _downloadedSongsKey {
    if (kIsWeb) return 'downloaded_songs_web';
    if (Platform.isAndroid) return 'downloaded_songs_android';
    if (Platform.isIOS) return 'downloaded_songs_ios';
    if (Platform.isWindows) return 'downloaded_songs_windows';
    if (Platform.isMacOS) return 'downloaded_songs_macos';
    if (Platform.isLinux) return 'downloaded_songs_linux';
    return 'downloaded_songs_unknown';
  }

  DateTime? _lastFileValidationTime;
  List<DownloadedSong>? _cachedDownloadedSongs;
  bool _migrated = false;

  late final DownloadSongWorker _songWorker = DownloadSongWorker(
    db: _db,
    prefsCache: _prefsCache,
    audioDownloadService: _audioDownloadService,
    pathManager: _pathManager,
    mediaScanService: _mediaScanService,
    lyricsService: _lyricsService,
    apiService: _apiService,
  );

  Future<void> init() async {
    await _prefsCache.init();
    await _migrateFromSharedPreferences();
    await DownloadRecoveryService().recoverIfNeeded();
  }

  Future<void> _migrateFromSharedPreferences() async {
    if (_migrated) return;
    _migrated = true;

    try {
      final dbCount = await _db.getDownloadedCount();
      if (dbCount > 0) return;

      final jsonStr = await _prefsCache.getString(_downloadedSongsKey);
      if (jsonStr == null || jsonStr.isEmpty) return;

      final List<dynamic> jsonList = jsonDecode(jsonStr) as List<dynamic>;
      if (jsonList.isEmpty) return;

      final songs = jsonList
          .map((json) => DownloadedSong.fromJson(json as Map<String, dynamic>))
          .toList();

      if (songs.isNotEmpty) {
        await _db.migrateFromSharedPreferences(songs);
        await _prefsCache.remove(_downloadedSongsKey);
        Logger.success('下载记录已从 SharedPreferences 迁移到 SQLite (${songs.length} 条)', 'Download');
      }
    } catch (e) {
      Logger.warning('SharedPreferences 迁移检查失败: $e', 'Download');
    }
  }

  Future<Directory> getDownloadDirectory() async {
    return _pathManager.getDownloadsDir();
  }

  Future<DownloadedSong?> downloadSongWithCancel(
    Song song, {
    required CancelToken cancelToken,
    void Function(double)? onProgress,
    void Function(int downloaded, int total)? onBytesProgress,
    int resumeFromBytes = 0,
  }) {
    return _songWorker.downloadSongWithCancel(
      song,
      cancelToken: cancelToken,
      onProgress: onProgress,
      onBytesProgress: onBytesProgress,
      resumeFromBytes: resumeFromBytes,
    );
  }

  Future<void> saveDownloadedSong(DownloadedSong song) async {
    await _db.insertDownloadedSong(song);
    _cachedDownloadedSongs = null;
  }

  Future<List<DownloadedSong>> getDownloadedSongs() async {
    try {
      final shouldValidate = _cachedDownloadedSongs == null ||
          _lastFileValidationTime == null ||
          DateTime.now().difference(_lastFileValidationTime!).inMinutes >= 5;

      if (!shouldValidate && _cachedDownloadedSongs != null) {
        return _cachedDownloadedSongs!;
      }

      final allSongs = await _db.getAllDownloadedSongs();

      final existChecks = await Future.wait(
        allSongs.map((song) => File(song.localAudioPath).exists()),
      );

      final validSongs = <DownloadedSong>[];
      final invalidIds = <String>[];

      for (int i = 0; i < allSongs.length; i++) {
        if (existChecks[i]) {
          validSongs.add(allSongs[i]);
        } else {
          Logger.warning('发现无效记录: ${allSongs[i].title} (文件不存在)', 'Download');
          invalidIds.add(allSongs[i].id);
        }
      }

      if (invalidIds.isNotEmpty) {
        for (final id in invalidIds) {
          await _db.deleteDownloadedSong(id);
        }
        Logger.success('已清理 ${invalidIds.length} 条无效记录', 'Download');
      }

      _cachedDownloadedSongs = validSongs;
      _lastFileValidationTime = DateTime.now();

      return validSongs;
    } catch (e) {
      Logger.error('读取下载列表失败', e, null, 'Download');
      return [];
    }
  }

  Future<bool> isDownloaded(String songId) async {
    final song = await _db.getDownloadedSong(songId);
    if (song == null) return false;

    final exists = await File(song.localAudioPath).exists();

    if (!exists) {
      Logger.warning('检测到无效记录，文件不存在: ${song.title}', 'Download');
      await _db.deleteDownloadedSong(songId);
      _cachedDownloadedSongs = null;
      return false;
    }

    return true;
  }

  Future<DeleteResult> deleteSongs(List<DownloadedSong> songs) async {
    if (songs.isEmpty) {
      return const DeleteResult(totalSongs: 0, deletedIds: [], failedIds: []);
    }

    final allFilePaths = <String>[];
    final dbIdsToDelete = <String>[];
    final taskIdsToRemove = <String>[];

    for (final song in songs) {
      if (song.source.isLocal) {
        allFilePaths.addAll(_collectSongFilePaths(song));
        dbIdsToDelete.add(song.id);
      } else {
        allFilePaths.addAll(await _validateFilePaths(_collectSongFilePaths(song)));
        dbIdsToDelete.add(song.id);
        taskIdsToRemove.add(song.id);
      }
    }

    final filesDeleted = await _batchDeleteFiles(allFilePaths);

    if (dbIdsToDelete.isNotEmpty) {
      await _db.batchDeleteDownloadedSongs(dbIdsToDelete);
    }
    _cachedDownloadedSongs = null;
    _lastFileValidationTime = null;

    final downloadManager = DownloadManager();
    for (final id in taskIdsToRemove) {
      downloadManager.removeTask(id);
    }

    if (Platform.isAndroid) {
      for (final song in songs) {
        _mediaScanService.scanFile(song.localAudioPath);
      }
    }

    final failedIds = filesDeleted ? <String>[] : songs.map((s) => s.id).toList();
    final deletedIds = filesDeleted ? songs.map((s) => s.id).toList() : <String>[];

    Logger.info('删除完成: ${songs.length}首, 成功${deletedIds.length}首, 失败${failedIds.length}首', 'Download');

    return DeleteResult(totalSongs: songs.length, deletedIds: deletedIds, failedIds: failedIds);
  }

  List<String> _collectSongFilePaths(DownloadedSong song) {
    final paths = <String>[];
    if (song.localAudioPath.isNotEmpty) paths.add(song.localAudioPath);
    if (song.localCoverPath != null && song.localCoverPath!.isNotEmpty) {
      paths.add(song.localCoverPath!);
    }
    if (song.localLyricsPath != null && song.localLyricsPath!.isNotEmpty) {
      paths.add(song.localLyricsPath!);
    }
    if (song.localTransPath != null && song.localTransPath!.isNotEmpty) {
      paths.add(song.localTransPath!);
    }
    return paths;
  }

  Future<List<String>> _validateFilePaths(List<String> paths) async {
    final validPaths = <String>[];
    for (final filePath in paths) {
      final isWithin = await _pathManager.isPathWithinManagedDir(filePath);
      if (isWithin) {
        validPaths.add(filePath);
      } else {
        Logger.warning('路径不在应用管理目录内，跳过删除: $filePath', 'Download');
      }
    }
    return validPaths;
  }

  Future<bool> _batchDeleteFiles(List<String> filePaths) async {
    if (filePaths.isEmpty) return true;

    final needPlatformDelete = <String>[];

    for (final filePath in filePaths) {
      final file = File(filePath);
      if (!await file.exists()) {
        continue;
      }
      try {
        await file.delete();
      } catch (e) {
        Logger.warning('Dart文件删除失败: $filePath', 'Download');
        needPlatformDelete.add(filePath);
      }
    }

    if (needPlatformDelete.isEmpty) return true;

    final platformResult = await _mediaScanService.deleteFiles(needPlatformDelete);
    if (platformResult) return true;

    int remainingFiles = 0;
    for (final filePath in needPlatformDelete) {
      if (await File(filePath).exists()) remainingFiles++;
    }

    if (remainingFiles == 0) return true;

    Logger.warning('部分文件删除失败: $remainingFiles/${filePaths.length}个文件仍存在', 'Download');
    return false;
  }

  Future<int> getDownloadedSize() async {
    try {
      final dbSize = await _db.getDownloadedSize();
      if (dbSize > 0) return dbSize;

      final downloadDir = await _pathManager.getDownloadsDir();
      int totalSize = 0;

      if (await downloadDir.exists()) {
        await for (final entity in downloadDir.list(recursive: true)) {
          if (entity is File) {
            totalSize += await entity.length();
          }
        }
      }

      return totalSize;
    } catch (e) {
      Logger.error('获取大小失败', e, null, 'Download');
      return 0;
    }
  }

  Future<Map<String, int>> getSizeByQuality() async => _db.getSizeByQuality();
  Future<int> getDownloadedCount() async => _db.getDownloadedCount();
  Future<List<DownloadedSong>> getLocalSongs() async => _db.getSongsBySource('local');

  Future<DownloadedSong?> getDownloadedSongById(String songId) async {
    final song = await _db.getDownloadedSong(songId);
    if (song != null) return song;
    final localSongs = await _db.getSongsBySource('local');
    return localSongs.where((s) => s.id == songId).firstOrNull;
  }

  Future<void> saveLocalSongs(List<DownloadedSong> songs) async {
    final existing = await _db.getSongsBySource('local');
    final existingIds = existing.map((s) => s.id).toList();
    if (existingIds.isNotEmpty) {
      await _db.batchDeleteDownloadedSongs(existingIds);
    }
    for (final song in songs) {
      await _db.insertDownloadedSong(song);
    }
    _cachedDownloadedSongs = null;
    _lastFileValidationTime = null;
  }

  Future<AddDownloadResult> addDownload(Song song) async {
    final manager = DownloadManager();
    await manager.init();
    return manager.addDownload(song);
  }

  set maxConcurrentDownloads(int value) {
    DownloadManager().maxConcurrent = value;
  }

  Future<bool> getWifiOnlyDownload() async {
    await _prefsCache.init();
    return _prefsCache.getWifiOnlyDownload();
  }

  Future<bool> setWifiOnlyDownload(bool value) async {
    await _prefsCache.init();
    return _prefsCache.setWifiOnlyDownload(value);
  }

  Future<int> getMaxConcurrentDownloads() async {
    await _prefsCache.init();
    return _prefsCache.getMaxConcurrentDownloads();
  }

  Future<bool> setMaxConcurrentDownloads(int value) async {
    await _prefsCache.init();
    final result = await _prefsCache.setMaxConcurrentDownloads(value);
    maxConcurrentDownloads = value;
    return result;
  }

  Future<List<DownloadedSong>> scanLocalAudio() async {
    return LocalAudioScanner().scanAllAudio();
  }

  Future<void> persistCover(String songId, String imageUrl) async {
    await CoverPersistenceService().persistCover(songId, imageUrl);
  }

  Future<String?> getDatabasePath() async => _db.getDatabasePath();

  Future<void> closeDatabase() async {
    await _db.close();
    _cachedDownloadedSongs = null;
    _lastFileValidationTime = null;
  }

  Future<BatchDownloadResult> batchAddDownloads(List<Song> songs) async {
    if (songs.isEmpty) {
      return const BatchDownloadResult(total: 0, added: 0, alreadyExists: 0, failed: 0);
    }

    final manager = DownloadManager();
    await manager.init();

    int added = 0;
    int alreadyExists = 0;
    int failed = 0;

    for (final song in songs) {
      try {
        final result = await manager.addDownload(song);
        switch (result) {
          case AddDownloadResult.added:
          case AddDownloadResult.qualityUpgraded:
            added++;
          case AddDownloadResult.alreadyExists:
            alreadyExists++;
          case AddDownloadResult.wifiRequired:
          case AddDownloadResult.storageInsufficient:
            failed++;
        }
      } catch (e) {
        Logger.error('批量下载失败', e, null, 'Download');
        failed++;
      }
    }

    return BatchDownloadResult(
      total: songs.length,
      added: added,
      alreadyExists: alreadyExists,
      failed: failed,
    );
  }

  Future<void> migratePathsIfNeeded(String oldDirPath, String newDirPath) async {
    try {
      final downloaded = await getDownloadedSongs();
      bool hasChanges = false;

      for (int i = 0; i < downloaded.length; i++) {
        final song = downloaded[i];
        String? newAudioPath;
        String? newCoverPath;
        String? newLyricsPath;
        String? newTransPath;

        if (song.localAudioPath.startsWith(oldDirPath)) {
          newAudioPath = song.localAudioPath.replaceFirst(oldDirPath, newDirPath);
        }
        if (song.localCoverPath != null && song.localCoverPath!.startsWith(oldDirPath)) {
          newCoverPath = song.localCoverPath!.replaceFirst(oldDirPath, newDirPath);
        }
        if (song.localLyricsPath != null && song.localLyricsPath!.startsWith(oldDirPath)) {
          newLyricsPath = song.localLyricsPath!.replaceFirst(oldDirPath, newDirPath);
        }
        if (song.localTransPath != null && song.localTransPath!.startsWith(oldDirPath)) {
          newTransPath = song.localTransPath!.replaceFirst(oldDirPath, newDirPath);
        }

        if (newAudioPath != null || newCoverPath != null || newLyricsPath != null || newTransPath != null) {
          final updated = song.copyWith(
            localAudioPath: newAudioPath,
            localCoverPath: newCoverPath,
            localLyricsPath: newLyricsPath,
            localTransPath: newTransPath,
          );
          await _db.insertDownloadedSong(updated);
          hasChanges = true;
        }
      }

      if (hasChanges) {
        _cachedDownloadedSongs = null;
        Logger.success('已更新下载记录的路径', 'Download');
      }
    } catch (e) {
      Logger.error('迁移下载记录路径失败', e, null, 'Download');
    }
  }
}

class DeleteResult {
  final int totalSongs;
  final List<String> deletedIds;
  final List<String> failedIds;

  bool get allSuccess => failedIds.isEmpty;

  const DeleteResult({
    required this.totalSongs,
    required this.deletedIds,
    required this.failedIds,
  });
}

class BatchDownloadResult {
  final int total;
  final int added;
  final int alreadyExists;
  final int failed;

  bool get allAdded => failed == 0 && alreadyExists == 0;

  const BatchDownloadResult({
    required this.total,
    required this.added,
    required this.alreadyExists,
    required this.failed,
  });
}
