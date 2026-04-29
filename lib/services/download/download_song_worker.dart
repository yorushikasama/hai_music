import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart' as audio_meta;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as path;

import '../../extensions/string_extension.dart';
import '../../models/downloaded_song.dart';
import '../../models/song.dart';
import '../../utils/logger.dart';
import '../core/core.dart';
import '../lyrics/lyrics.dart';
import '../network/network.dart';
import '../storage/storage.dart';
import 'audio_download_service.dart';
import 'audio_metadata_service.dart';
import 'download_database.dart';

/// 歌曲下载工作器，负责单首歌曲的完整下载流程
///
/// 包含音频下载、封面下载、元数据写入、歌词获取和记录保存等步骤。
/// 支持取消检查，每个关键步骤前验证 CancelToken 状态。
class DownloadSongWorker {
  final DownloadDatabase _db;
  final PreferencesService _prefsCache;
  final AudioDownloadService _audioDownloadService;
  final StoragePathManager _pathManager;
  final MediaScanService _mediaScanService;
  final LyricsService _lyricsService;
  final MusicApiService _apiService;

  DownloadSongWorker({
    required DownloadDatabase db,
    required PreferencesService prefsCache,
    required AudioDownloadService audioDownloadService,
    required StoragePathManager pathManager,
    required MediaScanService mediaScanService,
    required LyricsService lyricsService,
    required MusicApiService apiService,
  })  : _db = db,
        _prefsCache = prefsCache,
        _audioDownloadService = audioDownloadService,
        _pathManager = pathManager,
        _mediaScanService = mediaScanService,
        _lyricsService = lyricsService,
        _apiService = apiService;

  /// 下载歌曲（完整版，支持取消和断点续传）
  ///
  /// 每个关键步骤前检查取消状态，避免取消后继续执行无用操作。
  /// 返回下载完成的 [DownloadedSong]，失败或取消返回 null。
  Future<DownloadedSong?> downloadSongWithCancel(
    Song song, {
    required CancelToken cancelToken,
    void Function(double)? onProgress,
    void Function(int downloaded, int total)? onBytesProgress,
    int resumeFromBytes = 0,
  }) async {
    String? audioFilePath;
    String? localCoverPath;
    String? localLyricsPath;
    String? localTransPath;
    try {
      if (song.audioUrl.isEmpty) {
        Logger.error('歌曲 ${song.title} 没有音频URL', null, null, 'Download');
        return null;
      }

      final downloadDir = await _pathManager.getDownloadsDir();

      final rawFileName = '${song.artist} - ${song.title}'.toSafeFileName().toTruncated();
      final currentQuality = await _prefsCache.getAudioQuality();
      final audioFileName = '$rawFileName${currentQuality.fileExtension}';
      audioFilePath = path.join(downloadDir.path, audioFileName);

      final audioFile = File(audioFilePath);
      if (await audioFile.exists()) {
        Logger.warning('歌曲已存在: $audioFileName', 'Download');
        final existing = await _db.getDownloadedSong(song.id);
        if (existing != null) return existing;

        Logger.warning('发现无记录的残留文件，删除后重新下载: $audioFileName', 'Download');
        final deleted = await _tryDeleteFile(audioFilePath);
        if (!deleted) {
          Logger.error('无法删除残留文件，跳过下载: $audioFileName', null, null, 'Download');
          return null;
        }
      }

      Logger.download('开始下载: ${song.title} - ${song.artist}', 'Download');

      final audioResult = await _audioDownloadService.downloadAudio(
        song: song,
        targetPath: audioFilePath,
        cancelToken: cancelToken,
        resumeFromBytes: resumeFromBytes,
        onProgress: (received, total) {
          onBytesProgress?.call(received, total);
          if (total != -1) {
            onProgress?.call(received / total);
          }
        },
      );

      if (audioResult == null) return null;

      if (cancelToken.isCancelled) {
        await _tryDeleteFile(audioFilePath);
        return null;
      }

      final actualFileSize = await audioFile.length();

      final actualDuration = await _readAudioDuration(audioFilePath, song.duration, actualFileSize);

      localCoverPath = await _downloadCover(song, rawFileName, downloadDir.path);
      if (localCoverPath == null && song.coverUrl.isNotEmpty) {
        localCoverPath = null;
      }

      if (cancelToken.isCancelled) {
        final cleanupPaths = <String>[audioFilePath];
        if (localCoverPath != null) cleanupPaths.add(localCoverPath);
        await _batchDeleteFiles(cleanupPaths);
        return null;
      }

      await _writeAudioMetadata(audioFilePath, song, localCoverPath);

      if (cancelToken.isCancelled) {
        final cleanupPaths = <String>[audioFilePath];
        if (localCoverPath != null) cleanupPaths.add(localCoverPath);
        await _batchDeleteFiles(cleanupPaths);
        return null;
      }

      final lyricsResult = await _downloadLyrics(song, rawFileName, downloadDir.path);
      localLyricsPath = lyricsResult['lyricsPath'];
      localTransPath = lyricsResult['transPath'];

      final fileSize = await audioFile.exists() ? await audioFile.length() : null;

      final downloadedSong = DownloadedSong(
        id: song.id,
        title: song.title,
        artist: song.artist,
        album: song.album,
        coverUrl: song.coverUrl,
        localAudioPath: audioFilePath,
        localCoverPath: localCoverPath,
        localLyricsPath: localLyricsPath,
        localTransPath: localTransPath,
        duration: song.duration ?? actualDuration,
        platform: song.platform,
        downloadedAt: DateTime.now(),
        audioQualityValue: currentQuality.value,
        fileSize: fileSize,
      );

      final existingSong = await _db.getDownloadedSong(song.id);
      if (existingSong != null && existingSong.localAudioPath != audioFilePath) {
        await _batchDeleteFiles(_collectSongFilePaths(existingSong));
      }

      await _db.insertDownloadedSong(downloadedSong);

      _notifyMediaStore(audioFilePath, localCoverPath, localLyricsPath);

      Logger.success('下载完成: ${song.title}', 'Download');

      return downloadedSong;
    } catch (e) {
      Logger.error('下载失败', e, null, 'Download');
      try {
        final cleanupPaths = <String>[];
        if (audioFilePath != null) cleanupPaths.add(audioFilePath);
        if (localCoverPath != null) cleanupPaths.add(localCoverPath);
        if (localLyricsPath != null) cleanupPaths.add(localLyricsPath);
        if (localTransPath != null) cleanupPaths.add(localTransPath);
        if (cleanupPaths.isNotEmpty) await _batchDeleteFiles(cleanupPaths);
      } catch (_) {}
      return null;
    }
  }

  Future<int?> _readAudioDuration(String audioFilePath, int? expectedDuration, int fileSize) async {
    int? actualDuration;
    try {
      final metadata = audio_meta.readMetadata(File(audioFilePath));
      actualDuration = metadata.duration?.inSeconds;
      Logger.info('音频元数据时长: $actualDuration秒, 预期时长: $expectedDuration秒, 文件大小: $fileSize字节', 'Download');
    } catch (e) {
      Logger.warning('读取音频元数据失败: $e', 'Download');
    }

    if (actualDuration == null && !kIsWeb && Platform.isAndroid) {
      try {
        final nativeMeta = await _mediaScanService.getMetadata(audioFilePath);
        if (nativeMeta != null && nativeMeta['duration'] != null && nativeMeta['duration']!.isNotEmpty) {
          final ms = int.tryParse(nativeMeta['duration'] ?? '');
          if (ms != null && ms > 0) {
            actualDuration = ms ~/ 1000;
            Logger.info('原生通道读取时长: $actualDuration秒', 'Download');
          }
        }
      } catch (e) {
        Logger.warning('原生通道读取时长失败: $e', 'Download');
      }
    }
    return actualDuration;
  }

  Future<String?> _downloadCover(Song song, String rawFileName, String downloadDirPath) async {
    if (song.coverUrl.isEmpty) return null;
    try {
      final coverFileName = '$rawFileName.jpg';
      final localCoverPath = path.join(downloadDirPath, coverFileName);
      final coverFile = await _audioDownloadService.downloadCover(
        coverUrl: song.coverUrl,
        targetPath: localCoverPath,
      );
      if (coverFile != null) {
        Logger.success('封面下载成功', 'Download');
        unawaited(CoverPersistenceService()
            .persistCover(song.id, song.coverUrl)
            .catchError((e) {
          Logger.cache('下载流程封面持久化失败: ${song.id}', 'Download');
          return null;
        }));
        return localCoverPath;
      }
      return null;
    } catch (e) {
      Logger.warning('封面下载失败: $e', 'Download');
      return null;
    }
  }

  Future<void> _writeAudioMetadata(
    String audioFilePath,
    Song song,
    String? localCoverPath,
  ) async {
    Uint8List? coverBytes;
    if (localCoverPath != null) {
      try {
        final coverFile = File(localCoverPath);
        final coverSize = await coverFile.length();
        if (coverSize <= 5 * 1024 * 1024) {
          coverBytes = await coverFile.readAsBytes();
        } else {
          Logger.warning('封面文件过大(${(coverSize / 1024 / 1024).toStringAsFixed(1)}MB)，跳过嵌入元数据', 'Download');
        }
      } catch (e) {
        Logger.warning('读取封面数据失败: $e', 'Download');
      }
    }

    await AudioMetadataService().writeMetadata(
      audioFilePath: audioFilePath,
      title: song.title,
      artist: song.artist,
      album: song.album,
      coverBytes: coverBytes,
      duration: song.duration,
    );
  }

  Future<Map<String, String?>> _downloadLyrics(Song song, String rawFileName, String downloadDirPath) async {
    String? localLyricsPath;
    String? localTransPath;

    try {
      String? lyrics = song.lyricsLrc;
      String? translation = song.lyricsTrans;

      if (lyrics == null || lyrics.isEmpty) {
        final dbLyrics = await _lyricsService.getLyricsWithTranslation(song.id);
        if (dbLyrics != null) {
          lyrics = dbLyrics['lrc'];
          translation = dbLyrics['trans'];
        }
      }

      if (lyrics == null || lyrics.isEmpty) {
        final apiLyrics = await _apiService.getLyricsWithTranslation(songId: song.id);
        if (apiLyrics != null) {
          lyrics = apiLyrics['lrc'];
          translation = apiLyrics['trans'];
          if (lyrics != null && lyrics.isNotEmpty) {
            await _lyricsService.saveLyrics(
              songId: song.id,
              lyrics: lyrics,
              title: song.title,
              artist: song.artist,
              translation: translation,
            );
          }
        }
      }

      if (lyrics != null && lyrics.isNotEmpty) {
        final lyricsFileName = '$rawFileName.lrc';
        localLyricsPath = path.join(downloadDirPath, lyricsFileName);
        await File(localLyricsPath).writeAsString(lyrics);
        Logger.success('歌词下载成功', 'Download');

        if (translation != null && translation.isNotEmpty) {
          final transFileName = '${rawFileName}_trans.lrc';
          localTransPath = path.join(downloadDirPath, transFileName);
          await File(localTransPath).writeAsString(translation);
          Logger.success('歌词翻译下载成功', 'Download');
        }
      } else {
        Logger.warning('未找到歌词', 'Download');
      }
    } catch (e) {
      Logger.warning('歌词下载失败: $e', 'Download');
    }

    return {'lyricsPath': localLyricsPath, 'transPath': localTransPath};
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

  Future<bool> _tryDeleteFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return true;
    try {
      await file.delete();
      return true;
    } catch (e) {
      Logger.warning('Dart文件删除失败: $filePath', 'Download');
    }
    return _mediaScanService.deleteFile(filePath);
  }

  Future<bool> _batchDeleteFiles(List<String> filePaths) async {
    if (filePaths.isEmpty) return true;

    final successfullyDeleted = <String>[];
    final needPlatformDelete = <String>[];

    for (final filePath in filePaths) {
      final file = File(filePath);
      if (!await file.exists()) {
        successfullyDeleted.add(filePath);
        continue;
      }
      try {
        await file.delete();
        successfullyDeleted.add(filePath);
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
      if (await File(filePath).exists()) {
        remainingFiles++;
      }
    }

    if (remainingFiles == 0) return true;

    Logger.warning('部分文件删除失败: $remainingFiles/${filePaths.length}个文件仍存在', 'Download');
    return false;
  }

  void _notifyMediaStore(String audioPath, String? coverPath, String? lyricsPath) {
    if (kIsWeb || !Platform.isAndroid) return;

    _mediaScanService.scanFile(audioPath);
    if (coverPath != null) {
      _mediaScanService.scanFile(coverPath);
    }
    if (lyricsPath != null) {
      _mediaScanService.scanFile(lyricsPath);
    }
  }
}
