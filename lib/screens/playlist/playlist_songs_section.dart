import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/song.dart';
import '../../providers/favorite_provider.dart';
import '../../providers/music_provider.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_styles.dart';

class PlaylistSongsSection extends StatelessWidget {
  final List<Song> songs;
  final bool isSelectionMode;
  final Set<String> selectedIds;
  final bool isLoadingMore;
  final bool hasMoreData;
  final int totalCount;
  final void Function(Song song) onSongTap;
  final void Function(Song song, bool selected) onSelectionChanged;
  final Future<void> Function(BuildContext context, String action, Song song) onMenuAction;

  const PlaylistSongsSection({
    required this.songs,
    required this.isSelectionMode,
    required this.selectedIds,
    required this.isLoadingMore,
    required this.hasMoreData,
    required this.totalCount,
    required this.onSongTap,
    required this.onSelectionChanged,
    required this.onMenuAction,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index < songs.length) {
            final song = songs[index];
            final isSelected = selectedIds.contains(song.id);
            final musicProvider = Provider.of<MusicProvider>(context);
            final isPlaying = musicProvider.currentSong?.id == song.id;

            return _PlaylistSongTile(
              song: song,
              index: index,
              isPlaying: isPlaying,
              isSelectionMode: isSelectionMode,
              isSelected: isSelected,
              onSongTap: onSongTap,
              onSelectionChanged: onSelectionChanged,
              onMenuAction: onMenuAction,
            );
          }

          if (isLoadingMore) {
            return Container(
              padding: const EdgeInsets.all(AppStyles.spacingXL),
              color: colors.background,
              child: Center(
                child: CircularProgressIndicator(color: colors.accent),
              ),
            );
          }

          if (!hasMoreData && songs.isNotEmpty) {
            return Container(
              padding: const EdgeInsets.all(AppStyles.spacingXL),
              color: colors.background,
              child: Center(
                child: Text(
                  '已加载全部 $totalCount 首歌曲',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
            );
          }

          return Container(
            height: 100,
            color: colors.background,
          );
        },
        childCount: songs.length + 1,
      ),
    );
  }
}

class _PlaylistSongTile extends StatelessWidget {
  final Song song;
  final int index;
  final bool isPlaying;
  final bool isSelectionMode;
  final bool isSelected;
  final void Function(Song song) onSongTap;
  final void Function(Song song, bool selected) onSelectionChanged;
  final Future<void> Function(BuildContext context, String action, Song song) onMenuAction;

  const _PlaylistSongTile({
    required this.song,
    required this.index,
    required this.isPlaying,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onSongTap,
    required this.onSelectionChanged,
    required this.onMenuAction,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: isPlaying
            ? colors.accent.withValues(alpha: 0.06)
            : colors.background,
        border: Border(
          bottom: BorderSide(
            color: colors.border.withValues(alpha: 0.15),
            width: 0.5,
          ),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (isSelectionMode) {
              onSelectionChanged(song, !isSelected);
            } else {
              onSongTap(song);
            }
          },
          hoverColor: colors.card.withValues(alpha: 0.5),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppStyles.spacingXL,
              vertical: AppStyles.spacingM,
            ),
            child: Row(
              children: [
                if (isSelectionMode)
                  Checkbox(
                    value: isSelected,
                    onChanged: (value) {
                      onSelectionChanged(song, value ?? false);
                    },
                    activeColor: colors.accent,
                  )
                else
                  SizedBox(
                    width: 36,
                    child: Text(
                      '${index + 1}',
                      style: textTheme.labelMedium?.copyWith(
                        color: isPlaying ? colors.accent : colors.textSecondary,
                        fontWeight: isPlaying ? FontWeight.w700 : FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(width: AppStyles.spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        style: textTheme.titleSmall?.copyWith(
                          color: isPlaying ? colors.accent : colors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppStyles.spacingXS),
                      Text(
                        song.artist,
                        style: textTheme.labelMedium?.copyWith(
                          color: colors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (!isSelectionMode)
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      color: colors.textSecondary,
                      size: 20,
                    ),
                    color: colors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppStyles.borderRadiusMedium,
                    ),
                    offset: const Offset(0, 40),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    itemBuilder: (context) => [
                      PopupMenuItem<String>(
                        value: 'favorite',
                        child: Consumer<FavoriteProvider>(
                          builder: (context, favoriteProvider, child) {
                            final isFavorite = favoriteProvider.isFavorite(song.id);
                            return Row(
                              children: [
                                Icon(
                                  isFavorite ? Icons.favorite : Icons.favorite_border,
                                  color: isFavorite ? colors.favorite : colors.textPrimary,
                                  size: 20,
                                ),
                                const SizedBox(width: AppStyles.spacingM),
                                Text(
                                  isFavorite ? '取消喜欢' : '加入喜欢',
                                  style: TextStyle(color: colors.textPrimary),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'download',
                        child: Row(
                          children: [
                            Icon(Icons.download_outlined, color: colors.accent, size: 20),
                            const SizedBox(width: AppStyles.spacingM),
                            Text(
                              '下载到本地',
                              style: TextStyle(color: colors.textPrimary),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'play',
                        child: Row(
                          children: [
                            Icon(Icons.play_arrow, color: colors.accent, size: 20),
                            const SizedBox(width: AppStyles.spacingM),
                            Text(
                              '播放',
                              style: TextStyle(color: colors.textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) => onMenuAction(context, value, song),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
