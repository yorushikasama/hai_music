import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';
import '../../theme/app_styles.dart';
import '../../utils/responsive.dart';

class PlaylistHeader extends StatelessWidget {
  final String playlistName;
  final String coverUrl;
  final int songCount;
  final int totalCount;
  final VoidCallback onPlayAll;
  final VoidCallback onBack;

  const PlaylistHeader({
    required this.playlistName,
    required this.coverUrl,
    required this.songCount,
    required this.totalCount,
    required this.onPlayAll,
    required this.onBack,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;
    final textTheme = Theme.of(context).textTheme;
    final isMobile = Responsive.isMobile(context);

    return SliverToBoxAdapter(
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + AppStyles.spacingL,
          left: AppStyles.spacingXL,
          right: AppStyles.spacingXL,
          bottom: AppStyles.spacingXXL,
        ),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_ios_new, color: colors.textPrimary, size: 20),
                  onPressed: onBack,
                  padding: const EdgeInsets.all(AppStyles.spacingS),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: AppStyles.spacingL),
            isMobile
                ? Column(
                    children: [
                      _buildCoverImage(colors),
                      const SizedBox(height: AppStyles.spacingXL),
                      _buildInfo(colors, textTheme),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCoverImage(colors),
                      const SizedBox(width: AppStyles.spacingXXL),
                      Expanded(child: _buildInfo(colors, textTheme)),
                    ],
                  ),
            const SizedBox(height: AppStyles.spacingXXL),
            _buildPlayAllButton(colors, textTheme),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverImage(ThemeColors colors) {
    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        borderRadius: AppStyles.borderRadiusXL,
        boxShadow: [
          BoxShadow(
            color: colors.accent.withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: AppStyles.borderRadiusXL,
        child: CachedNetworkImage(
          imageUrl: coverUrl,
          width: 160,
          height: 160,
          fit: BoxFit.cover,
          memCacheWidth: 320,
          memCacheHeight: 320,
          placeholder: (context, url) => Container(
            color: colors.card.withValues(alpha: 0.3),
            child: Icon(
              Icons.library_music_rounded,
              size: 48,
              color: colors.textSecondary.withValues(alpha: 0.3),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            color: colors.card.withValues(alpha: 0.3),
            child: Icon(
              Icons.library_music_rounded,
              size: 48,
              color: colors.textSecondary.withValues(alpha: 0.4),
            ),
          ),
          fadeInDuration: AppStyles.animNormal,
        ),
      ),
    );
  }

  Widget _buildInfo(ThemeColors colors, TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          playlistName,
          style: textTheme.headlineMedium?.copyWith(height: 1.3),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppStyles.spacingM),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppStyles.spacingS,
                vertical: AppStyles.spacingXS,
              ),
              decoration: BoxDecoration(
                color: colors.accent.withValues(alpha: 0.12),
                borderRadius: AppStyles.borderRadiusSmall,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.music_note_rounded, color: colors.accent, size: 14),
                  const SizedBox(width: AppStyles.spacingXS),
                  Text(
                    songCount == totalCount
                        ? '$songCount 首'
                        : '$songCount / $totalCount 首',
                    style: textTheme.labelMedium?.copyWith(
                      color: colors.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlayAllButton(ThemeColors colors, TextTheme textTheme) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPlayAll,
        borderRadius: AppStyles.borderRadiusMedium,
        child: Ink(
          width: double.infinity,
          decoration: BoxDecoration(
            color: colors.accent.withValues(alpha: 0.12),
            borderRadius: AppStyles.borderRadiusMedium,
            border: Border.all(
              color: colors.accent.withValues(alpha: 0.25),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppStyles.spacingM + 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_arrow_rounded, color: colors.accent, size: 24),
                const SizedBox(width: AppStyles.spacingS),
                Text(
                  '播放全部',
                  style: textTheme.labelLarge?.copyWith(
                    color: colors.accent,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
