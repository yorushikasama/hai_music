import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:path/path.dart' as p;

import '../../utils/logger.dart';
import '../../utils/song_metadata_utils.dart';

/// 本地音频封面提取器
///
/// 三级回退策略：queryArtwork → 内嵌元数据 → 同目录图片
class LocalCoverExtractor {
  final SongMetadataUtils _metadataUtils = SongMetadataUtils();

  /// 在音频文件同目录下查找封面图片
  Future<String?> findCoverInSameDirectory(String audioPath, Directory coverDir) async {
    try {
      final dir = p.dirname(audioPath);
      final directory = Directory(dir);
      if (!await directory.exists()) return null;

      final baseName = p.basenameWithoutExtension(audioPath);

      final sameNamePatterns = ['$baseName.jpg', '$baseName.png', '$baseName.jpeg'];
      for (final pattern in sameNamePatterns) {
        final coverFile = File(p.join(dir, pattern));
        if (await coverFile.exists()) {
          final ext = p.extension(coverFile.path).toLowerCase();
          final safeName = _metadataUtils.safeCacheName(audioPath, 'cover', ext);
          final cachedCover = File(p.join(coverDir.path, safeName));
          if (!await cachedCover.exists()) {
            await cachedCover.writeAsBytes(await coverFile.readAsBytes());
          }
          Logger.info('找到同目录封面文件: $pattern', 'LocalScanner');
          return cachedCover.path;
        }
      }

      final genericCovers = ['cover.jpg', 'folder.jpg', 'album.jpg', 'cover.png', 'folder.png'];
      for (final pattern in genericCovers) {
        final coverFile = File(p.join(dir, pattern));
        if (await coverFile.exists()) {
          final ext = p.extension(coverFile.path).toLowerCase();
          final safeName = _metadataUtils.safeCacheName(audioPath, 'cover', ext);
          final cachedCover = File(p.join(coverDir.path, safeName));
          if (!await cachedCover.exists()) {
            await cachedCover.writeAsBytes(await coverFile.readAsBytes());
          }
          Logger.info('找到通用封面文件: $pattern', 'LocalScanner');
          return cachedCover.path;
        }
      }
    } catch (e) {
      Logger.warning('查找目录封面失败: $e', 'LocalScanner');
    }
    return null;
  }

  /// 保存内嵌封面到缓存目录
  Future<String?> saveEmbeddedCover(
    List<Picture> pictures,
    String audioPath,
    Directory coverDir,
  ) async {
    if (pictures.isEmpty) return null;

    try {
      Picture? cover;
      for (final pic in pictures) {
        if (pic.pictureType == PictureType.coverFront) {
          cover = pic;
          break;
        }
      }
      cover ??= pictures.first;

      if (cover.bytes.isEmpty) return null;

      final ext = cover.mimetype.contains('png') ? 'png' : 'jpg';
      final safeName = _metadataUtils.safeCacheName(audioPath, 'embedded', '.$ext');
      final coverFile = File(p.join(coverDir.path, safeName));

      if (coverFile.existsSync()) {
        return coverFile.path;
      }

      await coverFile.writeAsBytes(cover.bytes);
      return coverFile.path;
    } catch (e) {
      return null;
    }
  }
}
