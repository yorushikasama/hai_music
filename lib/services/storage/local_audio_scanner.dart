import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path/path.dart' as p;

import '../../models/downloaded_song.dart';
import '../../utils/logger.dart';
import '../../utils/song_metadata_utils.dart';
import '../core/core.dart';
import 'local_cover_extractor.dart';
import 'local_lyrics_extractor.dart';

/// 本地音频扫描器
///
/// 扫描设备本地音频文件并转换为 DownloadedSong 对象
/// 支持 Android（MediaStore）和桌面平台（文件系统递归扫描）
class LocalAudioScanner {
  static final LocalAudioScanner _instance = LocalAudioScanner._internal();
  factory LocalAudioScanner() => _instance;
  LocalAudioScanner._internal();

  final OnAudioQuery _audioQuery = OnAudioQuery();
  final StoragePathManager _pathManager = StoragePathManager();
  final _metadataUtils = SongMetadataUtils();
  final _coverExtractor = LocalCoverExtractor();
  final _lyricsExtractor = LocalLyricsExtractor();
  final _metadataReader = LocalMetadataReader();
  bool _hasPermission = false;

  /// 请求本地音频文件读取权限
  Future<bool> requestPermission() async {
    if (kIsWeb) {
      Logger.warning('Web平台不支持本地扫描', 'LocalScanner');
      return false;
    }

    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      Logger.info('桌面平台，跳过权限请求', 'LocalScanner');
      _hasPermission = true;
      return true;
    }

    if (_hasPermission) return true;

    try {
      final hasManageStorage = await MediaScanService().checkManageStoragePermission();
      if (hasManageStorage) {
        Logger.info('已拥有管理存储权限，跳过 OnAudioQuery 权限请求', 'LocalScanner');
        _hasPermission = true;
        return true;
      }
    } catch (e) {
      Logger.warning('检查管理存储权限失败: $e', 'LocalScanner');
    }

    try {
      _hasPermission = await _audioQuery.checkAndRequest();
      Logger.info('权限状态: $_hasPermission', 'LocalScanner');
      return _hasPermission;
    } catch (e) {
      Logger.error('请求权限失败', e, null, 'LocalScanner');
      return false;
    }
  }

  /// 扫描本地所有音频文件并返回歌曲列表
  Future<List<DownloadedSong>> scanAllAudio() async {
    if (kIsWeb) {
      Logger.warning('Web平台不支持本地扫描', 'LocalScanner');
      return [];
    }

    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      return _scanDesktopAudio();
    }

    if (!_hasPermission) {
      final granted = await requestPermission();
      if (!granted) {
        Logger.error('没有权限', null, null, 'LocalScanner');
        return [];
      }
    }

    try {
      Logger.info('开始扫描所有音频文件...', 'LocalScanner');

      final List<SongModel> songs = await _audioQuery.querySongs(
        sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
      );

      final downloadDir = await _getDownloadDirPath();

      Logger.success('扫描完成，找到 ${songs.length} 首歌曲', 'LocalScanner');

      final coverDir = await _getLocalCoverDir();
      final lyricsDir = await _getLocalLyricsDir();

      final List<DownloadedSong> downloadedSongs = [];
      for (final song in songs) {
        if (downloadDir != null && song.data.startsWith(downloadDir)) {
          continue;
        }

        final downloadedSong = await _convertToDownloadedSong(song, coverDir, lyricsDir);
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

  /// 获取所有可扫描的音乐目录路径
  Future<List<String>> getAllScanDirectories() async {
    await _loadCustomDirectories();
    final dirs = _getDesktopMusicDirectories();
    dirs.addAll(_customDirectories);
    return dirs;
  }

  Future<List<DownloadedSong>> _scanDesktopAudio() async {
    Logger.info('开始扫描桌面平台音频文件...', 'LocalScanner');

    final List<DownloadedSong> allSongs = [];
    final List<String> musicDirs = await getAllScanDirectories();

    final coverDir = await _getLocalCoverDir();
    final lyricsDir = await _getLocalLyricsDir();

    for (final dir in musicDirs) {
      final directory = Directory(dir);
      if (!directory.existsSync()) continue;
      try {
        await for (final entity in directory.list(recursive: true)) {
          if (entity is File) {
            final ext = entity.path.split('.').last.toLowerCase();
            if (_metadataUtils.isSupportedAudioFormat(ext)) {
              final song = await _parseDesktopAudioFile(entity, coverDir, lyricsDir);
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

  List<String> _getDesktopMusicDirectories() {
    final List<String> dirs = [];

    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null) {
        dirs.addAll([
          '$userProfile\\Music',
          '$userProfile\\Downloads',
          '$userProfile\\Desktop',
          '$userProfile\\Documents',
        ]);
      }
      final publicPath = Platform.environment['PUBLIC'];
      if (publicPath != null) {
        dirs.addAll(['$publicPath\\Music', '$publicPath\\Videos']);
      }
    } else if (Platform.isMacOS || Platform.isLinux) {
      final home = Platform.environment['HOME'];
      if (home != null) {
        dirs.addAll([
          '$home/Music',
          '$home/Downloads',
          '$home/Desktop',
          '$home/Documents',
        ]);
      }
    }

    return dirs;
  }

  final List<String> _customDirectories = [];
  static const _customDirsKey = 'custom_scan_directories';

  Future<void> _loadCustomDirectories() async {
    if (_customDirectories.isNotEmpty) return;
    try {
      final saved = await PreferencesService().getStringList(_customDirsKey);
      if (saved != null) {
        _customDirectories.addAll(saved);
      }
    } catch (e) {
      Logger.warning('加载自定义扫描目录失败: $e', 'LocalScanner');
    }
  }

  Future<String?> _getDownloadDirPath() async {
    try {
      final dir = await _pathManager.getDownloadsDir();
      return dir.path;
    } catch (_) {
      return null;
    }
  }

  Future<Directory> _getLocalCoverDir() async {
    final dir = Directory(p.join((await _pathManager.getMusicCoversDir()).path, 'local'));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  Future<Directory> _getLocalLyricsDir() async {
    final dir = Directory(p.join((await _pathManager.getLyricsCacheDir()).path, 'local'));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  Future<DownloadedSong?> _parseDesktopAudioFile(
    File file,
    Directory coverDir,
    Directory lyricsDir,
  ) async {
    try {
      final stat = file.statSync();
      String title = '未知标题';
      String artist = '未知艺术家';
      String album = '未知专辑';
      int? duration;
      String? localCoverPath;
      String? localLyricsPath;

      try {
        final metadata = readMetadata(file, getImage: true);

        title = metadata.title ?? '';
        artist = metadata.artist ?? '';
        album = metadata.album ?? '';
        duration = metadata.duration?.inSeconds;

        if (title.isEmpty || _metadataUtils.isLowQualityTitle(title)) {
          final parsed = _metadataUtils.parseFromFilePath(file.path);
          final parsedTitle = parsed?.title ?? _getFileNameWithoutExt(file);
          if (parsedTitle.isNotEmpty && !_metadataUtils.isLowQualityTitle(parsedTitle)) {
            title = parsedTitle;
          } else if (title.isEmpty) {
            title = parsedTitle;
          }
        }

        if (artist.isEmpty || _metadataUtils.isLowQualityArtist(artist)) {
          final parsed = _metadataUtils.parseFromFilePath(file.path);
          final parsedArtist = parsed?.artist ?? '';
          if (parsedArtist.isNotEmpty && !_metadataUtils.isLowQualityArtist(parsedArtist)) {
            artist = parsedArtist;
          } else if (artist.isEmpty) {
            artist = parsedArtist;
          }
        }

        if (album.isEmpty) {
          album = '';
        }

        localCoverPath = await _coverExtractor.saveEmbeddedCover(
          metadata.pictures, file.path, coverDir,
        );

        localLyricsPath = await _lyricsExtractor.saveEmbeddedLyrics(
          metadata.lyrics, file.path, lyricsDir,
        );

        Logger.success('读取元数据成功: $title - $artist', 'LocalScanner');
      } catch (e) {
        Logger.warning('读取元数据失败，使用文件名: $e', 'LocalScanner');
        final parsed = _metadataUtils.parseFromFilePath(file.path);
        if (parsed != null) {
          title = parsed.title;
          artist = parsed.artist;
        } else {
          title = _getFileNameWithoutExt(file);
          artist = '';
        }
      }

      localCoverPath ??= await _coverExtractor.findCoverInSameDirectory(file.path, coverDir);
      localLyricsPath ??= await _lyricsExtractor.findLyricsInSameDirectory(file.path, lyricsDir);

      return DownloadedSong(
        id: 'desktop_${file.path.hashCode.abs()}',
        title: title,
        artist: artist,
        album: album,
        localAudioPath: file.path,
        localCoverPath: localCoverPath,
        localLyricsPath: localLyricsPath,
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

  String _getFileNameWithoutExt(File file) {
    final fileName = file.path.split(Platform.pathSeparator).last;
    final lastDot = fileName.lastIndexOf('.');
    return lastDot > 0 ? fileName.substring(0, lastDot) : fileName;
  }

  /// 将移动端 SongModel 转换为 DownloadedSong
  Future<DownloadedSong?> _convertToDownloadedSong(
    SongModel song,
    Directory coverDir,
    Directory lyricsDir,
  ) async {
    try {
      if (song.data.isEmpty) {
        Logger.warning('歌曲文件路径为空: ${song.title}', 'LocalScanner');
        return null;
      }

      final id = 'local_${song.id}';

      String title = song.title;
      String artist = song.artist ?? '';
      String album = song.album ?? '';

      final titleIsLowQuality = _metadataUtils.isLowQualityTitle(title);
      final artistIsLowQuality = _metadataUtils.isLowQualityArtist(artist);

      if (titleIsLowQuality || artistIsLowQuality) {
        final metadataTitle = await _metadataReader.readTitle(song.data);
        final metadataArtist = await _metadataReader.readArtist(song.data);
        final metadataAlbum = await _metadataReader.readAlbum(song.data);

        if (titleIsLowQuality && metadataTitle != null && metadataTitle.isNotEmpty) {
          title = metadataTitle;
        }
        if (artistIsLowQuality && metadataArtist != null && metadataArtist.isNotEmpty) {
          artist = metadataArtist;
        }
        if (metadataAlbum != null && metadataAlbum.isNotEmpty && (album.isEmpty || album == '未知专辑')) {
          album = metadataAlbum;
        }
      }

      if (title.isEmpty || _metadataUtils.isLowQualityTitle(title)) {
        final parsed = _metadataUtils.parseFromFilePath(song.data);
        final parsedTitle = parsed?.title ?? _getFileNameWithoutExt(File(song.data));
        if (parsedTitle.isNotEmpty && !_metadataUtils.isLowQualityTitle(parsedTitle)) {
          title = parsedTitle;
        } else if (title.isEmpty) {
          title = parsedTitle;
        }
      }

      if (artist.isEmpty || _metadataUtils.isLowQualityArtist(artist)) {
        final parsed = _metadataUtils.parseFromFilePath(song.data);
        final parsedArtist = parsed?.artist ?? '';
        if (parsedArtist.isNotEmpty && !_metadataUtils.isLowQualityArtist(parsedArtist)) {
          artist = parsedArtist;
        } else if (artist.isEmpty) {
          artist = parsedArtist;
        }
      }

      var localCoverPath = await _extractMobileCover(song, coverDir);
      localCoverPath ??= await _extractCoverFromAudioFile(song, coverDir);
      localCoverPath ??= await _coverExtractor.findCoverInSameDirectory(song.data, coverDir);

      var localLyricsPath = await _extractLyricsFromAudioFile(song, lyricsDir);
      localLyricsPath ??= await _lyricsExtractor.findLyricsInSameDirectory(song.data, lyricsDir);

      Logger.info('扫描结果: $title | 封面: ${localCoverPath != null ? "有" : "无"} | 歌词: ${localLyricsPath != null ? "有" : "无"}', 'LocalScanner');

      return DownloadedSong(
        id: id,
        title: title,
        artist: artist,
        album: album.isEmpty ? '未知专辑' : album,
        localAudioPath: song.data,
        localCoverPath: localCoverPath,
        localLyricsPath: localLyricsPath,
        duration: song.duration != null ? (song.duration! ~/ 1000) : null,
        platform: 'local',
        downloadedAt: DateTime.fromMillisecondsSinceEpoch(
          song.dateAdded ?? DateTime.now().millisecondsSinceEpoch,
        ),
        source: SongSource.local,
        contentUri: song.uri,
      );
    } catch (e) {
      Logger.warning('转换歌曲失败: ${song.title}, $e', 'LocalScanner');
      return null;
    }
  }

  Future<String?> _extractMobileCover(SongModel song, Directory coverDir) async {
    try {
      final coverFile = File(p.join(coverDir.path, 'local_${song.id}.jpg'));
      if (coverFile.existsSync()) {
        return coverFile.path;
      }

      final artwork = await _audioQuery.queryArtwork(
        song.albumId ?? song.id,
        ArtworkType.ALBUM,
        size: 400,
        quality: 80,
      );

      if (artwork != null && artwork.isNotEmpty) {
        await coverFile.writeAsBytes(artwork);
        Logger.info('通过 queryArtwork 提取封面成功: ${song.title} (${artwork.length} bytes)', 'LocalScanner');
        return coverFile.path;
      }
    } catch (e) {
      Logger.warning('提取封面失败(queryArtwork): ${song.title}, $e', 'LocalScanner');
    }
    return null;
  }

  Future<String?> _extractCoverFromAudioFile(SongModel song, Directory coverDir) async {
    try {
      final audioFile = File(song.data);
      if (!audioFile.existsSync()) return null;

      final metadata = readMetadata(audioFile, getImage: true);
      if (metadata.pictures.isEmpty) return null;

      final result = await _coverExtractor.saveEmbeddedCover(metadata.pictures, song.data, coverDir);
      if (result != null) {
        Logger.info('通过内嵌元数据提取封面成功: ${song.title}', 'LocalScanner');
      }
      return result;
    } catch (e) {
      return null;
    }
  }

  Future<String?> _extractLyricsFromAudioFile(SongModel song, Directory lyricsDir) async {
    try {
      final audioFile = File(song.data);
      if (!audioFile.existsSync()) return null;

      final metadata = readMetadata(audioFile);
      if (metadata.lyrics == null || metadata.lyrics!.trim().isEmpty) return null;

      final result = await _lyricsExtractor.saveEmbeddedLyrics(metadata.lyrics, song.data, lyricsDir);
      if (result != null) {
        Logger.info('通过内嵌元数据提取歌词成功: ${song.title}', 'LocalScanner');
      }
      return result;
    } catch (e) {
      return null;
    }
  }
}
