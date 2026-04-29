import 'dart:io';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/song.dart';
import '../providers/favorite_provider.dart';
import '../providers/music_provider.dart';
import '../providers/theme_provider.dart';
import '../screens/player_screen.dart';
import '../services/download/download_service.dart';
import '../theme/app_styles.dart';
import '../utils/logger.dart';
import '../utils/platform_utils.dart';
import 'mini_player_windows_controls.dart';

/// 迷你播放器组件，显示在页面底部
class MiniPlayer extends StatefulWidget {
  final void Function(String artistName)? onArtistTap;

  const MiniPlayer({super.key, this.onArtistTap});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;
    final isAndroid = PlatformUtils.isAndroid;

    return Consumer<MusicProvider>(
      builder: (context, musicProvider, child) {
        final song = musicProvider.currentSong;
        if (song == null) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const PlayerScreen(),
              ),
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
                          _buildCoverTapArea(song, colors),
                          const SizedBox(width: AppStyles.spacingM),
                          _buildSongInfo(song, colors),
                          const SizedBox(width: AppStyles.spacingM),
                          if (isAndroid)
                            ..._buildAndroidControls(
                              context,
                              musicProvider,
                              colors,
                              song.id,
                            )
                          else
                            ...[
                              MiniPlayerWindowsControls(
                                musicProvider: musicProvider,
                                colors: colors,
                                songId: song.id,
                              ),
                            ],
                        ],
                      ),
                    ),
                    _buildProgressBar(musicProvider, colors),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCoverTapArea(Song song, ThemeColors colors) {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push<Object?>(
          context,
          MaterialPageRoute<Object?>(
            builder: (context) => const PlayerScreen(),
          ),
        );
        if (result is Map<String, Object?> &&
            result['action'] == 'search' &&
            result['query'] != null &&
            widget.onArtistTap != null) {
          widget.onArtistTap!(result['query'] as String);
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppStyles.radiusSmall),
        child: _buildCoverImage(song, colors),
      ),
    );
  }

  Widget _buildSongInfo(Song song, ThemeColors colors) {
    return Expanded(
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
                  ? () => widget.onArtistTap!(song.artist)
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
    );
  }

  Widget _buildProgressBar(MusicProvider musicProvider, ThemeColors colors) {
    return StreamBuilder<Duration>(
      stream: musicProvider.positionStream,
      initialData: musicProvider.currentPosition,
      builder: (context, positionSnapshot) {
        return StreamBuilder<Duration?>(
          stream: musicProvider.durationStream,
          initialData: musicProvider.totalDuration,
          builder: (context, durationSnapshot) {
            final position = positionSnapshot.data ?? Duration.zero;
            final totalDuration = durationSnapshot.data ?? Duration.zero;

            final sliderValue = min(
              _dragValue ?? position.inMilliseconds.toDouble(),
              totalDuration.inMilliseconds.toDouble(),
            );

            return SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 6,
                ),
                overlayShape: const RoundSliderOverlayShape(
                  overlayRadius: 12,
                ),
                activeTrackColor: colors.accent,
                inactiveTrackColor: colors.border,
                thumbColor: colors.accent,
                overlayColor: colors.accent.withValues(alpha: 0.2),
              ),
              child: Slider(
                min: 0.0,
                max: totalDuration.inMilliseconds > 0
                    ? totalDuration.inMilliseconds.toDouble()
                    : 1.0,
                value: totalDuration.inMilliseconds > 0
                    ? sliderValue.clamp(
                        0.0,
                        totalDuration.inMilliseconds.toDouble(),
                      )
                    : 0.0,
                onChanged: (value) {
                  setState(() {
                    _dragValue = value;
                  });
                },
                onChangeEnd: (value) {
                  musicProvider.seekTo(
                    Duration(milliseconds: value.round()),
                  );
                  setState(() {
                    _dragValue = null;
                  });
                },
              ),
            );
          },
        );
      },
    );
  }

  List<Widget> _buildAndroidControls(
    BuildContext context,
    MusicProvider musicProvider,
    ThemeColors colors,
    String songId,
  ) {
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
            ? colors.favorite
            : colors.textSecondary.withValues(alpha: 0.7),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        onPressed: () {
          Provider.of<FavoriteProvider>(
            context,
            listen: false,
          ).toggleFavorite(
            songId,
            currentSong: musicProvider.currentSong,
            playlist: musicProvider.playlist,
          );
        },
      ),
      const SizedBox(width: AppStyles.spacingS),
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: colors.accent,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: colors.accent.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => musicProvider.togglePlayPause(),
            child: Center(
              child: Icon(
                musicProvider.isPlaying ? Icons.pause : Icons.play_arrow,
                size: 26,
                color: colors.isLight ? Colors.white : colors.textPrimary,
              ),
            ),
          ),
        ),
      ),
      const SizedBox(width: AppStyles.spacingM),
    ];
  }

  Widget _buildCoverImage(Song song, ThemeColors colors) {
    final placeholder = Container(
      width: 56,
      height: 56,
      color: colors.card.withValues(alpha: 0.5),
      child: Icon(
        Icons.music_note,
        size: 28,
        color: colors.textSecondary,
      ),
    );

    if (song.localCoverPath != null && song.localCoverPath!.isNotEmpty) {
      final coverFile = File(song.localCoverPath!);
      if (coverFile.existsSync()) {
        return Image.file(
          coverFile,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          cacheWidth: 112,
          errorBuilder: (context, error, stackTrace) => placeholder,
        );
      }
    }

    final imageUrl = song.r2CoverUrl ?? song.coverUrl;
    if (imageUrl.isNotEmpty) {
      if (imageUrl.startsWith('file://')) {
        final filePath = Uri.parse(imageUrl).toFilePath();
        final file = File(filePath);
        if (file.existsSync()) {
          return Image.file(
            file,
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            cacheWidth: 112,
            errorBuilder: (context, error, stackTrace) => placeholder,
          );
        }
      } else if (!imageUrl.startsWith('content://')) {
        _persistCoverAsync(song);
        return CachedNetworkImage(
          imageUrl: imageUrl,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          memCacheWidth: 112,
          memCacheHeight: 112,
          placeholder: (context, url) => Container(
            width: 56,
            height: 56,
            color: colors.card.withValues(alpha: 0.5),
          ),
          errorWidget: (context, url, error) => placeholder,
        );
      }
    }

    return placeholder;
  }

  void _persistCoverAsync(Song song) {
    final imageUrl = song.r2CoverUrl ?? song.coverUrl;
    if (imageUrl.isEmpty ||
        imageUrl.startsWith('file://') ||
        imageUrl.startsWith('content://')) {
      return;
    }
    DownloadService().persistCover(song.id, imageUrl).catchError((e) {
      Logger.cache('迷你播放器异步持久化封面失败: ${song.id}', 'MiniPlayer');
      return null;
    });
  }
}
