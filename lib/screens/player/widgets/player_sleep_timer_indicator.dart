import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/sleep_timer_provider.dart';
import '../../../theme/app_styles.dart';
import '../player_bottom_sheets.dart';

class PlayerSleepTimerIndicator extends StatelessWidget {
  final ThemeColors colors;

  const PlayerSleepTimerIndicator({
    required this.colors,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final sleepTimerProvider = Provider.of<SleepTimerProvider>(context);
    if (!sleepTimerProvider.sleepTimer.isActive) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: GestureDetector(
        onTap: () => showSleepTimerDialog(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: colors.warning.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colors.warning.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.timer,
                size: 18,
                color: colors.warning,
              ),
              const SizedBox(width: 8),
              Text(
                '定时关闭: ${sleepTimerProvider.sleepTimer.formattedRemainingTime}',
                style: TextStyle(
                  color: colors.warning,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: colors.warning.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
