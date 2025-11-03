import 'dart:async';
import 'package:flutter/foundation.dart';

/// 定时关闭服务
class SleepTimerService extends ChangeNotifier {
  Timer? _timer;
  Duration? _remainingTime;
  DateTime? _endTime;
  bool _isActive = false;

  bool get isActive => _isActive;
  Duration? get remainingTime => _remainingTime;
  
  /// 设置定时关闭
  void setTimer(Duration duration, VoidCallback onComplete) {
    cancel(); // 取消之前的定时器
    
    _endTime = DateTime.now().add(duration);
    _remainingTime = duration;
    _isActive = true;
    
    // 每秒更新剩余时间
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      if (now.isAfter(_endTime!)) {
        // 时间到，执行回调
        onComplete();
        cancel();
      } else {
        _remainingTime = _endTime!.difference(now);
        notifyListeners();
      }
    });
    
    notifyListeners();
  }
  
  /// 取消定时关闭
  void cancel() {
    _timer?.cancel();
    _timer = null;
    _remainingTime = null;
    _endTime = null;
    _isActive = false;
    notifyListeners();
  }
  
  /// 格式化剩余时间
  String formatRemainingTime() {
    if (_remainingTime == null) return '';
    
    final hours = _remainingTime!.inHours;
    final minutes = _remainingTime!.inMinutes.remainder(60);
    final seconds = _remainingTime!.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }
  
  @override
  void dispose() {
    cancel();
    super.dispose();
  }
}
