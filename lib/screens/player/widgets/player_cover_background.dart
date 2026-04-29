import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../models/song.dart';
import '../../../services/download/download_service.dart';
import '../../../theme/app_styles.dart';
import '../../../utils/logger.dart';

class PlayerCoverBackground extends StatelessWidget {
  final Song song;
  final ThemeColors colors;

  static final Set<String> _persistedCoverIds = {};

  const PlayerCoverBackground({
    required this.song,
    required this.colors,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final gradientBackground = Container(
      decoration: BoxDecoration(
        gradient: colors.backgroundGradient ?? LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.surface, colors.background],
        ),
      ),
    );

    if (song.localCoverPath != null && song.localCoverPath!.isNotEmpty) {
      if (!kIsWeb) {
        final coverFile = File(song.localCoverPath!);
        if (coverFile.existsSync()) {
          return Image.file(
            coverFile,
            fit: BoxFit.cover,
            cacheWidth: 600,
            errorBuilder: (context, error, stackTrace) => gradientBackground,
          );
        }
      }
    }

    final imageUrl = song.r2CoverUrl ?? song.coverUrl;
    if (imageUrl.isNotEmpty) {
      if (!kIsWeb && imageUrl.startsWith('file://')) {
        final filePath = Uri.parse(imageUrl).toFilePath();
        final file = File(filePath);
        if (file.existsSync()) {
          return Image.file(
            file,
            fit: BoxFit.cover,
            cacheWidth: 600,
            errorBuilder: (context, error, stackTrace) => gradientBackground,
          );
        }
      } else if (!imageUrl.startsWith('content://') && !imageUrl.startsWith('file://')) {
        _persistCoverOnce(song);
        return CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          memCacheWidth: 600,
          placeholder: (context, url) => gradientBackground,
          errorWidget: (context, url, error) => gradientBackground,
        );
      }
    }

    return gradientBackground;
  }

  void _persistCoverOnce(Song song) {
    if (_persistedCoverIds.contains(song.id)) return;
    _persistedCoverIds.add(song.id);

    DownloadService().persistCover(song.id, song.r2CoverUrl ?? song.coverUrl).catchError((e) {
      Logger.warning('异步持久化封面失败: ${song.id}', 'PlayerScreen');
      return null;
    });
  }
}
