import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/song.dart';
import '../models/downloaded_song.dart';
import 'preferences_cache_service.dart';
import 'lyrics_service.dart';
import 'music_api_service.dart';
import '../utils/logger.dart';

/// 歌曲下载服务
class DownloadService {
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;
  DownloadService._internal();

  final Dio _dio = Dio();
  final _prefsCache = PreferencesCacheService();
  final _lyricsService = LyricsService();
  final _apiService = MusicApiService();
  
  // 根据平台使用不同的存储键，确保各平台数据隔离
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
  
  // 下载进度回调
  final Map<String, double> _downloadProgress = {};
  
  /// 初始化
  Future<void> init() async {
    await _prefsCache.init();
  }

  /// 获取下载目录
  Future<Directory> _getDownloadDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final downloadDir = Directory(path.join(appDir.path, 'HaiMusic', 'Downloads'));
    
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }
    
    return downloadDir;
  }

  /// 下载歌曲
  Future<DownloadedSong?> downloadSong(
    Song song, {
    Function(double)? onProgress,
  }) async {
    try {
      if (song.audioUrl.isEmpty) {
        Logger.error('歌曲 ${song.title} 没有音频URL', null, null, 'Download');
        return null;
      }

      final downloadDir = await _getDownloadDirectory();
      
      // 创建安全的文件名
      final safeFileName = _sanitizeFileName('${song.title}_${song.artist}');
      final audioFileName = '$safeFileName.mp3';
      final audioFilePath = path.join(downloadDir.path, audioFileName);
      
      // 检查是否已下载
      if (await File(audioFilePath).exists()) {
        Logger.warning('歌曲已存在: $audioFileName', 'Download');
        // 返回已存在的下载记录
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
      
      // 下载音频文件
      await _dio.download(
        song.audioUrl,
        audioFilePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            _downloadProgress[song.id] = progress;
            onProgress?.call(progress);
          }
        },
      );

      // 下载封面（可选）
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

      // 下载歌词（可选）
      String? localLyricsPath;
      try {
        // 1. 优先使用 Song 对象中的歌词
        String? lyrics = song.lyricsLrc;
        
        // 2. 如果没有，从数据库获取
        if (lyrics == null || lyrics.isEmpty) {
          lyrics = await _lyricsService.getLyrics(song.id);
        }
        
        // 3. 如果还是没有，从 API 获取
        if (lyrics == null || lyrics.isEmpty) {
          lyrics = await _apiService.getLyrics(songId: song.id);
          // 保存到数据库供下次使用
          if (lyrics != null && lyrics.isNotEmpty) {
            await _lyricsService.saveLyrics(
              songId: song.id,
              lyrics: lyrics,
              title: song.title,
              artist: song.artist,
            );
          }
        }
        
        // 4. 保存歌词到本地文件
        if (lyrics != null && lyrics.isNotEmpty) {
          final lyricsFileName = '$safeFileName.lrc';
          localLyricsPath = path.join(downloadDir.path, lyricsFileName);
          await File(localLyricsPath).writeAsString(lyrics, encoding: utf8);
          Logger.success('歌词下载成功', 'Download');
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
        duration: song.duration,
        platform: song.platform,
        downloadedAt: DateTime.now(),
      );

      // 保存到本地记录
      await _saveDownloadedSong(downloadedSong);
      
      _downloadProgress.remove(song.id);
      Logger.success('下载完成: ${song.title}', 'Download');
      
      return downloadedSong;
    } catch (e) {
      Logger.error('下载失败', e, null, 'Download');
      _downloadProgress.remove(song.id);
      return null;
    }
  }

  /// 获取下载进度
  double? getDownloadProgress(String songId) {
    return _downloadProgress[songId];
  }

  /// 保存下载记录
  Future<void> _saveDownloadedSong(DownloadedSong song) async {
    final downloaded = await getDownloadedSongs();
    
    // 避免重复
    downloaded.removeWhere((s) => s.id == song.id);
    downloaded.insert(0, song);
    
    final jsonList = downloaded.map((s) => s.toJson()).toList();
    await _prefsCache.setString(_downloadedSongsKey, jsonEncode(jsonList));
  }

  /// 获取所有下载的歌曲（自动过滤无效记录）
  Future<List<DownloadedSong>> getDownloadedSongs() async {
    try {
      final jsonStr = await _prefsCache.getString(_downloadedSongsKey);
      if (jsonStr == null || jsonStr.isEmpty) {
        return [];
      }
      
      final List<dynamic> jsonList = jsonDecode(jsonStr);
      final allSongs = jsonList.map((json) => DownloadedSong.fromJson(json)).toList();
      
      // 验证文件是否存在，过滤无效记录
      final validSongs = <DownloadedSong>[];
      bool hasInvalidRecords = false;
      
      for (final song in allSongs) {
        final audioFile = File(song.localAudioPath);
        if (await audioFile.exists()) {
          validSongs.add(song);
        } else {
          Logger.warning('发现无效记录: ${song.title} (文件不存在)', 'Download');
          hasInvalidRecords = true;
        }
      }
      
      // 如果有无效记录，更新存储
      if (hasInvalidRecords && validSongs.length != allSongs.length) {
        final jsonList = validSongs.map((s) => s.toJson()).toList();
        await _prefsCache.setString(_downloadedSongsKey, jsonEncode(jsonList));
        Logger.success('已清理 ${allSongs.length - validSongs.length} 条无效记录', 'Download');
      }
      
      return validSongs;
    } catch (e) {
      Logger.error('读取下载列表失败', e, null, 'Download');
      return [];
    }
  }

  /// 检查歌曲是否已下载（同时验证文件是否存在）
  Future<bool> isDownloaded(String songId) async {
    final downloaded = await getDownloadedSongs();
    final song = downloaded.where((s) => s.id == songId).firstOrNull;
    
    if (song == null) {
      return false; // 记录不存在
    }
    
    // 验证音频文件是否真实存在
    final audioFile = File(song.localAudioPath);
    final exists = await audioFile.exists();
    
    // 如果文件不存在，清理无效记录
    if (!exists) {
      Logger.warning('检测到无效记录，文件不存在: ${song.title}', 'Download');
      await _removeInvalidRecord(songId);
      return false;
    }
    
    return true;
  }
  
  /// 移除无效的下载记录
  Future<void> _removeInvalidRecord(String songId) async {
    try {
      final downloaded = await getDownloadedSongs();
      downloaded.removeWhere((s) => s.id == songId);
      final jsonList = downloaded.map((s) => s.toJson()).toList();
      await _prefsCache.setString(_downloadedSongsKey, jsonEncode(jsonList));
      Logger.success('已清理无效记录: $songId', 'Download');
    } catch (e) {
      Logger.error('清理无效记录失败', e, null, 'Download');
    }
  }

  /// 删除下载的歌曲
  Future<bool> deleteDownloadedSong(String songId) async {
    try {
      final downloaded = await getDownloadedSongs();
      final song = downloaded.firstWhere((s) => s.id == songId);
      
      // 删除音频文件
      final audioFile = File(song.localAudioPath);
      if (await audioFile.exists()) {
        await audioFile.delete();
      }
      
      // 删除封面文件
      if (song.localCoverPath != null) {
        final coverFile = File(song.localCoverPath!);
        if (await coverFile.exists()) {
          await coverFile.delete();
        }
      }
      
      // 删除歌词文件
      if (song.localLyricsPath != null) {
        final lyricsFile = File(song.localLyricsPath!);
        if (await lyricsFile.exists()) {
          await lyricsFile.delete();
        }
      }
      
      // 从记录中移除
      downloaded.removeWhere((s) => s.id == songId);
      final jsonList = downloaded.map((s) => s.toJson()).toList();
      await _prefsCache.setString(_downloadedSongsKey, jsonEncode(jsonList));
      
      Logger.success('删除成功: ${song.title}', 'Download');
      return true;
    } catch (e) {
      Logger.error('删除失败', e, null, 'Download');
      return false;
    }
  }

  /// 清空所有下载
  Future<bool> clearAllDownloads() async {
    try {
      final downloadDir = await _getDownloadDirectory();
      
      if (await downloadDir.exists()) {
        await downloadDir.delete(recursive: true);
        await downloadDir.create(recursive: true);
      }
      
      await _prefsCache.setString(_downloadedSongsKey, '[]');
      Logger.success('清空所有下载', 'Download');
      return true;
    } catch (e) {
      Logger.error('清空失败', e, null, 'Download');
      return false;
    }
  }

  /// 获取下载文件总大小
  Future<int> getDownloadedSize() async {
    try {
      final downloadDir = await _getDownloadDirectory();
      int totalSize = 0;
      
      if (await downloadDir.exists()) {
        await for (var entity in downloadDir.list(recursive: true)) {
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

  /// 格式化文件大小
  String formatSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }

  /// 清理文件名中的非法字符
  String _sanitizeFileName(String fileName) {
    // 移除或替换非法字符
    return fileName
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
  }
}
