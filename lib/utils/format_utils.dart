/// 格式化工具类
/// 统一提供常用的格式化方法
class FormatUtils {
  /// 格式化文件大小
  /// [bytes] 文件大小（字节）
  /// 返回格式化后的字符串（如 "1.23 MB"）
  static String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
