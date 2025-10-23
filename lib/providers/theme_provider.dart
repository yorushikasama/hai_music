import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_styles.dart';

enum AppThemeMode {
  dark,
  light,
  purple,
  blue,
  pink,
  orange,
  green,
  rainbow,
}

class ThemeProvider extends ChangeNotifier {
  AppThemeMode _currentTheme = AppThemeMode.dark;
  static const String _themeKey = 'app_theme';

  AppThemeMode get currentTheme => _currentTheme;
  ThemeColors get colors => _getColors();
  String get themeName => _getThemeName();

  /// 初始化时加载保存的主题
  Future<void> loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeIndex = prefs.getInt(_themeKey);
      if (themeIndex != null && themeIndex < AppThemeMode.values.length) {
        _currentTheme = AppThemeMode.values[themeIndex];
        notifyListeners();
      }
    } catch (e) {
      // 使用默认主题
    }
  }

  /// 设置主题并保存
  Future<void> setTheme(AppThemeMode theme) async {
    _currentTheme = theme;
    notifyListeners();
    
    // 保存到本地
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_themeKey, theme.index);
    } catch (e) {
      // 忽略保存错误
    }
  }

  void nextTheme() {
    final themes = AppThemeMode.values;
    final currentIndex = themes.indexOf(_currentTheme);
    final nextIndex = (currentIndex + 1) % themes.length;
    setTheme(themes[nextIndex]);
  }

  ThemeColors _getColors() {
    switch (_currentTheme) {
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

  String _getThemeName() {
    switch (_currentTheme) {
      case AppThemeMode.dark:
        return '深色';
      case AppThemeMode.light:
        return '浅色';
      case AppThemeMode.purple:
        return '紫色';
      case AppThemeMode.blue:
        return '蓝色';
      case AppThemeMode.pink:
        return '粉色';
      case AppThemeMode.orange:
        return '橙色';
      case AppThemeMode.green:
        return '绿色';
      case AppThemeMode.rainbow:
        return '彩虹';
    }
  }

  String getThemeIcon(AppThemeMode theme) {
    switch (theme) {
      case AppThemeMode.dark:
        return '🌙';
      case AppThemeMode.light:
        return '☀️';
      case AppThemeMode.purple:
        return '💜';
      case AppThemeMode.blue:
        return '💙';
      case AppThemeMode.pink:
        return '🌸';
      case AppThemeMode.orange:
        return '🍊';
      case AppThemeMode.green:
        return '🌿';
      case AppThemeMode.rainbow:
        return '🌈';
    }
  }

  // 生成完整的 ThemeData
  ThemeData get themeData {
    final c = colors;
    final isLight = c.isLight;

    return ThemeData(
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
        backgroundColor: c.surface.withOpacity(0.75),
        indicatorColor: c.accent.withOpacity(0.12),
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
        color: c.card.withOpacity(0.6),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppStyles.radiusLarge),
          side: BorderSide(color: c.border),
        ),
        shadowColor: Colors.black.withOpacity(isLight ? 0.05 : 0.15),
      ),

      // IconButton 主题
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          iconColor: WidgetStateProperty.all(c.textPrimary),
        ),
      ),
    );
  }
}
