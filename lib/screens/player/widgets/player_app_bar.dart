import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/audio_settings_provider.dart';
import '../../../theme/app_styles.dart';
import '../../../utils/platform_utils.dart';
import '../../../widgets/draggable_window_area.dart';
import '../player_bottom_sheets.dart';

class PlayerAppBar extends StatelessWidget {
  final ThemeColors colors;
  final Future<void> Function() onLoadLyrics;

  const PlayerAppBar({
    required this.colors,
    required this.onLoadLyrics,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = PlatformUtils.isDesktop;
    final isAndroid = PlatformUtils.isAndroid;

    return Stack(
      children: [
        if (isDesktop)
          const Positioned(
            top: 0,
            left: 60,
            right: 60,
            height: 56,
            child: DraggableWindowArea(
              child: SizedBox.expand(),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: colors.textPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  icon: Icon(Icons.expand_more, color: colors.textPrimary, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Consumer<AudioSettingsProvider>(
                builder: (context, audioSettings, child) {
                  return Container(
                    decoration: BoxDecoration(
                      color: colors.textPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: IconButton(
                      icon: Icon(
                        audioSettings.showLyricsTranslation
                            ? Icons.translate_rounded
                            : Icons.translate_outlined,
                        color: audioSettings.showLyricsTranslation
                            ? colors.accent
                            : colors.textPrimary,
                        size: 24,
                      ),
                      onPressed: () {
                        audioSettings.setShowLyricsTranslation(
                          !audioSettings.showLyricsTranslation,
                        );
                        unawaited(onLoadLyrics());
                      },
                    ),
                  );
                },
              ),
              if (isAndroid)
                Container(
                  decoration: BoxDecoration(
                    color: colors.textPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.more_horiz, color: colors.textPrimary, size: 24),
                    onPressed: () => showPlayerMoreMenu(context),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
