import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/audio_quality.dart';
import '../../models/play_mode.dart';
import '../../providers/audio_settings_provider.dart';
import '../../providers/favorite_provider.dart';
import '../../providers/music_provider.dart';
import '../../theme/app_styles.dart';
import '../../widgets/audio_quality_selector.dart';
import '../../widgets/volume_control_dialog.dart';

/// 迷你播放器 Windows 端控制按钮组
class MiniPlayerWindowsControls extends StatelessWidget {
  final MusicProvider musicProvider;
  final ThemeColors colors;
  final String songId;

  const MiniPlayerWindowsControls({
    required this.musicProvider,
    required this.colors,
    required this.songId,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final favoriteProvider = Provider.of<FavoriteProvider>(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.skip_previous),
          iconSize: 24,
          color: colors.textPrimary,
          onPressed: () => musicProvider.playPrevious(),
        ),
        _buildPlayPauseButton(),
        IconButton(
          icon: const Icon(Icons.skip_next),
          iconSize: 24,
          color: colors.textPrimary,
          onPressed: () => musicProvider.playNext(),
        ),
        const SizedBox(width: 4),
        _buildVolumeButton(),
        _buildPlayModeButton(),
        _buildQualityButton(context),
        _buildFavoriteButton(favoriteProvider),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildPlayPauseButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppStyles.spacingXS),
      decoration: BoxDecoration(
        color: colors.accent,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(
          musicProvider.isPlaying ? Icons.pause : Icons.play_arrow,
        ),
        iconSize: 24,
        color: Colors.white,
        onPressed: () => musicProvider.togglePlayPause(),
      ),
    );
  }

  Widget _buildVolumeButton() {
    return Builder(
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
          showVolumeControlDialog(context, colors: colors);
        },
      ),
    );
  }

  Widget _buildPlayModeButton() {
    return Builder(
      builder: (context) => IconButton(
        icon: Icon(_getPlayModeIcon(musicProvider.playMode)),
        iconSize: 20,
        color: musicProvider.playMode == PlayMode.sequence
            ? colors.textSecondary
            : colors.accent,
        tooltip: '播放模式',
        onPressed: () => musicProvider.togglePlayMode(),
      ),
    );
  }

  Widget _buildQualityButton(BuildContext context) {
    return Builder(
      builder: (context) {
        final audioSettings = Provider.of<AudioSettingsProvider>(context);
        final quality = audioSettings.audioQuality;
        final isSwitching = audioSettings.isQualitySwitching;
        final switchResult = audioSettings.switchResult;
        final isFailed = switchResult == QualitySwitchResult.failed;
        final isSuccess = switchResult == QualitySwitchResult.success;

        Color borderColor;
        if (isFailed) {
          borderColor = Colors.red.withValues(alpha: 0.4);
        } else if (isSuccess) {
          borderColor = Colors.green.withValues(alpha: 0.4);
        } else {
          borderColor = quality.color.withValues(alpha: 0.25);
        }

        return Semantics(
          label: isSwitching
              ? '正在切换音质...'
              : isFailed
                  ? '音质切换失败'
                  : '音质选择，当前: ${quality.semanticLabel}',
          button: true,
          child: GestureDetector(
            onTap: isSwitching
                ? null
                : () {
                    if (isFailed) {
                      audioSettings.clearSwitchError();
                    }
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
                    quality.gradientStart.withValues(alpha: 0.2),
                    quality.gradientEnd.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildQualityIcon(quality, isSwitching, isFailed, isSuccess),
                  const SizedBox(width: 3),
                  _buildQualityLabel(quality, isFailed),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQualityIcon(
    AudioQuality quality,
    bool isSwitching,
    bool isFailed,
    bool isSuccess,
  ) {
    if (isSwitching) {
      return SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          color: quality.color,
        ),
      );
    }
    if (isFailed) {
      return const Icon(
        Icons.error_outline_rounded,
        key: ValueKey('quality_failed'),
        size: 14,
        color: Colors.red,
      );
    }
    if (isSuccess) {
      return const Icon(
        Icons.check_circle_outline_rounded,
        key: ValueKey('quality_success'),
        size: 14,
        color: Colors.green,
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) =>
          ScaleTransition(scale: animation, child: child),
      child: Icon(
        quality.icon,
        key: ValueKey(quality.name),
        size: 14,
        color: quality.color,
      ),
    );
  }

  Widget _buildQualityLabel(AudioQuality quality, bool isFailed) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: Text(
        isFailed ? '失败' : quality.label,
        key: ValueKey(isFailed ? 'failed' : quality.label),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isFailed ? Colors.red : quality.color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildFavoriteButton(FavoriteProvider favoriteProvider) {
    return Builder(
      builder: (innerContext) => IconButton(
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
          Provider.of<FavoriteProvider>(
            innerContext,
            listen: false,
          ).toggleFavorite(
            songId,
            currentSong: musicProvider.currentSong,
            playlist: musicProvider.playlist,
          );
        },
      ),
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
