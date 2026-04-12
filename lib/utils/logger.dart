import 'package:flutter/foundation.dart';

/// 统一的日志工具
/// 可以通过设置 enableDebugLog 来控制是否输出调试日志
class Logger {
  // 是否启用调试日志（debug模式默认开启，release模式关闭）
  static bool enableDebugLog = kDebugMode;
  
  /// 调试日志（仅在 debug 模式或手动开启时输出）
  static void debug(String message, [String? tag]) {
    if (enableDebugLog) {
      final prefix = tag != null ? '[$tag] ' : '';
      debugPrint('🔍 $prefix$message');
    }
  }
  
  /// 信息日志（重要信息，始终输出）
  static void info(String message, [String? tag]) {
    final prefix = tag != null ? '[$tag] ' : '';
    debugPrint('ℹ️ $prefix$message');
  }
  
  /// 警告日志
  static void warning(String message, [String? tag]) {
    final prefix = tag != null ? '[$tag] ' : '';
    debugPrint('⚠️ $prefix$message');
  }
  
  /// 错误日志
  static void error(String message, [Object? error, StackTrace? stackTrace, String? tag]) {
    final prefix = tag != null ? '[$tag] ' : '';
    debugPrint('❌ $prefix$message');
    if (error != null) {
      debugPrint('错误详情: $error');
    }
    if (stackTrace != null) {
      debugPrint('堆栈跟踪:\n$stackTrace');
    }
  }
  
  /// 成功日志
  static void success(String message, [String? tag]) {
    final prefix = tag != null ? '[$tag] ' : '';
    debugPrint('✅ $prefix$message');
  }

  /// 网络请求日志
  static void network(String message, [String? tag]) {
    if (enableDebugLog) {
      final prefix = tag != null ? '[$tag] ' : '';
      debugPrint('🌐 $prefix$message');
    }
  }

  /// 数据库操作日志
  static void database(String message, [String? tag]) {
    if (enableDebugLog) {
      final prefix = tag != null ? '[$tag] ' : '';
      debugPrint('💾 $prefix$message');
    }
  }

  /// 缓存操作日志
  static void cache(String message, [String? tag]) {
    if (enableDebugLog) {
      final prefix = tag != null ? '[$tag] ' : '';
      debugPrint('📦 $prefix$message');
    }
  }

  /// 下载日志
  static void download(String message, [String? tag]) {
    if (enableDebugLog) {
      final prefix = tag != null ? '[$tag] ' : '';
      debugPrint('⬇️ $prefix$message');
    }
  }
}
