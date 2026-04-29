import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';
import '../../theme/app_styles.dart';
import '../../utils/responsive.dart';

class LibraryQuickActions extends StatelessWidget {
  final VoidCallback onFavoritesTap;
  final VoidCallback onRecentTap;
  final VoidCallback onDownloadedTap;

  const LibraryQuickActions({
    required this.onFavoritesTap,
    required this.onRecentTap,
    required this.onDownloadedTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    if (isMobile) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  context,
                  icon: Icons.favorite_rounded,
                  title: '我喜欢',
                  subtitle: '收藏的歌曲',
                  color: Provider.of<ThemeProvider>(context).colors.favorite,
                  onTap: onFavoritesTap,
                ),
              ),
              const SizedBox(width: AppStyles.spacingM),
              Expanded(
                child: _buildActionCard(
                  context,
                  icon: Icons.history_rounded,
                  title: '最近播放',
                  subtitle: '播放记录',
                  color: Provider.of<ThemeProvider>(context).colors.accent,
                  onTap: onRecentTap,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppStyles.spacingM),
          _buildActionCard(
            context,
            icon: Icons.download_rounded,
            title: '本地下载',
            subtitle: '离线音乐',
            color: Provider.of<ThemeProvider>(context).colors.success,
            onTap: onDownloadedTap,
            isWide: true,
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: _buildActionCard(
            context,
            icon: Icons.favorite_rounded,
            title: '我喜欢',
            subtitle: '收藏的歌曲',
            color: Provider.of<ThemeProvider>(context).colors.favorite,
            onTap: onFavoritesTap,
          ),
        ),
        const SizedBox(width: AppStyles.spacingM),
        Expanded(
          child: _buildActionCard(
            context,
            icon: Icons.history_rounded,
            title: '最近播放',
            subtitle: '播放记录',
            color: Provider.of<ThemeProvider>(context).colors.accent,
            onTap: onRecentTap,
          ),
        ),
        const SizedBox(width: AppStyles.spacingM),
        Expanded(
          child: _buildActionCard(
            context,
            icon: Icons.download_rounded,
            title: '本地下载',
            subtitle: '离线音乐',
            color: Provider.of<ThemeProvider>(context).colors.success,
            onTap: onDownloadedTap,
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool isWide = false,
  }) {
    final colors = Provider.of<ThemeProvider>(context).colors;
    final textTheme = Theme.of(context).textTheme;

    if (isWide) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppStyles.borderRadiusMedium,
          child: Ink(
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: AppStyles.borderRadiusMedium,
              border: Border.all(color: color.withValues(alpha: 0.15)),
              boxShadow: AppStyles.getShadows(colors.isLight),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppStyles.spacingL,
                horizontal: AppStyles.spacingXL,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppStyles.spacingM),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          color.withValues(alpha: 0.2),
                          color.withValues(alpha: 0.08),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: AppStyles.spacingM),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: textTheme.labelLarge?.copyWith(
                            color: colors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppStyles.spacingXS),
                        Text(
                          subtitle,
                          style: textTheme.labelMedium?.copyWith(
                            color: colors.textSecondary.withValues(alpha: 0.7),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppStyles.borderRadiusMedium,
        child: Ink(
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: AppStyles.borderRadiusMedium,
            border: Border.all(color: color.withValues(alpha: 0.15)),
            boxShadow: AppStyles.getShadows(colors.isLight),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppStyles.spacingXL,
              horizontal: AppStyles.spacingM,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppStyles.spacingM),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color.withValues(alpha: 0.2),
                        color.withValues(alpha: 0.08),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(height: AppStyles.spacingM),
                Text(
                  title,
                  style: textTheme.labelLarge?.copyWith(
                    color: colors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppStyles.spacingXS),
                Text(
                  subtitle,
                  style: textTheme.labelMedium?.copyWith(
                    color: colors.textSecondary.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
