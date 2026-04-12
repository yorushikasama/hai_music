import 'package:flutter/material.dart';

import '../services/preferences_service.dart';
import '../theme/app_styles.dart';
import '../utils/logger.dart';

enum AppThemeMode {
  dark(displayName: '深色', icon: '🌙'),
  light(displayName: '浅色', icon: '☀️'),
  purple(displayName: '紫色', icon: '💜'),
  blue(displayName: '蓝色', icon: '💙'),
  pink(displayName: '粉色', icon: '🌸'),
  orange(displayName: '橙色', icon: '🍊'),
  green(displayName: '绿色', icon: '🌿'),
  rainbow(displayName: '彩虹', icon: '🌈');

  final String displayName;
  final String icon;

  const AppThemeMode({required this.displayName, required this.icon});

  ThemeColors get colors {
    switch (this) {
      case AppThemeMode.dark:
        return ThemeColors.dark;
      case AppThemeMode.light:
        return ThemeColors.light;
      case AppThemeMode.purple:
        return ThemeColors.purple;
      case AppThemeMode.blue:
        return ThemeColors.blue;
      case AppThemeMode.pink:
        return ThemeColors.pink;
      case AppThemeMode.orange:
        return ThemeColors.orange;
      case AppThemeMode.green:
        return ThemeColors.green;
      case AppThemeMode.rainbow:
        return ThemeColors.rainbow;
    }
  }
}

class ThemeProvider extends ChangeNotifier {
  AppThemeMode _currentTheme = AppThemeMode.dark;
  ThemeData? _cachedThemeData;
  static const String _themeKey = 'app_theme';

  AppThemeMode get currentTheme => _currentTheme;
  ThemeColors get colors => _currentTheme.colors;
  String get themeName => _currentTheme.displayName;

  /// 初始化时加载保存的主题
  Future<void> loadTheme() async {
    try {
      final prefs = PreferencesService();
      final themeName = await prefs.getString(_themeKey);
      if (themeName != null) {
        final theme = AppThemeMode.values.where((t) => t.name == themeName).firstOrNull;
        if (theme != null) {
          _currentTheme = theme;
          _cachedThemeData = null;
          notifyListeners();
        }
      } else {
        final themeIndex = await prefs.getInt(_themeKey);
        if (themeIndex != null && themeIndex < AppThemeMode.values.length) {
          _currentTheme = AppThemeMode.values[themeIndex];
          _cachedThemeData = null;
          notifyListeners();
        }
      }
    } catch (e) {
      Logger.warning('加载主题设置失败，使用默认主题', 'ThemeProvider');
    }
  }

  /// 设置主题并保存
  Future<void> setTheme(AppThemeMode theme) async {
    _currentTheme = theme;
    _cachedThemeData = null;
    notifyListeners();

    try {
      final prefs = PreferencesService();
      await prefs.setString(_themeKey, theme.name);
    } catch (e) {
      Logger.warning('保存主题设置失败', 'ThemeProvider');
    }
  }

  void nextTheme() {
    const themes = AppThemeMode.values;
    final currentIndex = themes.indexOf(_currentTheme);
    final nextIndex = (currentIndex + 1) % themes.length;
    setTheme(themes[nextIndex]);
  }

  String getThemeIcon(AppThemeMode theme) => theme.icon;

  ThemeData get themeData {
    if (_cachedThemeData != null) return _cachedThemeData!;

    final c = colors;
    final isLight = c.isLight;

    final result = ThemeData(
      useMaterial3: true,
      brightness: isLight ? Brightness.light : Brightness.dark,
      scaffoldBackgroundColor: Colors.transparent,
      
      // 颜色方案
      colorScheme: ColorScheme(
        brightness: isLight ? Brightness.light : Brightness.dark,
        primary: c.accent,
        onPrimary: Colors.white,
        secondary: c.accent,
        onSecondary: Colors.white,
        error: Colors.red,
        onError: Colors.white,
        surface: c.surface,
        onSurface: c.textPrimary,
      ),

      // 文字主题
      textTheme: TextTheme(
        headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: c.textPrimary, letterSpacing: -1),
        headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: c.textPrimary, letterSpacing: -0.5),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.textPrimary),
        bodyMedium: TextStyle(fontSize: 15, color: c.textSecondary, fontWeight: FontWeight.w300),
        bodySmall: TextStyle(fontSize: 13, color: c.textSecondary, fontWeight: FontWeight.w300),
      ),

      // AppBar 主题
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: c.textPrimary),
        titleTextStyle: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: c.textPrimary),
      ),

      // NavigationBar 主题
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface.withValues(alpha: 0.75),
        indicatorColor: c.accent.withValues(alpha: 0.12),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.all(
          TextStyle(fontSize: 12, color: c.textSecondary),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: c.accent);
          }
          return IconThemeData(color: c.textSecondary);
        }),
      ),

      // Card 主题
      cardTheme: CardThemeData(
        color: c.card.withValues(alpha: 0.6),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppStyles.radiusLarge),
          side: BorderSide(color: c.border),
        ),
        shadowColor: Colors.black.withValues(alpha: isLight ? 0.05 : 0.15),
      ),

      // IconButton 主题
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          iconColor: WidgetStateProperty.all(c.textPrimary),
        ),
      ),
    );

    _cachedThemeData = result;
    return result;
  }

  @override
  void dispose() {
    Logger.info('释放 ThemeProvider 资源', 'ThemeProvider');
    super.dispose();
  }
}
