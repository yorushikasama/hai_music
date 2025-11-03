/// Duration 扩展方法
extension DurationExtension on Duration {
  /// 格式化为 "mm:ss" 格式
  String toMinutesSeconds() {
    final minutes = inMinutes;
    final seconds = inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// 格式化为 "hh:mm:ss" 格式
  String toHoursMinutesSeconds() {
    final hours = inHours;
    final minutes = inMinutes % 60;
    final seconds = inSeconds % 60;
    
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// 格式化为中文格式 "x分x秒"
  String toChineseFormat() {
    final minutes = inMinutes;
    final seconds = inSeconds % 60;
    
    if (minutes > 0) {
      return seconds > 0 ? '$minutes分$seconds秒' : '$minutes分';
    }
    return '$seconds秒';
  }

  /// 格式化为简短格式（自动选择最合适的单位）
  String toShortFormat() {
    final hours = inHours;
    final minutes = inMinutes;
    final seconds = inSeconds;
    
    if (hours > 0) {
      final remainingMinutes = minutes % 60;
      return remainingMinutes > 0 ? '$hours小时$remainingMinutes分' : '$hours小时';
    } else if (minutes > 0) {
      return '$minutes分钟';
    } else {
      return '$seconds秒';
    }
  }

  /// 获取进度百分比
  double progressPercentage(Duration total) {
    if (total.inMilliseconds == 0) return 0.0;
    return (inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
  }

  /// 是否为零
  bool get isZero => inMilliseconds == 0;

  /// 是否有效（大于零）
  bool get isValid => inMilliseconds > 0;
}
