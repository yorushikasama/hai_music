import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';
import '../../theme/app_styles.dart';

class LibraryPlaylistCard extends StatefulWidget {
  final Map<String, dynamic> playlistData;
  final VoidCallback onTap;

  const LibraryPlaylistCard({
    required this.playlistData,
    required this.onTap,
    super.key,
  });

  @override
  State<LibraryPlaylistCard> createState() => _LibraryPlaylistCardState();
}

class _LibraryPlaylistCardState extends State<LibraryPlaylistCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: AppStyles.animFast,
      lowerBound: 0.0,
      upperBound: 0.03,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _scaleController, curve: AppStyles.animCurve),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _scaleController.forward();
  void _onTapUp(TapUpDetails _) => _scaleController.reverse();
  void _onTapCancel() => _scaleController.reverse();

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: AppStyles.borderRadiusLarge,
              border: Border.all(
                color: colors.border.withValues(alpha: 0.15),
              ),
              boxShadow: AppStyles.getShadows(colors.isLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(
                  flex: 3,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppStyles.radiusLarge),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildCoverImage(colors),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.5),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          right: AppStyles.spacingS,
                          bottom: AppStyles.spacingS,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppStyles.spacingS,
                              vertical: AppStyles.spacingXS,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: AppStyles.borderRadiusSmall,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.music_note_rounded,
                                  color: Colors.white.withValues(alpha: 0.85),
                                  size: 12,
                                ),
                                const SizedBox(width: AppStyles.spacingXS),
                                Text(
                                  '${widget.playlistData['songCount']}',
                                  style: textTheme.labelSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppStyles.spacingM,
                    AppStyles.spacingM,
                    AppStyles.spacingM,
                    AppStyles.spacingL,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.playlistData['name'] as String,
                        style: textTheme.titleSmall?.copyWith(height: 1.3),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if ((widget.playlistData['description'] as String?) != null &&
                          (widget.playlistData['description'] as String).isNotEmpty) ...[
                        const SizedBox(height: AppStyles.spacingXS),
                        Text(
                          widget.playlistData['description'] as String,
                          style: textTheme.labelMedium?.copyWith(
                            color: colors.textSecondary.withValues(alpha: 0.7),
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
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

  Widget _buildCoverImage(ThemeColors colors) {
    final coverUrl = widget.playlistData['coverUrl'] as String;
    if (coverUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: coverUrl,
        fit: BoxFit.cover,
        memCacheWidth: 400,
        placeholder: (context, url) => Container(
          color: colors.card.withValues(alpha: 0.5),
          child: Center(
            child: Icon(
              Icons.library_music_rounded,
              size: 36,
              color: colors.textSecondary.withValues(alpha: 0.3),
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          color: colors.card,
          child: Icon(
            Icons.library_music_rounded,
            size: 40,
            color: colors.textSecondary.withValues(alpha: 0.4),
          ),
        ),
        fadeInDuration: AppStyles.animNormal,
      );
    }
    return Container(
      color: colors.card,
      child: Icon(
        Icons.library_music_rounded,
        size: 40,
        color: colors.textSecondary.withValues(alpha: 0.4),
      ),
    );
  }
}
