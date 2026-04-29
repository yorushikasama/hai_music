import 'dart:typed_data';

import 'package:audiotags/audiotags.dart';

import '../../utils/logger.dart';

class AudioMetadataService {
  static final AudioMetadataService _instance =
      AudioMetadataService._internal();
  factory AudioMetadataService() => _instance;
  AudioMetadataService._internal();

  static const int maxCoverSizeBytes = 5 * 1024 * 1024;

  Future<void> writeMetadata({
    required String audioFilePath,
    required String title,
    required String artist,
    required String album,
    Uint8List? coverBytes,
    int? duration,
  }) async {
    try {
      Tag? existingTag;
      try {
        existingTag = await AudioTags.read(audioFilePath);
      } catch (e) {
        Logger.warning('读取音频标签失败: $audioFilePath, $e', 'AudioMetadata');
      }

      final pictures = <Picture>[];
      if (coverBytes != null && coverBytes.isNotEmpty) {
        if (coverBytes.length > maxCoverSizeBytes) {
          Logger.warning(
            '封面过大(${coverBytes.length}字节)，跳过嵌入以避免OOM',
            'AudioMetadata',
          );
        } else {
          final mimeType = _detectMimeType(coverBytes);
          pictures.add(Picture(
            bytes: coverBytes,
            mimeType: mimeType,
            pictureType: PictureType.coverFront,
          ));
        }
      } else if (existingTag?.pictures.isNotEmpty == true) {
        pictures.addAll(existingTag!.pictures);
      }

      final tag = Tag(
        title: title.isNotEmpty ? title : existingTag?.title,
        trackArtist: artist.isNotEmpty ? artist : existingTag?.trackArtist,
        album: album.isNotEmpty ? album : existingTag?.album,
        albumArtist: existingTag?.albumArtist,
        genre: existingTag?.genre,
        year: existingTag?.year,
        trackNumber: existingTag?.trackNumber,
        trackTotal: existingTag?.trackTotal,
        discNumber: existingTag?.discNumber,
        discTotal: existingTag?.discTotal,
        duration: duration ?? existingTag?.duration,
        pictures: pictures,
      );

      await AudioTags.write(audioFilePath, tag);
      Logger.success('元数据写入成功: $title - $artist', 'AudioMetadata');
    } catch (e) {
      Logger.warning('元数据写入失败: $e', 'AudioMetadata');
    }
  }

  MimeType? _detectMimeType(Uint8List bytes) {
    if (bytes.length > 3) {
      if (bytes[0] == 0xFF && bytes[1] == 0xD8) {
        return MimeType.jpeg;
      } else if (bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4E &&
          bytes[3] == 0x47) {
        return MimeType.png;
      }
    }
    return null;
  }
}
