import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/audio_quality.dart';
import '../../../providers/audio_settings_provider.dart';
import '../../../providers/music_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../widgets/audio_quality_selector.dart';
import '../../../widgets/speed_selector.dart';

/// 播放器音质选择按钮
class PlayerQualityButton extends StatelessWidget {
  const PlayerQualityButton({super.key});

  @override
  Widget build(BuildContext context) {
    final audioSettings = Provider.of<AudioSettingsProvider>(context);
    final quality = audioSettings.audioQuality;
    final isSwitching = audioSettings.isQualitySwitching;
    final switchResult = audioSettings.switchResult;
    final isFailed = switchResult == QualitySwitchResult.failed;
    final isSuccess = switchResult == QualitySwitchResult.success;

    Color borderColor;
    if (isFailed) {
      borderColor = Colors.red.withValues(alpha: 0.5);
    } else if (isSuccess) {
      borderColor = Colors.green.withValues(alpha: 0.5);
    } else {
      borderColor = quality.color.withValues(alpha: 0.3);
    }

    return Semantics(
      label: isSwitching
          ? '正在切换音质...'
          : isFailed
              ? '音质切换失败'
              : '音质选择，当前: ${quality.semanticLabel}',
      button: true,
      child: TextButton(
        onPressed: isSwitching
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
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                quality.gradientStart.withValues(alpha: 0.25),
                quality.gradientEnd.withValues(alpha: 0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildIcon(quality, isSwitching, isFailed, isSuccess),
              const SizedBox(width: 4),
              _buildLabel(quality, isFailed),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(
    AudioQuality quality,
    bool isSwitching,
    bool isFailed,
    bool isSuccess,
  ) {
    if (isSwitching) {
      return SizedBox(
        width: 15,
        height: 15,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: quality.color.withValues(alpha: 0.9),
        ),
      );
    }
    if (isFailed) {
      return Icon(
        Icons.error_outline_rounded,
        key: const ValueKey('quality_failed'),
        size: 15,
        color: Colors.red.withValues(alpha: 0.9),
      );
    }
    if (isSuccess) {
      return Icon(
        Icons.check_circle_outline_rounded,
        key: const ValueKey('quality_success'),
        size: 15,
        color: Colors.green.withValues(alpha: 0.9),
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        return ScaleTransition(scale: animation, child: child);
      },
      child: Icon(
        quality.icon,
        key: ValueKey(quality.name),
        size: 15,
        color: quality.color.withValues(alpha: 0.9),
      ),
    );
  }

  Widget _buildLabel(AudioQuality quality, bool isFailed) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: Text(
        isFailed ? '失败' : quality.label,
        key: ValueKey(isFailed ? 'failed' : quality.label),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isFailed
              ? Colors.red.withValues(alpha: 0.95)
              : quality.color.withValues(alpha: 0.95),
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// 播放器速度选择按钮
class PlayerSpeedButton extends StatelessWidget {
  const PlayerSpeedButton({super.key});

  @override
  Widget build(BuildContext context) {
    final musicProvider = Provider.of<MusicProvider>(context);
    final currentSpeed = musicProvider.playbackSpeed;
    final colors = Provider.of<ThemeProvider>(context).colors;

    return Semantics(
      label: currentSpeed.semanticLabel,
      button: true,
      child: TextButton(
        onPressed: () => showSpeedSelector(context),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: currentSpeed.isNormal
                ? colors.accent.withValues(alpha: 0.1)
                : colors.accent.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: currentSpeed.isNormal
                  ? colors.border.withValues(alpha: 0.3)
                  : colors.accent.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.speed_rounded,
                size: 15,
                color: currentSpeed.isNormal
                    ? colors.textSecondary.withValues(alpha: 0.7)
                    : colors.accent.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight:
                      currentSpeed.isNormal ? FontWeight.w600 : FontWeight.w700,
                  color: currentSpeed.isNormal
                      ? colors.textSecondary.withValues(alpha: 0.7)
                      : colors.accent.withValues(alpha: 0.95),
                  letterSpacing: 0.3,
                ),
                child: Text(currentSpeed.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
