import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/music_provider.dart';
import '../../theme/app_styles.dart';

/// 显示音量控制弹窗
void showVolumeControlDialog(
  BuildContext context, {
  required ThemeColors colors,
  bool isPlayerScreen = false,
}) {
  final buttonRenderObject = context.findRenderObject();
  final overlayRenderObject = Overlay.of(context).context.findRenderObject();
  if (buttonRenderObject is! RenderBox || overlayRenderObject is! RenderBox) return;

  final RenderBox button = buttonRenderObject;
  final RenderBox overlay = overlayRenderObject;
  final Offset buttonPosition =
      button.localToGlobal(Offset.zero, ancestor: overlay);
  final Size buttonSize = button.size;

  showDialog<void>(
    context: context,
    barrierColor: Colors.transparent,
    builder: (dialogContext) => _VolumeControlContent(
      buttonPosition: buttonPosition,
      overlaySize: overlay.size,
      buttonSize: buttonSize,
      colors: colors,
      isPlayerScreen: isPlayerScreen,
    ),
  );
}

class _VolumeControlContent extends StatefulWidget {
  final Offset buttonPosition;
  final Size overlaySize;
  final Size buttonSize;
  final ThemeColors colors;
  final bool isPlayerScreen;

  const _VolumeControlContent({
    required this.buttonPosition,
    required this.overlaySize,
    required this.buttonSize,
    required this.colors,
    required this.isPlayerScreen,
  });

  @override
  State<_VolumeControlContent> createState() => _VolumeControlContentState();
}

class _VolumeControlContentState extends State<_VolumeControlContent> {
  double _volumeBeforeMute = 0.5;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;

    return Stack(
      children: [
        Positioned(
          left: widget.buttonPosition.dx + widget.buttonSize.width / 2 - 35,
          bottom: widget.overlaySize.height - widget.buttonPosition.dy + 10,
          child: Material(
            color: Colors.transparent,
            child: Consumer<MusicProvider>(
              builder: (context, musicProvider, child) {
                return Container(
                  width: 70,
                  height: 240,
                  decoration: BoxDecoration(
                    color: widget.isPlayerScreen
                        ? Colors.black.withValues(alpha: 0.85)
                        : colors.surface.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: widget.isPlayerScreen
                          ? Colors.white.withValues(alpha: 0.1)
                          : colors.border,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 12,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildMuteToggle(musicProvider, colors),
                      const SizedBox(height: 16),
                      Expanded(
                        child: _buildSlider(musicProvider, colors),
                      ),
                      const SizedBox(height: 12),
                      _buildVolumeLabel(musicProvider, colors),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMuteToggle(MusicProvider musicProvider, ThemeColors colors) {
    return InkWell(
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
          color: widget.isPlayerScreen ? Colors.white : colors.textPrimary,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildSlider(MusicProvider musicProvider, ThemeColors colors) {
    final activeColor = widget.isPlayerScreen ? Colors.white : colors.accent;
    final inactiveColor = widget.isPlayerScreen
        ? Colors.white54
        : colors.border.withValues(alpha: 0.3);
    final overlayColor = widget.isPlayerScreen
        ? Colors.white24
        : colors.accent.withValues(alpha: 0.2);

    return RotatedBox(
      quarterTurns: 3,
      child: SliderTheme(
        data: SliderThemeData(
          trackHeight: 6,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          activeTrackColor: activeColor,
          inactiveTrackColor: inactiveColor,
          thumbColor: Colors.white,
          overlayColor: overlayColor,
        ),
        child: Slider(
          value: musicProvider.volume,
          onChanged: (value) {
            musicProvider.setVolume(value);
          },
        ),
      ),
    );
  }

  Widget _buildVolumeLabel(MusicProvider musicProvider, ThemeColors colors) {
    final labelColor =
        widget.isPlayerScreen ? Colors.white : colors.accent;
    final bgColor = widget.isPlayerScreen
        ? Colors.white.withValues(alpha: 0.1)
        : colors.accent.withValues(alpha: 0.1);

    return Container(
      width: widget.isPlayerScreen ? 36 : 42,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${(musicProvider.volume * 100).round()}',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: labelColor,
          fontSize: widget.isPlayerScreen ? 13 : 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
