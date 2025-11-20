import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

import '../../models/song.dart';
import '../../providers/theme_provider.dart';
import '../../providers/music_provider.dart';

class SearchResultsList extends StatelessWidget {
  final List<Song> songs;
  final bool isSelectionMode;
  final Set<String> selectedIds;
  final bool isLoadingMore;
  final bool hasMore;
  final ScrollController scrollController;
  final void Function(Song song, bool selected) onSelectionChanged;
  final void Function(Song song) onSongTap;
  final VoidCallback onLoadMore;
  final void Function(BuildContext context, String action, Song song) onMenuAction;

  const SearchResultsList({
    super.key,
    required this.songs,
    required this.isSelectionMode,
    required this.selectedIds,
    required this.isLoadingMore,
    required this.hasMore,
    required this.scrollController,
    required this.onSelectionChanged,
    required this.onSongTap,
    required this.onLoadMore,
    required this.onMenuAction,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: songs.length + (isLoadingMore || hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == songs.length) {
          if (isLoadingMore) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '加载中...',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            );
          } else if (hasMore) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: TextButton(
                  onPressed: onLoadMore,
                  child: Text(
                    '加载更多',
                    style: TextStyle(color: colors.primary),
                  ),
                ),
              ),
            );
          } else {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  '已加载全部结果',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
            );
          }
        }

        final song = songs[index];
        final isSelected = selectedIds.contains(song.id);

        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: isSelectionMode
              ? Checkbox(
                  value: isSelected,
                  onChanged: (value) {
                    onSelectionChanged(song, value == true);
                  },
                  activeColor: colors.accent,
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: song.coverUrl,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
                    placeholder: (context, url) => Container(
                      width: 56,
                      height: 56,
                      color: colors.card.withValues(alpha: 0.5),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 56,
                      height: 56,
                      color: colors.card,
                      child: Icon(Icons.music_note, color: colors.textSecondary),
                    ),
                  ),
                ),
          title: Text(
            song.title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${song.artist} · ${song.album}',
            style: TextStyle(
              fontSize: 14,
              color: colors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: isSelectionMode
              ? null
              : PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: colors.textSecondary),
                  color: colors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  offset: const Offset(0, 40),
                  itemBuilder: (context) => [
                    PopupMenuItem<String>(
                      value: 'favorite',
                      child: Consumer<MusicProvider>(
                        builder: (context, musicProvider, child) {
                          final isFavorite = musicProvider.isFavorite(song.id);
                          return Row(
                            children: [
                              Icon(
                                isFavorite ? Icons.favorite : Icons.favorite_border,
                                color: isFavorite ? Colors.red : colors.textPrimary,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
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
                          Icon(Icons.download_outlined, color: colors.textPrimary, size: 20),
                          const SizedBox(width: 12),
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
                          Icon(Icons.play_arrow, color: colors.textPrimary, size: 20),
                          const SizedBox(width: 12),
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
          onTap: () {
            if (isSelectionMode) {
              onSelectionChanged(song, !isSelected);
            } else {
              onSongTap(song);
            }
          },
        );
      },
    );
  }
}
