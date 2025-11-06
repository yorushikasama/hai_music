import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

/// 平台判断工具类
/// 统一管理所有平台相关的判断逻辑,避免重复代码
class PlatformUtils {
  /// 是否为 Web 平台
  static bool get isWeb => kIsWeb;

  /// 是否为桌面平台 (Windows/macOS/Linux)
  static bool get isDesktop => !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  /// 是否为 Windows 平台
  static bool get isWindows => !kIsWeb && Platform.isWindows;

  /// 是否为 macOS 平台
  static bool get isMacOS => !kIsWeb && Platform.isMacOS;

  /// 是否为 Linux 平台
  static bool get isLinux => !kIsWeb && Platform.isLinux;

  /// 是否为移动平台 (Android/iOS)
  static bool get isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// 是否为 Android 平台
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;

  /// 是否为 iOS 平台
  static bool get isIOS => !kIsWeb && Platform.isIOS;

  /// 是否支持窗口拖动 (桌面平台)
  static bool get supportsWindowDragging => isDesktop;

  /// 是否支持后台播放 (移动平台)
  static bool get supportsBackgroundPlayback => isMobile;

  /// 获取平台名称
  static String get platformName {
    if (kIsWeb) return 'Web';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    return 'Unknown';
  }
}

