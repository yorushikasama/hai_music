import 'dart:io' as io;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../extensions/duration_extension.dart';
import '../../models/downloaded_song.dart';
import '../../providers/music_provider.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_styles.dart';

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
    required this.songs,
    required this.isSelectionMode,
    required this.selectedIds,
    required this.currentPlayingId,
    required this.isPlayingNow,
    required this.bottomPadding,
    required this.onSelectionChanged,
    required this.onPlay,
    required this.onDelete,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final musicProvider = Provider.of<MusicProvider>(context);
    final effectiveBottomPadding = musicProvider.currentSong != null ? bottomPadding : AppStyles.spacingL;

    return SliverPadding(
      padding: EdgeInsets.only(
        left: AppStyles.spacingXL,
        right: AppStyles.spacingXL,
        bottom: effectiveBottomPadding,
      ),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final downloadedSong = songs[index];
            final isPlaying = currentPlayingId != null && currentPlayingId == downloadedSong.id;
            final isSelected = selectedIds.contains(downloadedSong.id);

            return Padding(
              padding: const EdgeInsets.only(bottom: AppStyles.spacingM),
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

class _DownloadedSongTile extends StatefulWidget {
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
  State<_DownloadedSongTile> createState() => _DownloadedSongTileState();
}

class _DownloadedSongTileState extends State<_DownloadedSongTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: AppStyles.animFast,
      lowerBound: 0.97,
      upperBound: 1.0,
      value: 1.0,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: AppStyles.animCurve,
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _scaleController.reverse();
  void _onTapUp(TapUpDetails _) => _scaleController.forward();
  void _onTapCancel() => _scaleController.forward();

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;
    final textTheme = Theme.of(context).textTheme;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: AnimatedContainer(
        duration: AppStyles.animFast,
        curve: AppStyles.animCurve,
        decoration: BoxDecoration(
          color: widget.isSelected
              ? colors.accent.withValues(alpha: 0.1)
              : widget.isPlaying
                  ? colors.accent.withValues(alpha: 0.06)
                  : colors.surface.withValues(alpha: 0.5),
          borderRadius: AppStyles.borderRadiusLarge,
          border: Border.all(
            color: widget.isSelected
                ? colors.accent.withValues(alpha: 0.4)
                : widget.isPlaying
                    ? colors.accent.withValues(alpha: 0.2)
                    : colors.border.withValues(alpha: 0.06),
            width: widget.isSelected ? 1.5 : 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: AppStyles.borderRadiusLarge,
            onTapDown: _onTapDown,
            onTapUp: _onTapUp,
            onTapCancel: _onTapCancel,
            onTap: () {
              _scaleController.forward();
              if (widget.isSelectionMode) {
                widget.onSelectionChanged(widget.downloadedSong, !widget.isSelected);
              } else {
                widget.onPlay(widget.downloadedSong);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppStyles.spacingM,
                vertical: AppStyles.spacingS + 2,
              ),
              child: Row(
                children: [
                  if (widget.isSelectionMode)
                    Padding(
                      padding: const EdgeInsets.only(right: AppStyles.spacingM - 2),
                      child: AnimatedContainer(
                        duration: AppStyles.animFast,
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: widget.isSelected ? colors.accent : Colors.transparent,
                          borderRadius: AppStyles.borderRadiusSmall,
                          border: Border.all(
                            color: widget.isSelected ? colors.accent : colors.textSecondary.withValues(alpha: 0.4),
                            width: 2,
                          ),
                        ),
                        child: widget.isSelected
                            ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                            : null,
                      ),
                    ),
                  _buildCover(colors),
                  const SizedBox(width: AppStyles.spacingM),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.downloadedSong.title,
                          style: textTheme.titleSmall?.copyWith(
                            color: widget.isPlaying ? colors.accent : colors.textPrimary,
                            height: 1.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppStyles.spacingXS),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.downloadedSong.artist,
                                style: textTheme.labelMedium?.copyWith(
                                  color: colors.textSecondary.withValues(alpha: 0.75),
                                  height: 1.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (widget.downloadedSong.duration != null)
                              Padding(
                                padding: const EdgeInsets.only(left: AppStyles.spacingS),
                                child: Text(
                                  Duration(seconds: widget.downloadedSong.duration!).toMinutesSeconds(),
                                  style: textTheme.labelSmall?.copyWith(
                                    color: colors.textSecondary.withValues(alpha: 0.5),
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!widget.isSelectionMode)
                    Padding(
                      padding: const EdgeInsets.only(left: AppStyles.spacingXS),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => widget.onDelete(widget.downloadedSong),
                          child: Container(
                            padding: const EdgeInsets.all(AppStyles.spacingS),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colors.error.withValues(alpha: 0.08),
                            ),
                            child: Icon(
                              Icons.delete_outline_rounded,
                              color: colors.error.withValues(alpha: 0.7),
                              size: 19,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCover(ThemeColors colors) {
    return Stack(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: AppStyles.borderRadiusMedium,
            color: colors.card.withValues(alpha: 0.3),
          ),
          child: ClipRRect(
            borderRadius: AppStyles.borderRadiusMedium,
            child: widget.downloadedSong.localCoverPath != null
                ? Image.file(
                    io.File(widget.downloadedSong.localCoverPath!),
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    cacheWidth: 104,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildCoverPlaceholder(colors, widget.downloadedSong.coverUrl);
                    },
                  )
                : _buildCoverPlaceholder(colors, widget.downloadedSong.coverUrl),
          ),
        ),
        if (widget.isPlaying)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: AppStyles.borderRadiusMedium,
              ),
              child: Icon(
                widget.isGlobalPlaying ? Icons.equalizer_rounded : Icons.pause_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        Positioned(
          top: 2,
          right: 2,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: colors.success.withValues(alpha: 0.9),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: colors.success.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: const Icon(
              Icons.download_done_rounded,
              color: Colors.white,
              size: 10,
            ),
          ),
        ),
      ],
    );
  }
}

Widget _buildCoverPlaceholder(ThemeColors colors, String? networkUrl) {
  if (networkUrl != null && networkUrl.isNotEmpty) {
    return CachedNetworkImage(
      imageUrl: networkUrl,
      width: 52,
      height: 52,
      fit: BoxFit.cover,
      memCacheWidth: 104,
      memCacheHeight: 104,
      placeholder: (context, url) => Container(
        width: 52,
        height: 52,
        color: colors.card.withValues(alpha: 0.3),
        child: Icon(Icons.music_note_rounded, color: colors.textSecondary.withValues(alpha: 0.3), size: 20),
      ),
      errorWidget: (context, url, error) => Container(
        width: 52,
        height: 52,
        color: colors.card.withValues(alpha: 0.3),
        child: Icon(Icons.music_note_rounded, color: colors.textSecondary, size: 20),
      ),
      fadeInDuration: AppStyles.animNormal,
    );
  }

  return Container(
    width: 52,
    height: 52,
    color: colors.card.withValues(alpha: 0.3),
    child: Icon(Icons.music_note_rounded, color: colors.textSecondary, size: 20),
  );
}
