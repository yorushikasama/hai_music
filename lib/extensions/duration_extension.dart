extension DurationExtension on Duration {
  String toMinutesSeconds() {
    final minutes = inMinutes;
    final seconds = inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String toHoursMinutesSeconds() {
    final hours = inHours;
    final minutes = inMinutes % 60;
    final seconds = inSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

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
}
