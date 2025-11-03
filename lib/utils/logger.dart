/// 统一的日志工具
/// 可以通过设置 enableDebugLog 来控制是否输出调试日志
class Logger {
  // 是否启用调试日志（release模式下建议设为false）
  static const bool enableDebugLog = false;
  
  /// 调试日志
  static void debug(String message) {
    if (enableDebugLog) {
      print('🔍 $message');
    }
  }
  
  /// 信息日志（重要信息，始终输出）
  static void info(String message) {
    print('ℹ️ $message');
  }
  
  /// 警告日志
  static void warning(String message) {
    print('⚠️ $message');
  }
  
  /// 错误日志
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    print('❌ $message');
    if (error != null) {
      print('错误详情: $error');
    }
    if (stackTrace != null) {
      print('堆栈跟踪: $stackTrace');
    }
  }
  
  /// 成功日志
  static void success(String message) {
    if (enableDebugLog) {
      print('✅ $message');
    }
  }
}
