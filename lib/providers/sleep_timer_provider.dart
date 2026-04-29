import 'package:flutter/foundation.dart';

import '../services/ui/sleep_timer_service.dart';
import '../utils/logger.dart';

class SleepTimerProvider extends ChangeNotifier {
  final SleepTimerService _sleepTimer = SleepTimerService();
  final VoidCallback? _onPausePlayback;

  SleepTimerProvider({VoidCallback? onPausePlayback}) : _onPausePlayback = onPausePlayback {
    _sleepTimer.addListener(_onSleepTimerChanged);
  }

  SleepTimerService get sleepTimer => _sleepTimer;

  void _onSleepTimerChanged() {
    notifyListeners();
  }

  void startSleepTimer(Duration duration) {
    _sleepTimer.start(duration, () {
      _onPausePlayback?.call();
      Logger.success('睡眠定时器触发，已暂停播放', 'SleepTimerProvider');
    });
  }

  void cancelSleepTimer() {
    _sleepTimer.cancel();
  }

  void extendSleepTimer(Duration additionalDuration) {
    _sleepTimer.extend(additionalDuration);
  }

  @override
  void dispose() {
    _sleepTimer.removeListener(_onSleepTimerChanged);
    _sleepTimer.dispose();
    super.dispose();
  }
}
