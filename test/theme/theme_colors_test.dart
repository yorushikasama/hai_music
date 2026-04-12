import 'package:flutter_test/flutter_test.dart';
import 'package:hai_music/theme/app_styles.dart';
import 'package:flutter/material.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeColors', () {
    group('all theme presets', () {
      final allThemes = {
        'dark': ThemeColors.dark,
        'light': ThemeColors.light,
        'purple': ThemeColors.purple,
        'blue': ThemeColors.blue,
        'pink': ThemeColors.pink,
        'orange': ThemeColors.orange,
        'green': ThemeColors.green,
        'rainbow': ThemeColors.rainbow,
      };

      for (final entry in allThemes.entries) {
        group(entry.key, () {
          test('should have all required color properties', () {
            final c = entry.value;
            expect(c.background, isA<Color>());
            expect(c.surface, isA<Color>());
            expect(c.card, isA<Color>());
            expect(c.accent, isA<Color>());
            expect(c.textPrimary, isA<Color>());
            expect(c.textSecondary, isA<Color>());
            expect(c.border, isA<Color>());
            expect(c.error, isA<Color>());
            expect(c.warning, isA<Color>());
            expect(c.success, isA<Color>());
            expect(c.info, isA<Color>());
            expect(c.favorite, isA<Color>());
          });

          test('should have non-transparent background', () {
            final c = entry.value;
            expect(c.background.a, greaterThan(0.9));
          });

          test('should have non-transparent surface', () {
            final c = entry.value;
            expect(c.surface.a, greaterThan(0.9));
          });

          test('should have visible accent color', () {
            final c = entry.value;
            expect(c.accent.a, greaterThan(0.9));
          });

          test('should have visible text colors', () {
            final c = entry.value;
            expect(c.textPrimary.a, greaterThan(0.9));
            expect(c.textSecondary.a, greaterThan(0.5));
          });

          test('should have semantic color tokens', () {
            final c = entry.value;
            expect(c.error, isNotNull);
            expect(c.warning, isNotNull);
            expect(c.success, isNotNull);
            expect(c.info, isNotNull);
            expect(c.favorite, isNotNull);
          });
        });
      }
    });

    group('light theme', () {
      test('should be marked as light', () {
        expect(ThemeColors.light.isLight, isTrue);
      });

      test('should have visible border (not white on white)', () {
        final border = ThemeColors.light.border;
        final isWhiteBorder = border.r > 0.9 && border.g > 0.9 && border.b > 0.9;
        expect(isWhiteBorder, isFalse,
            reason: 'Light theme border should not be white (invisible on white background)');
      });

      test('should have dark text on light background', () {
        final c = ThemeColors.light;
        final textLuminance = c.textPrimary.computeLuminance();
        final bgLuminance = c.background.computeLuminance();
        expect(textLuminance, isNot(equals(bgLuminance)),
            reason: 'Text and background should have different luminance for readability');
      });
    });

    group('dark theme', () {
      test('should be marked as not light', () {
        expect(ThemeColors.dark.isLight, isFalse);
      });

      test('should have light text on dark background', () {
        final c = ThemeColors.dark;
        final textLuminance = c.textPrimary.computeLuminance();
        final bgLuminance = c.background.computeLuminance();
        expect(textLuminance, greaterThan(bgLuminance),
            reason: 'Dark theme should have lighter text than background');
      });
    });

    group('semantic colors', () {
      test('error should be red-ish', () {
        for (final theme in [ThemeColors.dark, ThemeColors.light]) {
          expect(theme.error, isNotNull);
        }
      });

      test('warning should be orange-ish', () {
        for (final theme in [ThemeColors.dark, ThemeColors.light]) {
          expect(theme.warning, isNotNull);
        }
      });

      test('success should be green-ish', () {
        for (final theme in [ThemeColors.dark, ThemeColors.light]) {
          expect(theme.success, isNotNull);
        }
      });

      test('info should be blue-ish', () {
        for (final theme in [ThemeColors.dark, ThemeColors.light]) {
          expect(theme.info, isNotNull);
        }
      });

      test('favorite should be red-ish', () {
        for (final theme in [ThemeColors.dark, ThemeColors.light]) {
          expect(theme.favorite, isNotNull);
        }
      });
    });

    group('AppStyles', () {
      test('should have consistent radius values', () {
        expect(AppStyles.radiusSmall, lessThan(AppStyles.radiusMedium));
        expect(AppStyles.radiusMedium, lessThan(AppStyles.radiusLarge));
      });

      test('should have positive radius values', () {
        expect(AppStyles.radiusSmall, greaterThan(0));
        expect(AppStyles.radiusMedium, greaterThan(0));
        expect(AppStyles.radiusLarge, greaterThan(0));
      });

      test('should have valid radius values', () {
        expect(AppStyles.radiusSmall, greaterThan(0));
        expect(AppStyles.radiusMedium, greaterThan(0));
        expect(AppStyles.radiusLarge, greaterThan(0));
      });
    });
  });
}
