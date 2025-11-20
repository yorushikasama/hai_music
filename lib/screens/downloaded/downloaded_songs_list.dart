import 'dart:io' as io;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/downloaded_song.dart';
import '../../providers/music_provider.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_styles.dart';

/// 下载页面的歌曲列表区域（含多选支持）
class DownloadedSongsListSection extends StatelessWidget {
  final List<DownloadedSong> songs;
  final bool isSelectionMode;
  final Set<String> selectedIds;
  final String? currentPlayingId;
  final bool isPlayingNow;
  final double bottomPadding;
  final void Function(DownloadedSong song, bool selected) onSelectionChanged;
  final void Function(DownloadedSong song) onPlay;
  final void Function(DownloadedSong song) onDelete;

  const DownloadedSongsListSection({
    super.key,
    required this.songs,
    required this.isSelectionMode,
    required this.selectedIds,
    required this.currentPlayingId,
    required this.isPlayingNow,
    required this.bottomPadding,
    required this.onSelectionChanged,
    required this.onPlay,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final musicProvider = Provider.of<MusicProvider>(context);

    final effectiveBottomPadding = musicProvider.currentSong != null
        ? bottomPadding
        : 16.0;

    return SliverPadding(
      padding: EdgeInsets.only(left: 20, right: 20, bottom: effectiveBottomPadding),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final downloadedSong = songs[index];
            final isPlaying = currentPlayingId != null && currentPlayingId == downloadedSong.id;
            final isSelected = selectedIds.contains(downloadedSong.id);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _DownloadedSongTile(
                downloadedSong: downloadedSong,
                isPlaying: isPlaying,
                isGlobalPlaying: isPlayingNow,
                isSelectionMode: isSelectionMode,
                isSelected: isSelected,
                onSelectionChanged: onSelectionChanged,
                onPlay: onPlay,
                onDelete: onDelete,
              ),
            );
          },
          childCount: songs.length,
        ),
      ),
    );
  }
}

class _DownloadedSongTile extends StatelessWidget {
  final DownloadedSong downloadedSong;
  final bool isPlaying;
  final bool isGlobalPlaying;
  final bool isSelectionMode;
  final bool isSelected;
  final void Function(DownloadedSong song, bool selected) onSelectionChanged;
  final void Function(DownloadedSong song) onPlay;
  final void Function(DownloadedSong song) onDelete;

  const _DownloadedSongTile({
    required this.downloadedSong,
    required this.isPlaying,
    required this.isGlobalPlaying,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onSelectionChanged,
    required this.onPlay,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;

    return Container(
      decoration: BoxDecoration(
        color: isPlaying
            ? colors.accent.withValues(alpha: 0.08)
            : colors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPlaying
              ? colors.accent.withValues(alpha: 0.3)
              : colors.border.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (isSelectionMode) {
              onSelectionChanged(downloadedSong, !isSelected);
            } else {
              onPlay(downloadedSong);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // 选择框或占位
                if (isSelectionMode)
                  Checkbox(
                    value: isSelected,
                    onChanged: (value) {
                      onSelectionChanged(downloadedSong, value == true);
                    },
                    activeColor: colors.accent,
                  )
                else
                  const SizedBox(width: 0),
                // 封面图
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: downloadedSong.localCoverPath != null
                          ? Image.file(
                              io.File(downloadedSong.localCoverPath!),
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildCoverPlaceholder(colors, downloadedSong.coverUrl);
                              },
                            )
                          : _buildCoverPlaceholder(colors, downloadedSong.coverUrl),
                    ),
                    if (isPlaying)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isGlobalPlaying ? Icons.equalizer_rounded : Icons.pause_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    // 下载标识
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.download_done,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                // 歌曲信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        downloadedSong.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isPlaying ? colors.accent : colors.textPrimary,
                          height: 1.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        downloadedSong.artist,
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.textSecondary.withValues(alpha: 0.8),
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // 时长
                if (downloadedSong.duration != null)
                  Text(
                    _formatDuration(downloadedSong.duration!),
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.textSecondary.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                if (!isSelectionMode) ...[
                  const SizedBox(width: 8),
                  // 删除按钮
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red.withValues(alpha: 0.1),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      onPressed: () => onDelete(downloadedSong),
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget _buildCoverPlaceholder(ThemeColors colors, String? networkUrl) {
  if (networkUrl != null && networkUrl.isNotEmpty) {
    return CachedNetworkImage(
      imageUrl: networkUrl,
      width: 60,
      height: 60,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        width: 60,
        height: 60,
        color: colors.card.withValues(alpha: 0.3),
        child: Icon(Icons.music_note, color: colors.textSecondary.withValues(alpha: 0.3)),
      ),
      errorWidget: (context, url, error) => Container(
        width: 60,
        height: 60,
        color: colors.card.withValues(alpha: 0.3),
        child: Icon(Icons.music_note, color: colors.textSecondary),
      ),
    );
  }

  return Container(
    width: 60,
    height: 60,
    color: colors.card.withValues(alpha: 0.3),
    child: Icon(Icons.music_note, color: colors.textSecondary),
  );
}

String _formatDuration(int durationSeconds) {
  String twoDigits(int n) => n.toString().padLeft(2, '0');
  final minutes = twoDigits((durationSeconds ~/ 60) % 60);
  final seconds = twoDigits(durationSeconds % 60);
  return '$minutes:$seconds';
}
