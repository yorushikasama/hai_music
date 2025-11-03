import 'package:flutter/material.dart';

/// 统一的错误处理工具类
class ErrorHandler {
  /// 显示错误提示
  static void showError(BuildContext context, String message, {dynamic error}) {
    if (error != null) {
      debugPrint('❌ 错误: $message - $error');
    } else {
      debugPrint('❌ 错误: $message');
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: '关闭',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  /// 显示成功提示
  static void showSuccess(BuildContext context, String message) {
    debugPrint('✅ 成功: $message');
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 显示警告提示
  static void showWarning(BuildContext context, String message) {
    debugPrint('⚠️ 警告: $message');
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 处理网络错误
  static String handleNetworkError(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    
    if (errorStr.contains('socket') || errorStr.contains('network')) {
      return '网络连接失败，请检查网络设置';
    } else if (errorStr.contains('timeout')) {
      return '请求超时，请稍后重试';
    } else if (errorStr.contains('404')) {
      return '请求的资源不存在';
    } else if (errorStr.contains('500') || errorStr.contains('502') || errorStr.contains('503')) {
      return '服务器错误，请稍后重试';
    } else {
      return '操作失败，请重试';
    }
  }

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
