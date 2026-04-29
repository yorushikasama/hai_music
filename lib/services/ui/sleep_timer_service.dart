import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../extensions/duration_extension.dart';
import '../../utils/logger.dart';

/// 睡眠定时器服务
/// 用于在指定时间后自动暂停音乐播放
class SleepTimerService extends ChangeNotifier {
  Timer? _timer;
  Duration? _remainingTime;
  DateTime? _endTime;
  int? _lastNotifiedMinute;
  
  /// 定时器是否激活
  bool get isActive => _timer != null && _timer!.isActive;
  
  /// 剩余时间
  Duration? get remainingTime => _remainingTime;
  
  /// 结束时间
  DateTime? get endTime => _endTime;
  
  /// 格式化剩余时间显示（如：15:30）
  String get formattedRemainingTime {
    if (_remainingTime == null) return '';
    return _remainingTime!.toHoursMinutesSeconds();
  }
  
  /// 开始定时器
  /// [duration] 定时时长
  /// [onComplete] 定时结束时的回调函数
  void start(Duration duration, VoidCallback onComplete) {
    if (duration.inSeconds <= 0) {
      Logger.warning('定时时长必须大于0', 'SleepTimer');
      return;
    }
    
    // 取消之前的定时器
    cancel();
    
    _endTime = DateTime.now().add(duration);
    _remainingTime = duration;
    _lastNotifiedMinute = null;
    
    Logger.info('启动睡眠定时器: ${duration.inMinutes}分钟', 'SleepTimer');
    
    // 每秒更新一次剩余时间
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _remainingTime = _endTime!.difference(DateTime.now());
      if (_remainingTime!.isNegative) _remainingTime = Duration.zero;

      if (_remainingTime!.inSeconds <= 0) {
        Logger.info('睡眠定时器结束，执行回调', 'SleepTimer');
        cancel();
        try {
          onComplete();
        } catch (e) {
          Logger.error('睡眠定时器回调执行失败', e, null, 'SleepTimer');
        }
        return;
      } else {
        final currentMinute = _remainingTime!.inMinutes;
        if (_lastNotifiedMinute != currentMinute) {
          _lastNotifiedMinute = currentMinute;
        }
      }

      notifyListeners();
    });
    
    notifyListeners();
  }
  
  /// 取消定时器
  void cancel() {
    _timer?.cancel();
    if (_timer != null) {
      Logger.info('取消睡眠定时器', 'SleepTimer');
    }
    _timer = null;
    _remainingTime = null;
    _endTime = null;
    notifyListeners();
  }
  
  /// 延长定时器时间
  /// [additionalDuration] 要延长的时长
  void extend(Duration additionalDuration) {
    if (!isActive) {
      Logger.warning('定时器未激活，无法延长', 'SleepTimer');
      return;
    }
    
    _endTime = _endTime!.add(additionalDuration);
    _remainingTime = _endTime!.difference(DateTime.now());
    
    Logger.info('延长睡眠定时器: ${additionalDuration.inMinutes}分钟', 'SleepTimer');
    notifyListeners();
  }
  
  @override
  void dispose() {
    cancel();
    super.dispose();
  }
}
