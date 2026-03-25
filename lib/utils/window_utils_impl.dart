// 非Web平台的窗口操作实现

import 'package:bitsdojo_window/bitsdojo_window.dart';

/// 窗口操作工具类（非Web平台实现）
class WindowUtils {
  /// 关闭窗口
  static void close() {
    try {
      appWindow.close();
    } catch (e) {
      // 忽略错误
    }
  }

  /// 最小化窗口
  static void minimize() {
    try {
      appWindow.minimize();
    } catch (e) {
      // 忽略错误
    }
  }

  /// 最大化或恢复窗口
  static void maximizeOrRestore() {
    try {
      appWindow.maximizeOrRestore();
    } catch (e) {
      // 忽略错误
    }
  }

  /// 开始拖动窗口
  static void startDragging() {
    try {
      appWindow.startDragging();
    } catch (e) {
      // 忽略错误
    }
  }
}
