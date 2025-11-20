import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/song.dart';
import '../../providers/music_provider.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_styles.dart';
import '../../utils/responsive.dart';

/// 发现页“每日推荐”区域
class DailyRecommendationsSection extends StatelessWidget {
  final List<Song> dailyRecommendations;
  final bool isLoading;
  final ScrollController scrollController;
  final VoidCallback onRefresh;

  const DailyRecommendationsSection({
    super.key,
    required this.dailyRecommendations,
    required this.isLoading,
    required this.scrollController,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final padding = Responsive.getHorizontalPadding(context);
    final colors = Provider.of<ThemeProvider>(context).colors;
    final today = DateTime.now();
    final dateStr = '${today.month}月${today.day}日';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: padding,
          child: Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 24,
                color: colors.accent,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '每日推荐',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$dateStr · 根据你的口味精选',
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (!isLoading)
                IconButton(
                  icon: Icon(Icons.refresh, color: colors.accent),
                  onPressed: onRefresh,
                  tooltip: '刷新推荐',
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (isLoading)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: CircularProgressIndicator(color: colors.accent),
            ),
          )
        else if (dailyRecommendations.isEmpty)
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
                    Icon(
                      Icons.cloud_off,
                      size: 48,
                      color: colors.textSecondary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '加载推荐失败',
                      style: TextStyle(
                        fontSize: 16,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Stack(
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
                    itemCount: dailyRecommendations.length,
                    itemBuilder: (context, index) {
                      final song = dailyRecommendations[index];
                      return Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: _LargeSongCard(
                          song: song,
                          onTap: () {
                            Provider.of<MusicProvider>(context, listen: false)
                                .playSong(song, playlist: dailyRecommendations);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
              // 左箭头按钮 (仅桌面端显示)
              if (Responsive.isDesktop(context))
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.only(left: 8),
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
                        icon: Icon(Icons.chevron_left, color: colors.textPrimary),
                        onPressed: () {
                          scrollController.animateTo(
                            scrollController.offset - 400,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                      ),
                    ),
                  ),
                ),
              // 右箭头按钮 (仅桌面端显示)
              if (Responsive.isDesktop(context))
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
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
                        icon: Icon(Icons.chevron_right, color: colors.textPrimary),
                        onPressed: () {
                          scrollController.animateTo(
                            scrollController.offset + 400,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                      ),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _LargeSongCard extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;

  const _LargeSongCard({
    required this.song,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;
    final coverOverlay = colors.isLight ? 0.0 : 0.5; // 浅色主题无遮罩

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 200,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppStyles.radiusLarge),
                child: BackdropFilter(
                  filter: AppStyles.backdropBlur,
                  child: Container(
                    decoration: AppStyles.glassDecoration(
                      color: colors.card,
                      opacity: 0.6,
                      borderColor: colors.border,
                      isLight: colors.isLight,
                      borderRadius: BorderRadius.circular(AppStyles.radiusLarge),
                    ),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppStyles.radiusLarge),
                            child: CachedNetworkImage(
                              imageUrl: song.coverUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: colors.card.withValues(alpha: 0.5),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: colors.card,
                                child: Icon(
                                  Icons.music_note,
                                  size: 60,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                          if (coverOverlay > 0)
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(AppStyles.radiusLarge),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: coverOverlay),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: AppStyles.spacingM),
              Text(
                song.title,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: AppStyles.spacingXS),
              Text(
                song.artist,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
