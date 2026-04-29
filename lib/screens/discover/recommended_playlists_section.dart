import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/playlist.dart';
import '../../models/song.dart';
import '../../providers/theme_provider.dart';
import '../../repositories/music_repository.dart';
import '../../services/network/playlist_scraper_service.dart';
import '../../theme/app_styles.dart';
import '../../utils/logger.dart';
import '../../utils/responsive.dart';
import '../../utils/snackbar_util.dart';
import '../playlist_detail_screen.dart';

class RecommendedPlaylistCard extends StatelessWidget {
  final RecommendedPlaylist playlist;

  const RecommendedPlaylistCard({
    required this.playlist,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _openPlaylistDetail(context, colors),
        child: Container(
          width: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppStyles.radiusLarge),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCoverImage(colors),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  playlist.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoverImage(ThemeColors colors) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppStyles.radiusLarge),
          child: AspectRatio(
            aspectRatio: 1,
            child: CachedNetworkImage(
              imageUrl: playlist.coverUrl,
              fit: BoxFit.cover,
              memCacheWidth: 400,
              placeholder: (context, url) => Container(
                color: colors.card.withValues(alpha: 0.5),
                child: Center(
                  child: CircularProgressIndicator(
                    color: colors.accent,
                    strokeWidth: 2,
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colors.card,
                      colors.card.withValues(alpha: 0.7),
                    ],
                  ),
                ),
                child: Icon(
                  Icons.music_note_rounded,
                  size: 64,
                  color: colors.textSecondary.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppStyles.radiusLarge),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.3),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openPlaylistDetail(BuildContext context, ThemeColors colors) async {
    final repository = MusicRepository();

    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(AppStyles.radiusLarge),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: colors.accent),
              const SizedBox(height: 16),
              Text(
                '加载中...',
                style: TextStyle(color: colors.textPrimary),
              ),
            ],
          ),
        ),
      ),
    ));

    final navigator = Navigator.of(context);

    try {
      Logger.info('开始加载歌单: ${playlist.title} (ID: ${playlist.id})', 'DiscoverScreen');

      final result = await repository.getPlaylistSongs(
        playlistId: playlist.id,
      );

      final List<Song> songs = (result['songs'] as List<dynamic>?)?.cast<Song>().toList() ?? [];
      final int totalCount = result['totalCount'] as int? ?? 0;

      Logger.info('歌单加载完成: ${songs.length} 首歌曲，总数: $totalCount', 'DiscoverScreen');

      if (!context.mounted) {
        navigator.pop();
        return;
      }

      final playlistObj = Playlist(
        id: playlist.id,
        name: playlist.title,
        coverUrl: playlist.coverUrl,
        songs: songs,
      );

      navigator.pop();

      unawaited(navigator.push(
        MaterialPageRoute<void>(
          builder: (context) => PlaylistDetailScreen(
            playlist: playlistObj,
            totalCount: totalCount,
            qqNumber: '',
          ),
        ),
      ));
    } catch (e) {
      Logger.error('歌单加载失败: ${playlist.title} (ID: ${playlist.id})', e, null, 'DiscoverScreen');

      if (!context.mounted) {
        navigator.pop();
        return;
      }
      AppSnackBar.show(
        '加载歌单失败，请稍后重试',
        type: SnackBarType.error,
      );
    }
  }
}

class RecommendedPlaylistsSection extends StatelessWidget {
  final List<RecommendedPlaylist> playlists;
  final bool isLoading;
  final ScrollController scrollController;
  final VoidCallback onRefresh;

  const RecommendedPlaylistsSection({
    required this.playlists,
    required this.isLoading,
    required this.scrollController,
    required this.onRefresh,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final padding = Responsive.getHorizontalPadding(context);
    final colors = Provider.of<ThemeProvider>(context).colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: padding,
          child: Row(
            children: [
              Text(
                '推荐歌单',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const Spacer(),
              if (!isLoading && playlists.isNotEmpty)
                IconButton(
                  icon: Icon(Icons.refresh, color: colors.accent),
                  onPressed: onRefresh,
                  tooltip: '刷新推荐',
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (isLoading)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: CircularProgressIndicator(color: colors.accent),
            ),
          )
        else if (playlists.isEmpty)
          Padding(
            padding: padding,
            child: Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(AppStyles.radiusLarge),
                border: Border.all(color: colors.border),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.cloud_off, size: 48, color: colors.textSecondary),
                    const SizedBox(height: 16),
                    Text(
                      '加载推荐歌单失败',
                      style: TextStyle(fontSize: 16, color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          _buildPlaylistListView(context, padding, colors),
      ],
    );
  }

  Widget _buildPlaylistListView(BuildContext context, EdgeInsets padding, ThemeColors colors) {
    return Stack(
      children: [
        SizedBox(
          height: 280,
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
              },
            ),
            child: ListView.builder(
              controller: scrollController,
              scrollDirection: Axis.horizontal,
              padding: padding,
              itemCount: playlists.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: RecommendedPlaylistCard(playlist: playlists[index]),
                );
              },
            ),
          ),
        ),
        if (Responsive.isDesktop(context))
          _buildScrollArrow(
            context: context,
            colors: colors,
            alignment: Alignment.centerLeft,
            icon: Icons.chevron_left,
            margin: const EdgeInsets.only(left: 8),
            onPressed: () => scrollController.animateTo(
              scrollController.offset - 400,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            ),
          ),
        if (Responsive.isDesktop(context))
          _buildScrollArrow(
            context: context,
            colors: colors,
            alignment: Alignment.centerRight,
            icon: Icons.chevron_right,
            margin: const EdgeInsets.only(right: 8),
            onPressed: () => scrollController.animateTo(
              scrollController.offset + 400,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            ),
          ),
      ],
    );
  }

  Widget _buildScrollArrow({
    required BuildContext context,
    required ThemeColors colors,
    required Alignment alignment,
    required IconData icon,
    required EdgeInsets margin,
    required VoidCallback onPressed,
  }) {
    return Align(
      alignment: alignment,
      child: Center(
        child: Container(
          margin: margin,
          decoration: BoxDecoration(
            color: colors.card.withValues(alpha: 0.9),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(icon, color: colors.textPrimary),
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }
}
