import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/play_mode.dart';
import '../../models/song.dart';
import '../../providers/music_provider.dart';
import '../../services/download_service.dart';
import '../../services/download_manager.dart';
import '../../screens/download_progress_screen.dart';
import '../../utils/platform_utils.dart';
import '../../widgets/audio_quality_selector.dart';

import 'player_bottom_sheets.dart';

class PlayerControlPanel extends StatelessWidget {
  final MusicProvider musicProvider;
  final DownloadService downloadService;

  const PlayerControlPanel({
    super.key,
    required this.musicProvider,
    required this.downloadService,
  });

  @override
  Widget build(BuildContext context) {
    final isAndroid = PlatformUtils.isAndroid;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isAndroid ? 16 : 20,
        vertical: isAndroid ? 12 : 20,
      ),
      padding: EdgeInsets.all(isAndroid ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(isAndroid ? 20 : 24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isAndroid ? 20 : 24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildProgressBar(context, musicProvider),
              SizedBox(height: isAndroid ? 16 : 20),
              isAndroid
                  ? _buildAndroidControls(context, musicProvider)
                  : _buildDesktopControls(context, musicProvider),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context, MusicProvider musicProvider) {
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
            thumbColor: Colors.white,
            overlayColor: Colors.white.withValues(alpha: 0.2),
          ),
          child: Slider(
            value: () {
              if (musicProvider.totalDuration.inSeconds <= 0) return 0.0;
              final value = musicProvider.currentPosition.inSeconds /
                  musicProvider.totalDuration.inSeconds;
              if (value.isNaN || value.isInfinite) return 0.0;
              return value.clamp(0.0, 1.0);
            }(),
            onChanged: (value) {
              if (musicProvider.totalDuration.inSeconds > 0) {
                final position = Duration(
                  seconds: (value * musicProvider.totalDuration.inSeconds).round(),
                );
                musicProvider.seekTo(position);
              }
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                musicProvider.formatDuration(musicProvider.currentPosition),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              Text(
                musicProvider.formatDuration(musicProvider.totalDuration),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAndroidControls(BuildContext context, MusicProvider musicProvider) {
    final song = musicProvider.currentSong;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildSimpleButton(
              icon: _getPlayModeIcon(musicProvider.playMode),
              size: 28,
              opacity: musicProvider.playMode == PlayMode.sequence ? 0.5 : 1.0,
              onPressed: () => musicProvider.togglePlayMode(),
            ),
            _buildSimpleButton(
              icon: Icons.skip_previous_rounded,
              size: 36,
              onPressed: () => musicProvider.playPrevious(),
            ),
            _buildPlayButton(musicProvider),
            _buildSimpleButton(
              icon: Icons.skip_next_rounded,
              size: 36,
              onPressed: () => musicProvider.playNext(),
            ),
            if (song != null)
              musicProvider.isFavoriteOperationInProgress(song.id)
                  ? SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
                          ),
                        ),
                      ),
                    )
                  : _buildSimpleButton(
                      icon: musicProvider.isFavorite(song.id)
                          ? Icons.favorite
                          : Icons.favorite_border,
                      size: 28,
                      color: musicProvider.isFavorite(song.id)
                          ? Colors.red
                          : null,
                      onPressed: () async {
                        await musicProvider.toggleFavorite(song.id);
                      },
                    )
            else
              const SizedBox(width: 44),
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopControls(BuildContext context, MusicProvider musicProvider) {
    final song = musicProvider.currentSong;

    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              _buildSimpleButton(
                icon: _getPlayModeIcon(musicProvider.playMode),
                size: 24,
                opacity: musicProvider.playMode == PlayMode.sequence ? 0.5 : 1.0,
                onPressed: () => musicProvider.togglePlayMode(),
              ),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSimpleButton(
              icon: Icons.skip_previous_rounded,
              size: 36,
              onPressed: () => musicProvider.playPrevious(),
            ),
            const SizedBox(width: 16),
            _buildPlayButton(musicProvider),
            const SizedBox(width: 16),
            _buildSimpleButton(
              icon: Icons.skip_next_rounded,
              size: 36,
              onPressed: () => musicProvider.playNext(),
            ),
          ],
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (song != null)
                musicProvider.isFavoriteOperationInProgress(song.id)
                    ? SizedBox(
                        width: 40,
                        height: 40,
                        child: Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
                            ),
                          ),
                        ),
                      )
                    : _buildSimpleButton(
                        icon: musicProvider.isFavorite(song.id)
                            ? Icons.favorite
                            : Icons.favorite_border,
                        size: 24,
                        color: musicProvider.isFavorite(song.id)
                            ? Colors.red
                            : null,
                        onPressed: () async {
                          await musicProvider.toggleFavorite(song.id);
                        },
                      ),
              const SizedBox(width: 16),
              if (Platform.isWindows && song != null)
                _buildDownloadButton(context, song),
              if (Platform.isWindows && song != null)
                const SizedBox(width: 16),
              _buildVolumeControl(context, musicProvider),
              const SizedBox(width: 16),
              _buildSimpleButton(
                icon: Icons.high_quality_rounded,
                size: 24,
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true,
                    builder: (context) => const AudioQualitySelector(),
                  );
                },
              ),
              const SizedBox(width: 16),
              _buildSimpleButton(
                icon: Icons.timer_outlined,
                size: 24,
                onPressed: () => showSleepTimerDialog(context),
              ),
              const SizedBox(width: 16),
              _buildSimpleButton(
                icon: Icons.queue_music_rounded,
                size: 24,
                onPressed: () => showPlaylistDialog(context, musicProvider),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleButton({
    required IconData icon,
    required double size,
    required VoidCallback onPressed,
    double opacity = 1.0,
    Color? color,
  }) {
    return IconButton(
      icon: Icon(
        icon,
        color: color ?? Colors.white.withValues(alpha: opacity * 0.9),
      ),
      iconSize: size,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(
        minWidth: size + 16,
        minHeight: size + 16,
      ),
      onPressed: onPressed,
    );
  }

  Widget _buildPlayButton(MusicProvider musicProvider) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 1,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => musicProvider.togglePlayPause(),
          borderRadius: BorderRadius.circular(32),
          child: Icon(
            musicProvider.isPlaying
                ? Icons.pause_rounded
                : Icons.play_arrow_rounded,
            color: Colors.black87,
            size: 36,
          ),
        ),
      ),
    );
  }

  Widget _buildVolumeControl(BuildContext context, MusicProvider musicProvider) {
    IconData volumeIcon;
    if (musicProvider.volume == 0) {
      volumeIcon = Icons.volume_off_rounded;
    } else if (musicProvider.volume < 0.5) {
      volumeIcon = Icons.volume_down_rounded;
    } else {
      volumeIcon = Icons.volume_up_rounded;
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.05),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(
          volumeIcon,
          color: Colors.white.withValues(alpha: 0.9),
        ),
        iconSize: 24,
        onPressed: () {
          _showVolumeControlDialog(context);
        },
      ),
    );
  }

  void _showVolumeControlDialog(BuildContext context) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final Offset buttonPosition = button.localToGlobal(Offset.zero, ancestor: overlay);
    final Size buttonSize = button.size;

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      builder: (dialogContext) => Consumer<MusicProvider>(
        builder: (context, musicProvider, child) {
          return Stack(
            children: [
              Positioned(
                left: buttonPosition.dx + buttonSize.width / 2 - 35,
                bottom: overlay.size.height - buttonPosition.dy + 10,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: 70,
                    height: 240,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        InkWell(
                          onTap: () {
                            if (musicProvider.volume > 0) {
                              musicProvider.setVolume(0);
                            } else {
                              musicProvider.setVolume(0.5);
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
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: RotatedBox(
                            quarterTurns: 3,
                            child: SliderTheme(
                              data: const SliderThemeData(
                                trackHeight: 6,
                                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8),
                                overlayShape: RoundSliderOverlayShape(overlayRadius: 16),
                                activeTrackColor: Colors.white,
                                inactiveTrackColor: Colors.white54,
                                thumbColor: Colors.white,
                                overlayColor: Colors.white24,
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
                        Container(
                          width: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${(musicProvider.volume * 100).round()}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
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

  Widget _buildDownloadButton(BuildContext context, Song song) {
    return FutureBuilder<bool>(
      future: downloadService.isDownloaded(song.id),
      builder: (context, snapshot) {
        final isDownloaded = snapshot.data ?? false;

        return _buildSimpleButton(
          icon: isDownloaded ? Icons.download_done : Icons.download_outlined,
          size: 24,
          color: isDownloaded ? Colors.green : null,
          opacity: isDownloaded ? 0.5 : 1.0,
          onPressed: () async {
            if (isDownloaded) return;

            final manager = DownloadManager();
            await manager.init();
            final success = await manager.addDownload(song);

            if (!context.mounted) return;

            if (success) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.download, color: Colors.white, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '已添加到下载队列：${song.title}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: Colors.blue.shade700,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.all(16),
                  action: SnackBarAction(
                    label: '查看',
                    textColor: Colors.white,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DownloadProgressScreen(),
                        ),
                      );
                    },
                  ),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.white, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '《${song.title}》已在下载列表中',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: Colors.orange.shade700,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.all(16),
                ),
              );
            }
          },
        );
      },
    );
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
}
