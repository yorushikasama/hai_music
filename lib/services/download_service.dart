import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as path;

import '../extensions/string_extension.dart';
import '../models/downloaded_song.dart';
import '../models/song.dart';
import '../utils/logger.dart';
import 'dio_client.dart';
import 'lyrics_service.dart';
import 'music_api_service.dart';
import 'preferences_service.dart';
import 'storage_path_manager.dart';

class DownloadService {
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;
  DownloadService._internal();

  final Dio _dio = DioClient().dio;
  final _prefsCache = PreferencesService();
  final _lyricsService = LyricsService();
  final _apiService = MusicApiService();
  final _pathManager = StoragePathManager();

  String get _downloadedSongsKey {
    if (kIsWeb) {
      return 'downloaded_songs_web';
    } else if (Platform.isAndroid) {
      return 'downloaded_songs_android';
    } else if (Platform.isIOS) {
      return 'downloaded_songs_ios';
    } else if (Platform.isWindows) {
      return 'downloaded_songs_windows';
    } else if (Platform.isMacOS) {
      return 'downloaded_songs_macos';
    } else if (Platform.isLinux) {
      return 'downloaded_songs_linux';
    } else {
      return 'downloaded_songs_unknown';
    }
  }

  DateTime? _lastFileValidationTime;
  List<DownloadedSong>? _cachedDownloadedSongs;

  Completer<void>? _lock;

  Future<T> _synchronized<T>(Future<T> Function() action) async {
    while (_lock != null) {
      try {
        await _lock!.future;
      } catch (e) {
        Logger.debug('下载锁等待中断', 'Download');
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

  Future<void> init() async {
    await _prefsCache.init();
  }

  Future<Directory> _getDownloadDirectory() async {
    return _pathManager.getDownloadsDir();
  }

  Future<DownloadedSong?> downloadSong(
    Song song, {
    void Function(double)? onProgress,
  }) async {
    return downloadSongWithCancel(song, cancelToken: CancelToken(), onProgress: onProgress);
  }

  Future<DownloadedSong?> downloadSongWithCancel(
    Song song, {
    required CancelToken cancelToken,
    void Function(double)? onProgress,
  }) async {
    try {
      if (song.audioUrl.isEmpty) {
        Logger.error('歌曲 ${song.title} 没有音频URL', null, null, 'Download');
        return null;
      }

      final downloadDir = await _getDownloadDirectory();

      final safeFileName = '${song.title}_${song.artist}'.toSafeFileName();
      final currentQuality = _prefsCache.getAudioQuality();
      final audioFileName = '$safeFileName${currentQuality.fileExtension}';
      final audioFilePath = path.join(downloadDir.path, audioFileName);

      if (File(audioFilePath).existsSync()) {
        Logger.warning('歌曲已存在: $audioFileName', 'Download');
        final downloaded = await getDownloadedSongs();
        return downloaded.firstWhere(
          (d) => d.id == song.id,
          orElse: () => DownloadedSong(
            id: song.id,
            title: song.title,
            artist: song.artist,
            album: song.album,
            coverUrl: song.coverUrl,
            localAudioPath: audioFilePath,
            duration: song.duration,
            platform: song.platform,
            downloadedAt: DateTime.now(),
          ),
        );
      }

      Logger.download('开始下载: ${song.title} - ${song.artist}', 'Download');

      await _dio.download(
        song.audioUrl,
        audioFilePath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            onProgress?.call(received / total);
          }
        },
      );

      String? localCoverPath;
      if (song.coverUrl.isNotEmpty) {
        try {
          final coverFileName = '$safeFileName.jpg';
          localCoverPath = path.join(downloadDir.path, coverFileName);
          await _dio.download(song.coverUrl, localCoverPath);
          Logger.success('封面下载成功', 'Download');
        } catch (e) {
          Logger.warning('封面下载失败: $e', 'Download');
        }
      }

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
          final lyricsFileName = '$safeFileName.lrc';
          localLyricsPath = path.join(downloadDir.path, lyricsFileName);
          File(localLyricsPath).writeAsStringSync(lyrics);
          Logger.success('歌词下载成功', 'Download');

          if (translation != null && translation.isNotEmpty) {
            final transFileName = '${safeFileName}_trans.lrc';
            localTransPath = path.join(downloadDir.path, transFileName);
            File(localTransPath).writeAsStringSync(translation);
            Logger.success('歌词翻译下载成功', 'Download');
          }
        } else {
          Logger.warning('未找到歌词', 'Download');
        }
      } catch (e) {
        Logger.warning('歌词下载失败: $e', 'Download');
      }

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
        duration: song.duration,
        platform: song.platform,
        downloadedAt: DateTime.now(),
      );

      await _saveDownloadedSong(downloadedSong);

      Logger.success('下载完成: ${song.title}', 'Download');

      return downloadedSong;
    } catch (e) {
      Logger.error('下载失败', e, null, 'Download');
      return null;
    }
  }

  Future<void> _saveDownloadedSong(DownloadedSong song) async {
    await _synchronized(() async {
      final downloaded = await getDownloadedSongs();

      downloaded.removeWhere((s) => s.id == song.id);
      downloaded.insert(0, song);

      final jsonList = downloaded.map((s) => s.toJson()).toList();
      await _prefsCache.setString(_downloadedSongsKey, jsonEncode(jsonList));
      _cachedDownloadedSongs = downloaded;
    });
  }

  Future<List<DownloadedSong>> getDownloadedSongs() async {
    try {
      final jsonStr = await _prefsCache.getString(_downloadedSongsKey);
      if (jsonStr == null || jsonStr.isEmpty) {
        return [];
      }

      final List<dynamic> jsonList = jsonDecode(jsonStr) as List<dynamic>;
      final allSongs = jsonList.map((json) => DownloadedSong.fromJson(json as Map<String, dynamic>)).toList();

      final shouldValidate = _cachedDownloadedSongs == null ||
          _lastFileValidationTime == null ||
          DateTime.now().difference(_lastFileValidationTime!).inMinutes >= 5;

      if (!shouldValidate && _cachedDownloadedSongs != null) {
        return _cachedDownloadedSongs!;
      }

      final validSongs = <DownloadedSong>[];
      bool hasInvalidRecords = false;

      for (final song in allSongs) {
        final audioFile = File(song.localAudioPath);
        if (audioFile.existsSync()) {
          validSongs.add(song);
        } else {
          Logger.warning('发现无效记录: ${song.title} (文件不存在)', 'Download');
          hasInvalidRecords = true;
        }
      }

      if (hasInvalidRecords && validSongs.length != allSongs.length) {
        final jsonList = validSongs.map((s) => s.toJson()).toList();
        await _prefsCache.setString(_downloadedSongsKey, jsonEncode(jsonList));
        Logger.success('已清理 ${allSongs.length - validSongs.length} 条无效记录', 'Download');
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
    final downloaded = await getDownloadedSongs();
    final song = downloaded.where((s) => s.id == songId).firstOrNull;

    if (song == null) {
      return false;
    }

    final audioFile = File(song.localAudioPath);
    final exists = audioFile.existsSync();

    if (!exists) {
      Logger.warning('检测到无效记录，文件不存在: ${song.title}', 'Download');
      await _removeInvalidRecord(songId);
      return false;
    }

    return true;
  }

  Future<void> _removeInvalidRecord(String songId) async {
    await _synchronized(() async {
      try {
        final downloaded = await getDownloadedSongs();
        downloaded.removeWhere((s) => s.id == songId);
        final jsonList = downloaded.map((s) => s.toJson()).toList();
        await _prefsCache.setString(_downloadedSongsKey, jsonEncode(jsonList));
        Logger.success('已清理无效记录: $songId', 'Download');
      } catch (e) {
        Logger.error('清理无效记录失败', e, null, 'Download');
      }
    });
  }

  Future<bool> deleteDownloadedSong(String songId) async {
    return _synchronized(() async {
      try {
        final downloaded = await getDownloadedSongs();
        final songIndex = downloaded.indexWhere((s) => s.id == songId);
        if (songIndex == -1) {
          Logger.warning('未找到下载记录: $songId', 'Download');
          return false;
        }
        final song = downloaded[songIndex];

        final audioFile = File(song.localAudioPath);
        if (audioFile.existsSync()) {
          audioFile.deleteSync();
        }

        if (song.localCoverPath != null) {
          final coverFile = File(song.localCoverPath!);
          if (coverFile.existsSync()) {
            coverFile.deleteSync();
          }
        }

        if (song.localLyricsPath != null) {
          final lyricsFile = File(song.localLyricsPath!);
          if (lyricsFile.existsSync()) {
            lyricsFile.deleteSync();
          }
        }

        if (song.localTransPath != null) {
          final transFile = File(song.localTransPath!);
          if (transFile.existsSync()) {
            transFile.deleteSync();
          }
        }

        downloaded.removeWhere((s) => s.id == songId);
        final jsonList = downloaded.map((s) => s.toJson()).toList();
        await _prefsCache.setString(_downloadedSongsKey, jsonEncode(jsonList));

        _cachedDownloadedSongs = null;
        _lastFileValidationTime = null;

        Logger.success('删除成功: ${song.title}', 'Download');
        return true;
      } catch (e) {
        Logger.error('删除失败', e, null, 'Download');
        return false;
      }
    });
  }

  Future<int> getDownloadedSize() async {
    try {
      final downloadDir = await _getDownloadDirectory();
      int totalSize = 0;

      if (downloadDir.existsSync()) {
        await for (final entity in downloadDir.list(recursive: true)) {
          if (entity is File) {
            totalSize += entity.lengthSync();
          }
        }
      }

      return totalSize;
    } catch (e) {
      Logger.error('获取大小失败', e, null, 'Download');
      return 0;
    }
  }

  /// 迁移下载记录中的路径，将旧内部存储路径替换为新外部存储路径
  /// 在 StoragePathManager.migrateDownloadsIfNeeded() 之后调用
  Future<void> migratePathsIfNeeded(String oldDirPath, String newDirPath) async {
    await _synchronized(() async {
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
            downloaded[i] = song.copyWith(
              localAudioPath: newAudioPath,
              localCoverPath: newCoverPath,
              localLyricsPath: newLyricsPath,
              localTransPath: newTransPath,
            );
            hasChanges = true;
          }
        }

        if (hasChanges) {
          final jsonList = downloaded.map((s) => s.toJson()).toList();
          await _prefsCache.setString(_downloadedSongsKey, jsonEncode(jsonList));
          _cachedDownloadedSongs = downloaded;
          Logger.success('已更新 ${downloaded.length} 条下载记录的路径', 'Download');
        }
      } catch (e) {
        Logger.error('迁移下载记录路径失败', e, null, 'Download');
      }
    });
  }

}
