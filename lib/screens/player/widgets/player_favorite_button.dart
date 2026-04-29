import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/favorite_provider.dart';
import '../../../providers/music_provider.dart';
import '../../../utils/logger.dart';

class PlayerFavoriteButton extends StatelessWidget {
  final double iconSize;
  final double indicatorSize;

  const PlayerFavoriteButton({
    this.iconSize = 24,
    this.indicatorSize = 16,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final musicProvider = context.watch<MusicProvider>();
    final song = musicProvider.currentSong;
    if (song == null) {
      return SizedBox(width: iconSize + 16);
    }

    return Consumer<FavoriteProvider>(
      builder: (context, favoriteProvider, _) {
        final isFav = favoriteProvider.isFavorite(song.id);
        final isLoading = favoriteProvider.isFavoriteOperationInProgress(song.id);

        if (isLoading) {
          return SizedBox(
            width: iconSize + 16,
            height: iconSize + 16,
            child: Center(
              child: SizedBox(
                width: indicatorSize,
                height: indicatorSize,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                ),
              ),
            ),
          );
        }

        return IconButton(
          icon: Icon(
            isFav ? Icons.favorite : Icons.favorite_border,
            color: isFav ? Colors.red : Colors.white.withValues(alpha: 0.9),
          ),
          iconSize: iconSize,
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(
            minWidth: iconSize + 16,
            minHeight: iconSize + 16,
          ),
          onPressed: () async {
            try {
              await favoriteProvider.toggleFavorite(
                song.id,
                currentSong: musicProvider.currentSong,
                playlist: musicProvider.playlist,
              );
            } catch (e) {
              Logger.error('切换收藏失败', e, null, 'PlayerControls');
            }
          },
        );
      },
    );
  }
}
