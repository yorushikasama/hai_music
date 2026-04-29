import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../extensions/duration_extension.dart';
import '../../extensions/favorite_song_extension.dart';
import '../../models/favorite_song.dart';
import '../../providers/favorite_provider.dart';
import '../../providers/music_provider.dart';
import '../../theme/app_styles.dart';

class FavoriteSongItem extends StatelessWidget {
  final FavoriteSong favorite;
  final bool isPlaying;
  final bool isSelectionMode;
  final bool isSelected;
  final ThemeColors colors;
  final MusicProvider musicProvider;
  final FavoriteProvider favoriteProvider;
  final VoidCallback onSelectionToggle;
  final void Function(bool success) onToggleFavorite;

  const FavoriteSongItem({
    required this.favorite,
    required this.isPlaying,
    required this.isSelectionMode,
    required this.isSelected,
    required this.colors,
    required this.musicProvider,
    required this.favoriteProvider,
    required this.onSelectionToggle,
    required this.onToggleFavorite,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isToggling = favoriteProvider.isFavoriteOperationInProgress(favorite.id);
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: isPlaying
            ? colors.accent.withValues(alpha: 0.08)
            : colors.surface.withValues(alpha: 0.6),
        borderRadius: AppStyles.borderRadiusLarge,
        border: Border.all(
          color: isPlaying
              ? colors.accent.withValues(alpha: 0.3)
              : colors.border.withValues(alpha: 0.1),
        ),
        boxShadow: AppStyles.getShadows(colors.isLight),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppStyles.borderRadiusLarge,
          onTap: () {
            if (isSelectionMode) {
              onSelectionToggle();
            } else {
              final song = favorite.toSong();
              final allSongs = <FavoriteSong>[favorite].toSongList();
              musicProvider.playSong(song, playlist: allSongs);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(AppStyles.spacingM),
            child: Row(
              children: [
                if (isSelectionMode)
                  Checkbox(
                    value: isSelected,
                    onChanged: (_) => onSelectionToggle(),
                    activeColor: colors.accent,
                  )
                else
                  const SizedBox(width: 0),
                _buildCoverImage(context),
                const SizedBox(width: AppStyles.spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        favorite.title,
                        style: textTheme.titleSmall?.copyWith(
                          color: isPlaying ? colors.accent : colors.textPrimary,
                          height: 1.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppStyles.spacingXS),
                      Text(
                        favorite.artist,
                        style: textTheme.labelMedium?.copyWith(
                          color: colors.textSecondary.withValues(alpha: 0.8),
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppStyles.spacingM),
                if (favorite.duration != null)
                  Text(
                    Duration(seconds: favorite.duration ?? 0).toMinutesSeconds(),
                    style: textTheme.labelMedium?.copyWith(
                      color: colors.textSecondary.withValues(alpha: 0.6),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                if (!isSelectionMode) ...[
                  const SizedBox(width: AppStyles.spacingS),
                  _buildFavoriteButton(colors, isToggling),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoverImage(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: AppStyles.borderRadiusMedium,
          child: CachedNetworkImage(
            imageUrl: favorite.coverUrl,
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            memCacheWidth: 112,
            memCacheHeight: 112,
            placeholder: (context, url) => Container(
              width: 56,
              height: 56,
              color: colors.card.withValues(alpha: 0.3),
              child: Icon(
                Icons.music_note_rounded,
                color: colors.textSecondary.withValues(alpha: 0.3),
                size: 22,
              ),
            ),
            errorWidget: (context, url, error) => Container(
              width: 56,
              height: 56,
              color: colors.card.withValues(alpha: 0.3),
              child: Icon(
                Icons.music_note_rounded,
                color: colors.textSecondary,
                size: 22,
              ),
            ),
            fadeInDuration: AppStyles.animNormal,
          ),
        ),
        if (isPlaying)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: AppStyles.borderRadiusMedium,
              ),
              child: Icon(
                musicProvider.isPlaying ? Icons.equalizer_rounded : Icons.pause_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFavoriteButton(ThemeColors colors, bool isToggling) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.favorite.withValues(alpha: 0.1),
      ),
      child: AnimatedSwitcher(
        duration: AppStyles.animFast,
        child: isToggling
            ? Padding(
                padding: const EdgeInsets.all(10),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(colors.favorite),
                  ),
                ),
              )
            : IconButton(
                key: const ValueKey('favorite_btn'),
                icon: Icon(
                  Icons.favorite_rounded,
                  color: colors.favorite,
                  size: 20,
                ),
                onPressed: () async {
                  final success = await favoriteProvider.toggleFavorite(
                    favorite.id,
                    currentSong: musicProvider.currentSong,
                    playlist: musicProvider.playlist,
                  );
                  onToggleFavorite(success);
                },
                padding: const EdgeInsets.all(AppStyles.spacingS),
                constraints: const BoxConstraints(),
              ),
      ),
    );
  }
}
