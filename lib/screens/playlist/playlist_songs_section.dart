import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/song.dart';
import '../../providers/music_provider.dart';
import '../../providers/theme_provider.dart';

/// 歌单详情页中的歌曲列表区域（含多选支持）
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
    super.key,
    required this.songs,
    required this.isSelectionMode,
    required this.selectedIds,
    required this.isLoadingMore,
    required this.hasMoreData,
    required this.totalCount,
    required this.onSongTap,
    required this.onSelectionChanged,
    required this.onMenuAction,
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

          // 末尾的“加载更多/已全部加载/占位”区域
          if (isLoadingMore) {
            return Container(
              padding: const EdgeInsets.all(20),
              color: colors.background,
              child: Center(
                child: CircularProgressIndicator(color: colors.accent),
              ),
            );
          }

          if (!hasMoreData && songs.isNotEmpty) {
            return Container(
              padding: const EdgeInsets.all(20),
              color: colors.background,
              child: Center(
                child: Text(
                  '已加载全部 $totalCount 首歌曲',
                  style: TextStyle(
                    fontSize: 14,
                    color: colors.textSecondary,
                  ),
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

    return Container(
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(
          bottom: BorderSide(
            color: colors.border.withValues(alpha: 0.3),
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
              horizontal: 24,
              vertical: 12,
            ),
            child: Row(
              children: [
                if (isSelectionMode)
                  Checkbox(
                    value: isSelected,
                    onChanged: (value) {
                      onSelectionChanged(song, value == true);
                    },
                    activeColor: colors.accent,
                  )
                else
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: colors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(width: 16),
                // 歌曲信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        song.artist,
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // 更多按钮
                if (!isSelectionMode)
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      color: colors.textSecondary,
                      size: 20,
                    ),
                    color: colors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
