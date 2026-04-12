import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/play_mode.dart';
import '../providers/audio_settings_provider.dart';
import '../providers/favorite_provider.dart';
import '../providers/music_provider.dart';
import '../providers/theme_provider.dart';
import '../screens/player_screen.dart';
import '../theme/app_styles.dart';
import '../utils/logger.dart';
import 'audio_quality_selector.dart';

class MiniPlayer extends StatefulWidget {
  final void Function(String artistName)? onArtistTap;
  
  const MiniPlayer({super.key, this.onArtistTap});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  bool _isDragging = false;
  double _dragValue = 0.0;
  double _volumeBeforeMute = 0.5;

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;
    final isAndroid = Platform.isAndroid;
    
    return Consumer<MusicProvider>(
      builder: (context, musicProvider, child) {
        final song = musicProvider.currentSong;
        if (song == null) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const PlayerScreen()),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppStyles.radiusLarge),
            child: BackdropFilter(
              filter: AppStyles.backdropBlur,
              child: Container(
                margin: const EdgeInsets.all(AppStyles.spacingM),
                decoration: AppStyles.glassDecoration(
                  color: colors.surface,
                  opacity: 0.8,
                  borderColor: colors.border,
                  isLight: colors.isLight,
                  borderRadius: BorderRadius.circular(AppStyles.radiusLarge),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AppStyles.spacingM),
                      child: Row(
                        children: [
                          // 封面（点击进入歌词页面）
                          GestureDetector(
                            onTap: () async {
                              final result = await Navigator.push<dynamic>(
                                context,
                                MaterialPageRoute<dynamic>(
                                  builder: (context) => const PlayerScreen(),
                                ),
                              );
                              // 处理从播放器页面返回的搜索请求
                              if (result is Map && 
                                  result['action'] == 'search' && 
                                  result['query'] != null &&
                                  widget.onArtistTap != null) {
                                widget.onArtistTap!(result['query'] as String);
                              }
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(AppStyles.radiusSmall),
                              child: CachedNetworkImage(
                                imageUrl: song.coverUrl,
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  width: 56,
                                  height: 56,
                                  color: colors.card.withValues(alpha: 0.5),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  width: 56,
                                  height: 56,
                                  color: colors.card,
                                  child: Icon(
                                    Icons.music_note,
                                    size: 28,
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppStyles.spacingM),
                          // 歌曲信息
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
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
                                const SizedBox(height: AppStyles.spacingXS),
                                MouseRegion(
                                  cursor: widget.onArtistTap != null 
                                      ? SystemMouseCursors.click 
                                      : SystemMouseCursors.basic,
                                  child: GestureDetector(
                                    onTap: widget.onArtistTap != null
                                        ? () {
                                            Logger.debug('点击歌手: ${song.artist}');
                                            widget.onArtistTap!(song.artist);
                                          }
                                        : null,
                                    behavior: HitTestBehavior.opaque,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                      child: Text(
                                        song.artist,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: colors.textSecondary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppStyles.spacingM),
                          // 根据平台显示不同的控制按钮
                          if (isAndroid) ..._buildAndroidControls(context, musicProvider, colors, song.id)
                          else ..._buildWindowsControls(context, musicProvider, colors, song.id),
                        ],
                      ),
                    ),
                    // 进度条
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                        activeTrackColor: colors.accent,
                        inactiveTrackColor: colors.border,
                        thumbColor: colors.accent,
                        overlayColor: colors.accent.withValues(alpha: 0.2),
                      ),
                      child: Slider(
                        value: _isDragging
                            ? _dragValue
                            : () {
                                if (musicProvider.totalDuration.inSeconds <= 0) return 0.0;
                                final value = musicProvider.currentPosition.inSeconds /
                                    musicProvider.totalDuration.inSeconds;
                                if (value.isNaN || value.isInfinite) return 0.0;
                                return value.clamp(0.0, 1.0);
                              }(),
                        onChanged: (value) {
                          setState(() {
                            _isDragging = true;
                            _dragValue = value;
                          });
                        },
                        onChangeEnd: (value) {
                          if (musicProvider.totalDuration.inSeconds > 0) {
                            final position = Duration(
                              seconds: (value * musicProvider.totalDuration.inSeconds).round(),
                            );
                            musicProvider.seekTo(position);
                          }
                          setState(() {
                            _isDragging = false;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Android 端控制按钮 - Spotify 风格
  List<Widget> _buildAndroidControls(BuildContext context, MusicProvider musicProvider, ThemeColors colors, String songId) {
    final favoriteProvider = Provider.of<FavoriteProvider>(context);
    return [
      const Spacer(),
      IconButton(
        icon: Icon(
          favoriteProvider.isFavorite(songId)
              ? Icons.favorite
              : Icons.favorite_border,
        ),
        iconSize: 28,
        color: favoriteProvider.isFavorite(songId)
            ? const Color(0xFF1DB954)
            : colors.textSecondary.withValues(alpha: 0.7),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(
          minWidth: 40,
          minHeight: 40,
        ),
        onPressed: () {
          Provider.of<FavoriteProvider>(context, listen: false).toggleFavorite(songId, currentSong: musicProvider.currentSong, playlist: musicProvider.playlist);
        },
      ),
      const SizedBox(width: AppStyles.spacingS),
      // 播放/暂停按钮
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () {
              musicProvider.togglePlayPause();
            },
            child: Center(
              child: Icon(
                musicProvider.isPlaying
                    ? Icons.pause
                    : Icons.play_arrow,
                size: 26,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ),
      const SizedBox(width: AppStyles.spacingM),
    ];
  }

  // Windows 端控制按钮 - 完整控制
  List<Widget> _buildWindowsControls(BuildContext context, MusicProvider musicProvider, ThemeColors colors, String songId) {
    final favoriteProvider = Provider.of<FavoriteProvider>(context);
    return [
      // 上一曲
      IconButton(
        icon: const Icon(Icons.skip_previous),
        iconSize: 24,
        color: colors.textPrimary,
        onPressed: () {
          musicProvider.playPrevious();
        },
      ),
      // 播放/暂停
      Container(
        margin: const EdgeInsets.symmetric(horizontal: AppStyles.spacingXS),
        decoration: BoxDecoration(
          color: colors.accent,
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: Icon(
            musicProvider.isPlaying
                ? Icons.pause
                : Icons.play_arrow,
          ),
          iconSize: 24,
          color: Colors.white,
          onPressed: () {
            musicProvider.togglePlayPause();
          },
        ),
      ),
      // 下一曲
      IconButton(
        icon: const Icon(Icons.skip_next),
        iconSize: 24,
        color: colors.textPrimary,
        onPressed: () {
          musicProvider.playNext();
        },
      ),
      const SizedBox(width: 4),
      // 音量按钮 - QQ 音乐风格
      Builder(
        builder: (context) => IconButton(
          icon: Icon(
            musicProvider.volume == 0
                ? Icons.volume_off
                : musicProvider.volume < 0.5
                    ? Icons.volume_down
                    : Icons.volume_up,
          ),
          iconSize: 20,
          color: colors.textSecondary,
          tooltip: '音量: ${(musicProvider.volume * 100).round()}%',
          onPressed: () {
            _showVolumeControl(context, colors);
          },
        ),
      ),
      // 播放模式按钮
      Builder(
        builder: (context) => IconButton(
          icon: Icon(_getPlayModeIcon(musicProvider.playMode)),
          iconSize: 20,
          color: musicProvider.playMode == PlayMode.sequence 
              ? colors.textSecondary 
              : colors.accent,
          tooltip: '播放模式',
          onPressed: () {
            musicProvider.togglePlayMode();
          },
        ),
      ),
      // 音质选择按钮
      Builder(
        builder: (context) {
          final quality = Provider.of<AudioSettingsProvider>(context).audioQuality;
          return Semantics(
            label: '音质选择，当前: ${quality.semanticLabel}',
            button: true,
            child: GestureDetector(
              onTap: () {
                showModalBottomSheet<void>(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (context) => const AudioQualitySelector(),
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      quality.gradientColors[0].withValues(alpha: 0.2),
                      quality.gradientColors[1].withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: quality.color.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, animation) =>
                          ScaleTransition(scale: animation, child: child),
                      child: Icon(
                        quality.icon,
                        key: ValueKey(quality.name),
                        size: 14,
                        color: quality.color,
                      ),
                    ),
                    const SizedBox(width: 3),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, animation) =>
                          FadeTransition(opacity: animation, child: child),
                      child: Text(
                        quality.label,
                        key: ValueKey(quality.label),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: quality.color,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      IconButton(
        icon: Icon(
          favoriteProvider.isFavorite(songId)
              ? Icons.favorite
              : Icons.favorite_border,
        ),
        iconSize: 20,
        color: favoriteProvider.isFavorite(songId)
            ? Colors.red
            : colors.textSecondary,
        tooltip: '收藏',
        onPressed: () {
          Provider.of<FavoriteProvider>(context, listen: false).toggleFavorite(songId, currentSong: musicProvider.currentSong, playlist: musicProvider.playlist);
        },
      ),
      const SizedBox(width: 8),
    ];
  }

  IconData _getPlayModeIcon(PlayMode mode) {
    switch (mode) {
      case PlayMode.sequence:
        return Icons.repeat;
      case PlayMode.single:
        return Icons.repeat_one;
      case PlayMode.shuffle:
        return Icons.shuffle;
    }
  }

  // QQ 音乐风格的音量控制弹窗
  void _showVolumeControl(BuildContext context, ThemeColors colors) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final Offset buttonPosition = button.localToGlobal(Offset.zero, ancestor: overlay);
    final Size buttonSize = button.size;

    showDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => Consumer<MusicProvider>(
        builder: (context, musicProvider, child) {
          return Stack(
            children: [
              Positioned(
                left: buttonPosition.dx + buttonSize.width / 2 - 35, // 🔧 修复:调整居中位置
                bottom: overlay.size.height - buttonPosition.dy + 10, // 按钮上方 10px
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: 70, // 🔧 修复:增加宽度防止文本换行 (60 -> 70)
                    height: 240,
                    decoration: BoxDecoration(
                      color: colors.surface.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colors.border,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 音量图标（可点击静音/恢复）
                        InkWell(
                          onTap: () {
                            if (musicProvider.volume > 0) {
                              _volumeBeforeMute = musicProvider.volume;
                              musicProvider.setVolume(0);
                            } else {
                              musicProvider.setVolume(_volumeBeforeMute);
                            }
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              musicProvider.volume == 0
                                  ? Icons.volume_off_rounded
                                  : musicProvider.volume < 0.5
                                      ? Icons.volume_down_rounded
                                      : Icons.volume_up_rounded,
                              color: colors.textPrimary,
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // 垂直音量滑块
                        Expanded(
                          child: RotatedBox(
                            quarterTurns: 3,
                            child: SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 6,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                                activeTrackColor: colors.accent,
                                inactiveTrackColor: colors.border.withValues(alpha: 0.3),
                                thumbColor: Colors.white,
                                overlayColor: colors.accent.withValues(alpha: 0.2),
                              ),
                              child: Slider(
                                value: musicProvider.volume,
                                onChanged: (value) {
                                  musicProvider.setVolume(value);
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // 音量百分比
                        Container(
                          width: 42, // 🔧 修复:固定宽度防止 100% 时换行
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(
                            color: colors.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${(musicProvider.volume * 100).round()}',
                            textAlign: TextAlign.center, // 🔧 修复:居中对齐
                            style: TextStyle(
                              color: colors.accent,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
