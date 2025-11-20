import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart' if (dart.library.html) '';

import '../../models/playlist.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_styles.dart';

/// 歌单详情页顶部头部区域（封面 + 背景毛玻璃 + 歌单信息）
class PlaylistDetailHeader extends StatelessWidget {
  final Playlist playlist;
  final int totalCount;

  const PlaylistDetailHeader({
    super.key,
    required this.playlist,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;

    return SliverAppBar(
      expandedHeight: 360,
      pinned: true,
      backgroundColor: colors.background,
      automaticallyImplyLeading: false,
      flexibleSpace: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: !kIsWeb
            ? (_) {
                try {
                  appWindow.startDragging();
                } catch (e) {
                  // 桌面平台支持窗口拖动
                }
              }
            : null,
        child: FlexibleSpaceBar(
          background: Stack(
            fit: StackFit.expand,
            children: [
              // 背景模糊封面
              CachedNetworkImage(
                imageUrl: playlist.coverUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: colors.card,
                ),
                errorWidget: (context, url, error) => Container(
                  color: colors.card,
                ),
              ),
              // 毛玻璃效果
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                child: Container(
                  color: colors.background.withValues(alpha: 0.7),
                ),
              ),
              // 渐变遮罩
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.3),
                      colors.background.withValues(alpha: 0.5),
                      colors.background,
                    ],
                  ),
                ),
              ),
              // 内容区域
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Spacer(),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 封面图
                          Container(
                            width: 160,
                            height: 160,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(AppStyles.radiusLarge),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(AppStyles.radiusLarge),
                              child: CachedNetworkImage(
                                imageUrl: playlist.coverUrl,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: colors.card,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: colors.accent,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: colors.card,
                                  child: Icon(
                                    Icons.music_note_rounded,
                                    size: 64,
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 24),
                          // 歌单信息
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  playlist.name,
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: colors.textPrimary,
                                    height: 1.2,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.music_note,
                                      size: 16,
                                      color: colors.textSecondary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$totalCount 首歌曲',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
