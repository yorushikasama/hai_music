import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart' as audio_meta;
import 'package:audiotags/audiotags.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path/path.dart' as path;

import '../../models/downloaded_song.dart';
import '../../utils/logger.dart';
import '../../utils/song_metadata_utils.dart';
import '../core/core.dart';
import 'download_database.dart';

/// 下载恢复服务
///
/// 负责在数据库为空时扫描下载目录，恢复已下载歌曲的记录。
/// Android 使用 MediaStore API 查询，桌面端使用文件系统递归扫描。
class DownloadRecoveryService {
  static final DownloadRecoveryService _instance = DownloadRecoveryService._internal();
  factory DownloadRecoveryService() => _instance;
  DownloadRecoveryService._internal();

  final OnAudioQuery _audioQuery = OnAudioQuery();
  final _metadataUtils = SongMetadataUtils();
  final _db = DownloadDatabase();
  final _mediaScanService = MediaScanService();
  final _pathManager = StoragePathManager();

  Future<void> recoverIfNeeded() async {
    try {
      final dbCount = await _db.getDownloadedCount();
      Logger.info('恢复检查: 数据库已有 $dbCount 条记录', 'DownloadRecovery');
      if (dbCount > 0) return;

      final downloadDir = await _getDownloadDirectory();
      final dirExists = await downloadDir.exists();
      Logger.info('恢复检查: 下载目录 ${downloadDir.path}, 存在=$dirExists', 'DownloadRecovery');
      if (!dirExists) return;

      final recoveredSongs = <DownloadedSong>[];

      if (Platform.isAndroid) {
        await _recoverOnAndroid(downloadDir, recoveredSongs);
      } else {
        await _recoverOnDesktop(downloadDir, recoveredSongs);
      }

      if (recoveredSongs.isNotEmpty) {
        for (final song in recoveredSongs) {
          await _db.insertDownloadedSong(song);
        }
        Logger.success('从下载目录恢复了 ${recoveredSongs.length} 首歌曲记录', 'DownloadRecovery');

        if (Platform.isAndroid) {
          for (final song in recoveredSongs) {
            _mediaScanService.scanFile(song.localAudioPath);
          }
        }
      }
    } catch (e) {
      Logger.warning('恢复下载记录失败: $e', 'DownloadRecovery');
    }
  }

  Future<Directory> _getDownloadDirectory() async {
    await _pathManager.init();
    return _pathManager.getDownloadsDir();
  }

  Future<void> _recoverOnAndroid(Directory downloadDir, List<DownloadedSong> recoveredSongs) async {
    try {
      final hasPermission = await _audioQuery.checkAndRequest();
      if (!hasPermission) {
        Logger.warning('无音频读取权限，无法恢复下载记录', 'DownloadRecovery');
        return;
      }

      final List<SongModel> allSongs = await _audioQuery.querySongs(
        sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
      );

      final downloadDirPath = path.normalize(downloadDir.path);
      final downloadSongs = allSongs.where((s) {
        final normalizedData = path.normalize(s.data);
        return normalizedData.startsWith(downloadDirPath + path.separator) ||
               normalizedData == downloadDirPath;
      }).toList();
      Logger.info('通过 MediaStore 找到 ${downloadSongs.length} 首下载目录歌曲', 'DownloadRecovery');

      for (final songModel in downloadSongs) {
        final song = await _parseAndroidSongModel(songModel, downloadDir);
        if (song != null) recoveredSongs.add(song);
      }
    } catch (e) {
      Logger.warning('MediaStore 查询失败: $e', 'DownloadRecovery');
    }
  }

  Future<DownloadedSong?> _parseAndroidSongModel(SongModel songModel, Directory downloadDir) async {
    final filePath = songModel.data;
    final fileName = path.basenameWithoutExtension(filePath);
    String title = songModel.title.isNotEmpty ? songModel.title : fileName;
    String artist = songModel.artist ?? '';
    if (artist == '<unknown>') artist = '';

    final isLowQualityTitle = _metadataUtils.isLowQualityTitle(title);

    if (isLowQualityTitle) {
      title = await _tryImproveTitleFromMetadata(filePath, title, artist);
      artist = _tryImproveArtistFromFilename(fileName, title, artist, isLowQualityTitle);
    } else if (_metadataUtils.isLowQualityArtist(artist)) {
      artist = _parseArtistFromFilename(fileName, title);
      if (isLowQualityTitle && fileName.contains(' - ')) {
        final parts = fileName.split(' - ');
        if (parts.length >= 2) {
          title = parts.sublist(1).join(' - ').trim();
        }
      }
    }

    final localCoverPath = await _findOrExtractCover(filePath, fileName, downloadDir, songModel);
    final localLyricsPath = await _findLyricsFile(fileName, downloadDir);
    final localTransPath = await _findTransFile(fileName, downloadDir);

    final audioFile = File(filePath);
    final fileSize = await audioFile.length();

    return DownloadedSong(
      id: _generateRecoveryId(title, artist, duration: songModel.duration != null ? songModel.duration! ~/ 1000 : null),
      title: title,
      artist: artist,
      album: songModel.album ?? '',
      localAudioPath: filePath,
      localCoverPath: localCoverPath,
      localLyricsPath: localLyricsPath,
      localTransPath: localTransPath,
      duration: songModel.duration != null ? songModel.duration! ~/ 1000 : null,
      platform: 'local',
      downloadedAt: DateTime.now(),
      source: SongSource.recovered,
      fileSize: fileSize,
    );
  }

  Future<String> _tryImproveTitleFromMetadata(String filePath, String currentTitle, String currentArtist) async {
    String title = currentTitle;
    String artist = currentArtist;

    try {
      final audioFile = File(filePath);
      if (audioFile.existsSync()) {
        final metadata = audio_meta.readMetadata(audioFile, getImage: false);
        if (metadata.title != null && metadata.title!.trim().isNotEmpty && !_metadataUtils.isLowQualityTitle(metadata.title!.trim())) {
          title = metadata.title!.trim();
        }
        if (metadata.artist != null && metadata.artist!.trim().isNotEmpty && _metadataUtils.isLowQualityArtist(artist)) {
          artist = metadata.artist!.trim();
        }
      }
    } catch (_) {}

    if (_metadataUtils.isLowQualityTitle(title)) {
      try {
        final nativeMeta = await _mediaScanService.getMetadata(filePath);
        if (nativeMeta != null) {
          final nativeTitle = nativeMeta['title']?.trim() ?? '';
          if (nativeTitle.isNotEmpty && !_metadataUtils.isLowQualityTitle(nativeTitle)) {
            title = nativeTitle;
          }
          if (_metadataUtils.isLowQualityArtist(artist)) {
            final nativeArtist = nativeMeta['artist']?.trim() ?? '';
            if (nativeArtist.isNotEmpty) {
              artist = nativeArtist;
            }
          }
        }
      } catch (_) {}
    }

    return title;
  }

  String _tryImproveArtistFromFilename(String fileName, String title, String artist, bool isLowQualityTitle) {
    if (artist.isEmpty || _metadataUtils.isLowQualityArtist(artist)) {
      if (fileName.contains(' - ')) {
        final parts = fileName.split(' - ');
        if (parts.length >= 2) {
          final parsedArtist = parts[0].trim();
          if (parsedArtist.isNotEmpty) {
            artist = parsedArtist;
          }
          if (isLowQualityTitle || title == fileName) {
            title = parts.sublist(1).join(' - ').trim();
          }
        }
      }
    }
    return artist;
  }

  String _parseArtistFromFilename(String fileName, String title) {
    if (fileName.contains(' - ')) {
      final parts = fileName.split(' - ');
      if (parts.length >= 2) {
        return parts[0].trim();
      }
    }
    return '';
  }

  Future<String?> _findOrExtractCover(String filePath, String fileName, Directory downloadDir, SongModel? songModel) async {
    // 1. 检查下载目录中与音频同名的封面文件
    for (final coverExt in ['.jpg', '.png', '.jpeg']) {
      final coverFile = File(path.join(downloadDir.path, '$fileName$coverExt'));
      if (await coverFile.exists()) {
        return coverFile.path;
      }
    }

    // 2. 检查 covers 子目录中的封面文件（与音频同名）
    final coversDir = Directory(path.join(downloadDir.path, 'covers'));
    if (await coversDir.exists()) {
      for (final coverExt in ['.jpg', '.png', '.jpeg']) {
        final coverFile = File(path.join(coversDir.path, '$fileName$coverExt'));
        if (await coverFile.exists()) {
          return coverFile.path;
        }
      }
    }

    // 3. 通过 MediaStore 查询专辑封面
    if (songModel != null) {
      try {
        final albumId = songModel.albumId;
        if (albumId != null) {
          final artwork = await _audioQuery.queryArtwork(
            albumId,
            ArtworkType.AUDIO,
            size: 600,
            quality: 80,
          );
          if (artwork != null && artwork.isNotEmpty) {
            final coverSavePath = path.join(downloadDir.path, '$fileName.jpg');
            final coverSaveFile = File(coverSavePath);
            if (!await coverSaveFile.exists()) {
              await coverSaveFile.writeAsBytes(artwork);
            }
            return coverSavePath;
          }
        }
      } catch (e) {
        Logger.warning('MediaStore 提取封面失败: $fileName, 错误: $e', 'DownloadRecovery');
      }
    }

    // 4. 从音频文件元数据中提取嵌入封面
    try {
      final coverSavePath = path.join(downloadDir.path, '$fileName.jpg');
      final coverSaveFile = File(coverSavePath);
      if (!await coverSaveFile.exists()) {
        final extractedPath = await _mediaScanService.extractCover(filePath, coverSavePath).timeout(const Duration(seconds: 5));
        if (extractedPath != null) {
          return coverSavePath;
        }
      } else {
        return coverSavePath;
      }
    } catch (e) {
      Logger.warning('MediaMetadataRetriever 提取封面失败: $fileName, 错误: $e', 'DownloadRecovery');
    }

    return null;
  }

  Future<String?> _findLyricsFile(String fileName, Directory downloadDir) async {
    final lrcFile = File(path.join(downloadDir.path, '$fileName.lrc'));
    if (await lrcFile.exists()) return lrcFile.path;
    return null;
  }

  Future<String?> _findTransFile(String fileName, Directory downloadDir) async {
    final transFile = File(path.join(downloadDir.path, '${fileName}_trans.lrc'));
    if (await transFile.exists()) return transFile.path;
    return null;
  }

  Future<void> _recoverOnDesktop(Directory downloadDir, List<DownloadedSong> recoveredSongs) async {
    final audioExtensions = SongMetadataUtils.supportedAudioExtensions;
    final entities = await downloadDir.list().toList();
    Logger.info('下载目录共有 ${entities.length} 个文件/目录', 'DownloadRecovery');

    for (final entity in entities) {
      if (entity is! File) continue;

      final ext = path.extension(entity.path).toLowerCase();
      if (!audioExtensions.contains(ext)) continue;

      final song = await _parseDesktopFile(entity, downloadDir);
      if (song != null) recoveredSongs.add(song);
    }
  }

  Future<DownloadedSong?> _parseDesktopFile(File file, Directory downloadDir) async {
    final filePath = file.path;
    final fileName = path.basenameWithoutExtension(filePath);

    String? localCoverPath;
    for (final coverExt in ['.jpg', '.png', '.jpeg']) {
      final coverFile = File(path.join(downloadDir.path, '$fileName$coverExt'));
      if (await coverFile.exists()) {
        localCoverPath = coverFile.path;
        break;
      }
    }

    String title = fileName;
    String artist = '';
    if (fileName.contains(' - ')) {
      final parts = fileName.split(' - ');
      if (parts.length >= 2) {
        artist = parts[0].trim();
        title = parts.sublist(1).join(' - ').trim();
      }
    }

    try {
      final metadata = await AudioTags.read(filePath);
      if (metadata != null) {
        final metaTitle = metadata.title;
        if (metaTitle != null && metaTitle.isNotEmpty) {
          title = metaTitle;
        }
        final metaArtist = metadata.trackArtist;
        if (metaArtist != null && metaArtist.isNotEmpty) {
          artist = metaArtist;
        }

        if (localCoverPath == null && metadata.pictures.isNotEmpty) {
          final pic = metadata.pictures.first;
          final picExt = pic.mimeType == MimeType.png ? '.png' : '.jpg';
          final coverSavePath = path.join(downloadDir.path, '$fileName$picExt');
          final coverSaveFile = File(coverSavePath);
          if (!await coverSaveFile.exists()) {
            await coverSaveFile.writeAsBytes(pic.bytes);
          }
          localCoverPath = coverSavePath;
        }
      }
    } catch (e) {
      Logger.warning('AudioTags 读取元数据失败: $fileName, 错误: $e', 'DownloadRecovery');
    }

    final localLyricsPath = await _findLyricsFile(fileName, downloadDir);
    final localTransPath = await _findTransFile(fileName, downloadDir);

    final stat = await file.stat();
    final fileSize = await file.length();

    int? recoveredDuration;
    try {
      final audioFile = File(filePath);
      if (await audioFile.exists()) {
        final metadata = audio_meta.readMetadata(audioFile, getImage: false);
        recoveredDuration = metadata.duration?.inSeconds;
      }
    } catch (e) {
      Logger.warning('恢复时读取音频时长失败: $fileName, 错误: $e', 'DownloadRecovery');
    }

    return DownloadedSong(
      id: _generateRecoveryId(title, artist, duration: recoveredDuration),
      title: title,
      artist: artist,
      album: '',
      localAudioPath: filePath,
      localCoverPath: localCoverPath,
      localLyricsPath: localLyricsPath,
      localTransPath: localTransPath,
      duration: recoveredDuration,
      platform: 'local',
      downloadedAt: stat.modified,
      source: SongSource.recovered,
      fileSize: fileSize,
    );
  }

  /// 生成恢复歌曲的稳定ID，基于元数据而非路径
  /// 格式：recovered_{artist}_{title}_{duration}
  /// 这样即使文件移动到不同路径，ID也保持一致
  static String _generateRecoveryId(String title, String artist, {int? duration}) {
    final safeArtist = artist.replaceAll(RegExp(r'[^\w]'), '').toLowerCase();
    final safeTitle = title.replaceAll(RegExp(r'[^\w]'), '').toLowerCase();
    final durationPart = duration != null ? '_$duration' : '';
    return 'recovered_${safeArtist}_${safeTitle}$durationPart';
  }
}
