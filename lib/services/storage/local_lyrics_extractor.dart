import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;

import '../../utils/logger.dart';
import '../../utils/song_metadata_utils.dart';
import '../core/core.dart';

/// 本地音频歌词提取器
///
/// 二级回退策略：内嵌元数据 → 同目录 .lrc 文件
class LocalLyricsExtractor {
  final SongMetadataUtils _metadataUtils = SongMetadataUtils();

  /// 在音频文件同目录下查找 .lrc 歌词文件
  Future<String?> findLyricsInSameDirectory(String audioPath, Directory lyricsDir) async {
    try {
      final dir = p.dirname(audioPath);
      final directory = Directory(dir);
      if (!await directory.exists()) return null;

      final baseName = p.basenameWithoutExtension(audioPath);

      final lrcFile = File(p.join(dir, '$baseName.lrc'));
      if (await lrcFile.exists()) {
        final safeName = _metadataUtils.safeCacheName(audioPath, 'lyrics', '.lrc');
        final cachedLrc = File(p.join(lyricsDir.path, safeName));
        if (!await cachedLrc.exists()) {
          await cachedLrc.writeAsString(await lrcFile.readAsString());
        }
        Logger.info('找到同目录歌词文件: $baseName.lrc', 'LocalScanner');
        return cachedLrc.path;
      }
    } catch (e) {
      Logger.warning('查找歌词文件失败: $e', 'LocalScanner');
    }
    return null;
  }

  /// 保存内嵌歌词到缓存目录
  Future<String?> saveEmbeddedLyrics(
    String? lyrics,
    String audioPath,
    Directory lyricsDir,
  ) async {
    if (lyrics == null || lyrics.trim().isEmpty) return null;

    try {
      final safeName = _metadataUtils.safeCacheName(audioPath, 'embedded', '.lrc');
      final lyricsFile = File(p.join(lyricsDir.path, safeName));

      if (lyricsFile.existsSync()) {
        return lyricsFile.path;
      }

      await lyricsFile.writeAsString(lyrics);
      return lyricsFile.path;
    } catch (e) {
      return null;
    }
  }
}

/// 本地音频元数据读取器
///
/// 支持两级回退：audio_metadata_reader → MediaScanService（Android原生）
class LocalMetadataReader {
  /// 从音频文件读取标题
  Future<String?> readTitle(String filePath) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return null;
      final metadata = readMetadata(file);
      final title = metadata.title?.trim();
      if (title != null && title.isNotEmpty) return title;
    } catch (e) {
      Logger.warning('读取元数据标题失败: $e', 'LocalScanner');
    }

    if (!kIsWeb && Platform.isAndroid) {
      try {
        final result = await MediaScanService().getMetadata(filePath);
        final title = result?['title']?.trim();
        if (title != null && title.isNotEmpty) return title;
      } catch (_) {}
    }

    return null;
  }

  /// 从音频文件读取艺术家
  Future<String?> readArtist(String filePath) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return null;
      final metadata = readMetadata(file);
      final artist = metadata.artist?.trim();
      if (artist != null && artist.isNotEmpty) return artist;
    } catch (_) {}

    if (!kIsWeb && Platform.isAndroid) {
      try {
        final result = await MediaScanService().getMetadata(filePath);
        final artist = result?['artist']?.trim();
        if (artist != null && artist.isNotEmpty) return artist;
      } catch (_) {}
    }

    return null;
  }

  /// 从音频文件读取专辑
  Future<String?> readAlbum(String filePath) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return null;
      final metadata = readMetadata(file);
      final album = metadata.album?.trim();
      if (album != null && album.isNotEmpty) return album;
    } catch (_) {}

    if (!kIsWeb && Platform.isAndroid) {
      try {
        final result = await MediaScanService().getMetadata(filePath);
        final album = result?['album']?.trim();
        if (album != null && album.isNotEmpty) return album;
      } catch (_) {}
    }

    return null;
  }
}
