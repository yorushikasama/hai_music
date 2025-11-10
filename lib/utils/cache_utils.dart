/// 缓存工具类
/// 统一管理缓存过期检查逻辑
class CacheUtils {
  /// 检查缓存是否过期
  /// 
  /// [timestamp] 缓存时间戳 (毫秒)
  /// [hours] 过期时间 (小时),默认 24 小时
  /// 
  /// 返回 true 表示缓存已过期,需要刷新
  static bool isCacheExpired(int timestamp, {int hours = 24}) {
    if (timestamp == 0) return true;
    
    final now = DateTime.now().millisecondsSinceEpoch;
    final expiryDuration = hours * 60 * 60 * 1000; // 转换为毫秒
    
    return (now - timestamp) > expiryDuration;
  }

  /// 检查缓存是否过期 (使用 DateTime 对象)
  /// 
  /// [cachedTime] 缓存时间
  /// [duration] 过期时长
  /// 
  /// 返回 true 表示缓存已过期,需要刷新
  static bool isCacheExpiredByDateTime(DateTime? cachedTime, Duration duration) {
    if (cachedTime == null) return true;
    
    final now = DateTime.now();
    return now.difference(cachedTime) > duration;
  }

  /// 获取当前时间戳 (毫秒)
  static int getCurrentTimestamp() {
    return DateTime.now().millisecondsSinceEpoch;
  }
}

