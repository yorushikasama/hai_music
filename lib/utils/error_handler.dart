import 'package:flutter/material.dart';

/// 统一的错误处理工具类
class ErrorHandler {
  /// 记录错误日志
  static void logError(String operation, dynamic error, [StackTrace? stackTrace]) {
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('❌ 错误发生在: $operation');
    debugPrint('错误信息: $error');
    if (stackTrace != null) {
      debugPrint('堆栈跟踪:\n$stackTrace');
    }
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }
}
