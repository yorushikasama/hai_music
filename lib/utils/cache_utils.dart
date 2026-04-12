class CacheUtils {
  static bool isCacheExpired(int timestamp, {int hours = 24}) {
    if (timestamp == 0) return true;

    final now = DateTime.now().millisecondsSinceEpoch;
    final expiryDuration = hours * 60 * 60 * 1000;

    return (now - timestamp) > expiryDuration;
  }

  static int getCurrentTimestamp() {
    return DateTime.now().millisecondsSinceEpoch;
  }
}
