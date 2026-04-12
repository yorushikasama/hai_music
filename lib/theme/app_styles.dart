import 'dart:ui';

import 'package:flutter/material.dart';

/// 统一样式常量 - 颜色、间距、圆角、阴影、模糊
class AppStyles {
  AppStyles._();

  // ============ 圆角 ============
  static const double radiusSmall = 10.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;

  // ============ 间距 ============
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 12.0;
  static const double spacingL = 16.0;
  static const double spacingXL = 20.0;

  static const double blurStrength = 20.0;

  static const double sidebarWidth = 240.0;

  // ============ 阴影（根据主题亮暗自动调整） ============
  static List<BoxShadow> getShadows(bool isLight) {
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: isLight ? 0.05 : 0.15),
        blurRadius: isLight ? 16 : 15,
        offset: const Offset(0, 4),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: isLight ? 0.03 : 0.1),
        blurRadius: isLight ? 24 : 30,
        offset: const Offset(0, 8),
      ),
    ];
  }

  // ============ 毛玻璃装饰生成器 ============
  static BoxDecoration glassDecoration({
    required Color color,
    required double opacity,
    required Color borderColor,
    required bool isLight,
    BorderRadius? borderRadius,
  }) {
    return BoxDecoration(
      color: color.withValues(alpha: opacity),
      borderRadius: borderRadius ?? BorderRadius.circular(radiusLarge),
      border: Border.all(color: borderColor),
      boxShadow: getShadows(isLight),
    );
  }

  // ============ 背景模糊滤镜 ============
  static ImageFilter get backdropBlur => ImageFilter.blur(
        sigmaX: blurStrength,
        sigmaY: blurStrength,
      );
}

/// 主题颜色配置
class ThemeColors {
  final Color background;
  final Color surface;
  final Color card;
  final Color primary;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final Color border;
  final Gradient? backgroundGradient;
  final bool isLight;
  final Color error;
  final Color warning;
  final Color success;
  final Color info;
  final Color favorite;

  const ThemeColors({
    required this.background,
    required this.surface,
    required this.card,
    required this.primary,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.border,
    this.backgroundGradient,
    this.isLight = false,
    this.error = Colors.red,
    this.warning = Colors.orange,
    this.success = Colors.green,
    this.info = Colors.blue,
    this.favorite = Colors.red,
  });

  // 深色主题
  static const dark = ThemeColors(
    background: Color(0xFF000000),
    surface: Color(0xFF0A0A0A),
    card: Color(0xFF1A1A1A),
    primary: Color(0xFFFFFFFF),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF9E9E9E),
    accent: Color(0xFF3B82F6),
    border: Color(0x1AFFFFFF),
  );

  // 浅色主题
  static const light = ThemeColors(
    background: Color(0xFFF5F5F5),
    surface: Color(0xFFFFFFFF),
    card: Color(0xFFFAFAFA),
    primary: Color(0xFF000000),
    textPrimary: Color(0xFF1C1C1E),
    textSecondary: Color(0xFF6E6E73),
    accent: Color(0xFF007AFF),
    border: Color(0x1A000000),
    isLight: true,
  );

  // 紫色主题
  static const purple = ThemeColors(
    background: Color(0xFF1A0A2E),
    surface: Color(0xFF2D1B4E),
    card: Color(0xFF3E2C5F),
    primary: Color(0xFFB794F6),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFB8A5D6),
    accent: Color(0xFF9F7AEA),
    border: Color(0x1AB794F6),
  );

  // 蓝色主题
  static const blue = ThemeColors(
    background: Color(0xFF0A1929),
    surface: Color(0xFF1E3A5F),
    card: Color(0xFF2D4A6F),
    primary: Color(0xFF60A5FA),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFA5C9E8),
    accent: Color(0xFF3B82F6),
    border: Color(0x1A60A5FA),
  );

  // 粉色主题
  static const pink = ThemeColors(
    background: Color(0xFF2D1B28),
    surface: Color(0xFF4A2D42),
    card: Color(0xFF5E3A54),
    primary: Color(0xFFF9A8D4),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFE9C5DB),
    accent: Color(0xFFEC4899),
    border: Color(0x1AF9A8D4),
  );

  // 橙色主题
  static const orange = ThemeColors(
    background: Color(0xFF2D1F0A),
    surface: Color(0xFF4A3520),
    card: Color(0xFF5E4530),
    primary: Color(0xFFFBBF24),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFE9D5A8),
    accent: Color(0xFFF59E0B),
    border: Color(0x1AFBBF24),
  );

  // 绿色主题
  static const green = ThemeColors(
    background: Color(0xFF0A2D1F),
    surface: Color(0xFF1E4A35),
    card: Color(0xFF2D5E45),
    primary: Color(0xFF6EE7B7),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFA8E9C5),
    accent: Color(0xFF10B981),
    border: Color(0x1A6EE7B7),
  );

  // 彩虹主题
  static const rainbow = ThemeColors(
    background: Color(0xFF1A1A2E),
    surface: Color(0xFF2D2D4A),
    card: Color(0xFF3E3E5E),
    primary: Color(0xFFFFFFFF),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFB8B8D6),
    accent: Color(0xFFFF6B9D),
    border: Color(0x1AFFFFFF),
    backgroundGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF667EEA),
        Color(0xFF764BA2),
        Color(0xFFF093FB),
        Color(0xFF4FACFE),
      ],
    ),
  );
}
