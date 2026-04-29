import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/play_mode.dart';
import '../../models/song.dart';
import '../../providers/music_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/download/download_service.dart';
import '../../utils/download_utils.dart';
import '../../utils/platform_utils.dart';
import '../../widgets/volume_control_dialog.dart';
import 'player_bottom_sheets.dart';
import 'widgets/player_favorite_button.dart';
import 'widgets/player_play_button.dart';
import 'widgets/player_progress_bar.dart';
import 'widgets/player_quality_speed_buttons.dart';

class PlayerControlPanel extends StatefulWidget {
  final DownloadService downloadService;

  const PlayerControlPanel({
    required this.downloadService,
    super.key,
  });

  @override
  State<PlayerControlPanel> createState() => _PlayerControlPanelState();
}

class _PlayerControlPanelState extends State<PlayerControlPanel> {
  DownloadService get downloadService => widget.downloadService;

  @override
  Widget build(BuildContext context) {
    final musicProvider = context.watch<MusicProvider>();
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
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isAndroid ? 20 : 24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const PlayerProgressBar(),
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

  Widget _buildAndroidControls(BuildContext context, MusicProvider musicProvider) {
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
            const PlayerPlayButton(),
            _buildSimpleButton(
              icon: Icons.skip_next_rounded,
              size: 36,
              onPressed: () => musicProvider.playNext(),
            ),
            const PlayerFavoriteButton(iconSize: 28, indicatorSize: 20),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const PlayerQualityButton(),
            const SizedBox(width: 16),
            const PlayerSpeedButton(),
            const SizedBox(width: 16),
            _buildSimpleButton(
              icon: Icons.timer_outlined,
              size: 22,
              onPressed: () => showSleepTimerDialog(context),
            ),
            const SizedBox(width: 16),
            _buildSimpleButton(
              icon: Icons.queue_music_rounded,
              size: 22,
              onPressed: () => showPlaylistDialog(context, musicProvider),
            ),
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
            const PlayerPlayButton(),
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
              const PlayerFavoriteButton(),
              const SizedBox(width: 16),
              if (PlatformUtils.isWindows && song != null)
                _buildDownloadButton(context, song),
              if (PlatformUtils.isWindows && song != null)
                const SizedBox(width: 16),
              _buildVolumeControl(context, musicProvider),
              const SizedBox(width: 16),
              const PlayerQualityButton(),
              const SizedBox(width: 16),
              const PlayerSpeedButton(),
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
          final colors = Provider.of<ThemeProvider>(context, listen: false).colors;
          showVolumeControlDialog(
            context,
            colors: colors,
            isPlayerScreen: true,
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

            final result = await DownloadService().addDownload(song);

            if (!mounted) return;

            DownloadUtils.handleAddDownloadResult(context, result, song.title);
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
