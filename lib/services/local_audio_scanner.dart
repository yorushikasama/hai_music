import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:on_audio_query/on_audio_query.dart';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import '../models/downloaded_song.dart';
import '../utils/logger.dart';

/// 本地音频扫描服务（使用 on_audio_query 插件）
class LocalAudioScanner {
  static final LocalAudioScanner _instance = LocalAudioScanner._internal();
  factory LocalAudioScanner() => _instance;
  LocalAudioScanner._internal();

  final OnAudioQuery _audioQuery = OnAudioQuery();
  bool _hasPermission = false;

  /// 请求权限
  Future<bool> requestPermission() async {
    if (kIsWeb) {
      Logger.warning('Web平台不支持本地扫描', 'LocalScanner');
      return false;
    }

    // Windows/macOS/Linux 桌面平台不需要权限请求
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      Logger.info('桌面平台，跳过权限请求', 'LocalScanner');
      _hasPermission = true;
      return true;
    }

    try {
      // 移动平台（Android/iOS）需要请求权限
      _hasPermission = await _audioQuery.checkAndRequest();
      Logger.info('权限状态: $_hasPermission', 'LocalScanner');
      return _hasPermission;
    } catch (e) {
      Logger.error('请求权限失败', e, null, 'LocalScanner');
      return false;
    }
  }

  /// 扫描所有音频文件
  Future<List<DownloadedSong>> scanAllAudio() async {
    if (kIsWeb) {
      Logger.warning('Web平台不支持本地扫描', 'LocalScanner');
      return [];
    }

    // Windows/macOS/Linux 使用文件系统扫描
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      return await _scanDesktopAudio();
    }

    // Android/iOS 使用 MediaStore
    if (!_hasPermission) {
      final granted = await requestPermission();
      if (!granted) {
        Logger.error('没有权限', null, null, 'LocalScanner');
        return [];
      }
    }

    try {
      Logger.info('开始扫描所有音频文件...', 'LocalScanner');
      
      // 使用 on_audio_query 查询所有歌曲
      final List<SongModel> songs = await _audioQuery.querySongs(
        sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
      );

      Logger.success('扫描完成，找到 ${songs.length} 首歌曲', 'LocalScanner');
      
      // 转换为 DownloadedSong 对象
      final List<DownloadedSong> downloadedSongs = [];
      for (final song in songs) {
        final downloadedSong = _convertToDownloadedSong(song);
        if (downloadedSong != null) {
          downloadedSongs.add(downloadedSong);
        }
      }

      return downloadedSongs;
    } catch (e) {
      Logger.error('扫描失败', e, null, 'LocalScanner');
      return [];
    }
  }

  /// 桌面平台音频扫描（Windows/macOS/Linux）
  Future<List<DownloadedSong>> _scanDesktopAudio() async {
    Logger.info('开始扫描桌面平台音频文件...', 'LocalScanner');
    
    final List<DownloadedSong> allSongs = [];
    final List<String> musicDirs = _getDesktopMusicDirectories();
    
    for (final dir in musicDirs) {
      final directory = Directory(dir);
      if (!await directory.exists()) continue;
      
      Logger.debug('扫描目录: $dir', 'LocalScanner');
      
      try {
        await for (var entity in directory.list(recursive: true)) {
          if (entity is File) {
            final ext = entity.path.split('.').last.toLowerCase();
            if (_isSupportedFormat(ext)) {
              final song = await _parseDesktopAudioFile(entity);
              if (song != null) {
                allSongs.add(song);
              }
            }
          }
        }
      } catch (e) {
        Logger.warning('扫描目录失败 $dir: $e', 'LocalScanner');
      }
    }
    
    Logger.success('桌面扫描完成，找到 ${allSongs.length} 首歌曲', 'LocalScanner');
    return allSongs;
  }

  /// 获取桌面平台音乐目录
  List<String> _getDesktopMusicDirectories() {
    final List<String> dirs = [];
    
    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null) {
        dirs.addAll([
          '$userProfile\\Music',
          '$userProfile\\Downloads',
        ]);
      }
    } else if (Platform.isMacOS || Platform.isLinux) {
      final home = Platform.environment['HOME'];
      if (home != null) {
        dirs.addAll([
          '$home/Music',
          '$home/Downloads',
        ]);
      }
    }
    
    return dirs;
  }

  /// 检查是否为支持的音频格式
  bool _isSupportedFormat(String ext) {
    const supportedFormats = [
      'mp3', 'm4a', 'aac', 'flac', 'wav', 'ogg', 'opus', 'wma'
    ];
    return supportedFormats.contains(ext);
  }

  /// 解析桌面平台音频文件（使用 audio_metadata_reader 读取真实元数据）
  Future<DownloadedSong?> _parseDesktopAudioFile(File file) async {
    try {
      final stat = await file.stat();
      String title = '未知标题';
      String artist = '未知艺术家';
      String album = '未知专辑';
      int? duration;
      
      // 尝试读取音频元数据（支持 MP3, M4A, FLAC, OGG, WAV 等）
      try {
        final metadata = readMetadata(file, getImage: false);
        
        // 提取元数据
        title = metadata.title ?? _getFileNameWithoutExt(file);
        artist = metadata.artist ?? '未知艺术家';
        album = metadata.album ?? '未知专辑';
        duration = metadata.duration?.inSeconds;
        
        Logger.success('读取元数据成功: $title - $artist', 'LocalScanner');
      } catch (e) {
        // 如果读取元数据失败，从文件名解析
        Logger.warning('读取元数据失败，使用文件名: $e', 'LocalScanner');
        final parsed = _parseFromFileName(file);
        title = parsed.title;
        artist = parsed.artist;
      }
      
      return DownloadedSong(
        id: 'desktop_${file.path.hashCode.abs()}',
        title: title,
        artist: artist,
        album: album,
        coverUrl: '',
        localAudioPath: file.path,
        duration: duration,
        platform: 'local',
        downloadedAt: stat.modified,
        source: SongSource.local,
      );
    } catch (e) {
      Logger.warning('解析文件失败: ${file.path}', 'LocalScanner');
      return null;
    }
  }
  
  /// 从文件名解析歌曲信息
  ({String title, String artist}) _parseFromFileName(File file) {
    final nameWithoutExt = _getFileNameWithoutExt(file);
    String artist = '未知艺术家';
    String title = nameWithoutExt;
    
    if (nameWithoutExt.contains(' - ')) {
      final parts = nameWithoutExt.split(' - ');
      if (parts.length >= 2) {
        artist = parts[0].trim();
        title = parts.sublist(1).join(' - ').trim();
      }
    }
    
    return (title: title, artist: artist);
  }
  
  /// 获取不带扩展名的文件名
  String _getFileNameWithoutExt(File file) {
    final fileName = file.path.split(Platform.pathSeparator).last;
    final lastDot = fileName.lastIndexOf('.');
    return lastDot > 0 ? fileName.substring(0, lastDot) : fileName;
  }

  /// 转换 SongModel 到 DownloadedSong
  DownloadedSong? _convertToDownloadedSong(SongModel song) {
    try {
      // 生成唯一ID
      final id = 'local_${song.id}';

      return DownloadedSong(
        id: id,
        title: song.title,
        artist: song.artist ?? '未知艺术家',
        album: song.album ?? '未知专辑',
        coverUrl: '', // 封面通过 queryArtwork 获取
        localAudioPath: song.data,
        duration: song.duration != null ? (song.duration! ~/ 1000) : null, // 转换毫秒为秒
        platform: 'local',
        downloadedAt: DateTime.fromMillisecondsSinceEpoch(
          song.dateAdded ?? DateTime.now().millisecondsSinceEpoch,
        ),
        source: SongSource.local,
      );
    } catch (e) {
      Logger.warning('转换歌曲失败: ${song.title}, $e', 'LocalScanner');
      return null;
    }
  }
}
