import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../extensions/duration_extension.dart';
import '../../providers/music_provider.dart';
import '../../providers/sleep_timer_provider.dart';
import '../../utils/snackbar_util.dart';
import 'widgets/player_more_menu_sheet.dart';
import 'widgets/player_playlist_sheet.dart';

/// 显示播放器的"更多"菜单 bottom sheet
void showPlayerMoreMenu(BuildContext rootContext) {
  showModalBottomSheet<void>(
    context: rootContext,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => PlayerMoreMenuSheet(rootContext: rootContext),
  );
}

/// 显示定时关闭对话框
void showSleepTimerDialog(BuildContext context) {
  final sleepTimerProvider = Provider.of<SleepTimerProvider>(context, listen: false);

  if (sleepTimerProvider.sleepTimer.isActive) {
    _showActiveSleepTimerDialog(context, sleepTimerProvider);
    return;
  }

  const initialDuration = Duration(minutes: 30);

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      Duration selectedDuration = initialDuration;
      return StatefulBuilder(
        builder: (innerContext, setState) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDragHandle(),
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    '定时关闭',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(
                  height: 180,
                  child: CupertinoTimerPicker(
                    mode: CupertinoTimerPickerMode.hm,
                    initialTimerDuration: selectedDuration,
                    onTimerDurationChanged: (duration) {
                      setState(() => selectedDuration = duration);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: const Text('取消', style: TextStyle(color: Colors.white70)),
                      ),
                      TextButton(
                        onPressed: () {
                          if (selectedDuration.inSeconds <= 0) {
                            AppSnackBar.showWithContext(
                              context,
                              '请选择有效的时间',
                              type: SnackBarType.warning,
                            );
                            return;
                          }

                          sleepTimerProvider.startSleepTimer(selectedDuration);
                          Navigator.pop(sheetContext);

                          final timeText = selectedDuration.toShortFormat();
                          AppSnackBar.show(
                            '定时关闭已启动：$timeText后暂停播放',
                            duration: const Duration(seconds: 3),
                            actionLabel: '取消',
                            onAction: sleepTimerProvider.cancelSleepTimer,
                          );
                        },
                        child: const Text('开始定时', style: TextStyle(color: Colors.blue)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      );
    },
  );
}

/// 显示已激活的定时器管理界面
void _showActiveSleepTimerDialog(BuildContext context, SleepTimerProvider sleepTimerProvider) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDragHandle(),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    '定时关闭已启动',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Consumer<SleepTimerProvider>(
                    builder: (context, provider, child) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                        ),
                        child: Column(
                          children: [
                            const Text('剩余时间', style: TextStyle(color: Colors.white70, fontSize: 14)),
                            const SizedBox(height: 8),
                            Text(
                              provider.sleepTimer.formattedRemainingTime,
                              style: const TextStyle(
                                color: Colors.orange,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            sleepTimerProvider.extendSleepTimer(const Duration(minutes: 15));
                            AppSnackBar.showWithContext(context, '已延长15分钟');
                          },
                          icon: const Icon(Icons.add, color: Colors.white),
                          label: const Text('延长15分钟', style: TextStyle(color: Colors.white)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white30),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            sleepTimerProvider.cancelSleepTimer();
                            Navigator.pop(sheetContext);
                            AppSnackBar.show('定时关闭已取消');
                          },
                          icon: const Icon(Icons.close),
                          label: const Text('取消定时'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      );
    },
  );
}

/// 显示播放列表 bottom sheet
void showPlaylistDialog(BuildContext context, MusicProvider musicProvider) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => PlayerPlaylistSheet(musicProvider: musicProvider),
  );
}

Widget _buildDragHandle() {
  return Container(
    margin: const EdgeInsets.only(top: 12, bottom: 8),
    width: 40,
    height: 4,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(2),
    ),
  );
}
