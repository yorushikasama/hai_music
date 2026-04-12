import 'package:flutter_test/flutter_test.dart';
import 'package:hai_music/utils/format_utils.dart';

void main() {
  group('FormatUtils', () {
    group('formatSize', () {
      test('should format bytes', () {
        expect(FormatUtils.formatSize(0), '0 B');
        expect(FormatUtils.formatSize(512), '512 B');
        expect(FormatUtils.formatSize(1023), '1023 B');
      });

      test('should format kilobytes', () {
        expect(FormatUtils.formatSize(1024), '1.00 KB');
        expect(FormatUtils.formatSize(1536), '1.50 KB');
        expect(FormatUtils.formatSize(1024 * 1024 - 1), closeToKB(1023.99));
      });

      test('should format megabytes', () {
        expect(FormatUtils.formatSize(1024 * 1024), '1.00 MB');
        expect(FormatUtils.formatSize(1024 * 1024 * 512), '512.00 MB');
      });

      test('should format gigabytes', () {
        expect(FormatUtils.formatSize(1024 * 1024 * 1024), '1.00 GB');
        expect(FormatUtils.formatSize(1024 * 1024 * 1024 * 2), '2.00 GB');
      });
    });

    group('parseIntSafe', () {
      test('should parse int', () {
        expect(FormatUtils.parseIntSafe(42), 42);
      });

      test('should parse double to int', () {
        expect(FormatUtils.parseIntSafe(3.7), 3);
        expect(FormatUtils.parseIntSafe(3.14), 3);
      });

      test('should parse string to int', () {
        expect(FormatUtils.parseIntSafe('123'), 123);
      });

      test('should return null for null', () {
        expect(FormatUtils.parseIntSafe(null), isNull);
      });

      test('should return null for unparseable string', () {
        expect(FormatUtils.parseIntSafe('abc'), isNull);
      });
    });
  });
}

Matcher closeToKB(double expected) {
  return predicate<String>((s) {
    final value = double.tryParse(s.replaceAll(' KB', ''));
    return value != null && (value - expected).abs() < 0.01;
  }, 'close to $expected KB');
}
