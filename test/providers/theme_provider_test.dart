import 'package:flutter_test/flutter_test.dart';
import 'package:hai_music/providers/theme_provider.dart';
import 'package:hai_music/theme/app_styles.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AppThemeMode', () {
    test('should have 8 theme modes', () {
      expect(AppThemeMode.values.length, 8);
    });

    test('should have correct display names', () {
      expect(AppThemeMode.dark.displayName, '深色');
      expect(AppThemeMode.light.displayName, '浅色');
      expect(AppThemeMode.purple.displayName, '紫色');
      expect(AppThemeMode.blue.displayName, '蓝色');
      expect(AppThemeMode.pink.displayName, '粉色');
      expect(AppThemeMode.orange.displayName, '橙色');
      expect(AppThemeMode.green.displayName, '绿色');
      expect(AppThemeMode.rainbow.displayName, '彩虹');
    });

    test('should have icons for all modes', () {
      for (final mode in AppThemeMode.values) {
        expect(mode.icon, isNotEmpty);
      }
    });

    test('should return correct colors for each mode', () {
      expect(AppThemeMode.dark.colors, same(ThemeColors.dark));
      expect(AppThemeMode.light.colors, same(ThemeColors.light));
      expect(AppThemeMode.purple.colors, same(ThemeColors.purple));
      expect(AppThemeMode.blue.colors, same(ThemeColors.blue));
      expect(AppThemeMode.pink.colors, same(ThemeColors.pink));
      expect(AppThemeMode.orange.colors, same(ThemeColors.orange));
      expect(AppThemeMode.green.colors, same(ThemeColors.green));
      expect(AppThemeMode.rainbow.colors, same(ThemeColors.rainbow));
    });
  });

  group('ThemeProvider', () {
    test('should default to dark theme', () {
      final provider = ThemeProvider();
      expect(provider.currentTheme, AppThemeMode.dark);
    });

    test('should return correct colors for current theme', () {
      final provider = ThemeProvider();
      expect(provider.colors, ThemeColors.dark);
    });

    test('should return correct theme name', () {
      final provider = ThemeProvider();
      expect(provider.themeName, '深色');
    });

    test('should generate theme data', () {
      final provider = ThemeProvider();
      final themeData = provider.themeData;

      expect(themeData, isNotNull);
      expect(themeData.useMaterial3, isTrue);
    });

    test('should cache theme data', () {
      final provider = ThemeProvider();
      final first = provider.themeData;
      final second = provider.themeData;

      expect(identical(first, second), isTrue);
    });

    test('should return theme icon', () {
      final provider = ThemeProvider();
      for (final mode in AppThemeMode.values) {
        expect(provider.getThemeIcon(mode), mode.icon);
      }
    });

    test('should notify listeners on setTheme', () async {
      final provider = ThemeProvider();
      bool notified = false;
      provider.addListener(() => notified = true);

      provider.setTheme(AppThemeMode.light);

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(provider.currentTheme, AppThemeMode.light);
      expect(provider.colors, ThemeColors.light);
      expect(provider.themeName, '浅色');
      expect(notified, isTrue);
    });

    test('should update current theme', () async {
      final provider = ThemeProvider();

      provider.setTheme(AppThemeMode.purple);

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(provider.currentTheme, AppThemeMode.purple);
      expect(provider.colors, ThemeColors.purple);
    });

    test('should invalidate cache on theme change', () async {
      final provider = ThemeProvider();
      final first = provider.themeData;

      provider.setTheme(AppThemeMode.light);

      await Future<void>.delayed(const Duration(milliseconds: 100));

      final second = provider.themeData;

      expect(identical(first, second), isFalse);
    });
  });
}
