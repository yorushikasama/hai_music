import 'package:flutter_test/flutter_test.dart';
import 'package:hai_music/utils/cache_utils.dart';

void main() {
  group('CacheUtils', () {
    group('isCacheExpired', () {
      test('should return true for zero timestamp', () {
        expect(CacheUtils.isCacheExpired(0), isTrue);
      });

      test('should return false for recent timestamp', () {
        final recentTimestamp = DateTime.now().millisecondsSinceEpoch;
        expect(CacheUtils.isCacheExpired(recentTimestamp), isFalse);
      });

      test('should return true for old timestamp', () {
        final oldTimestamp = DateTime.now()
            .subtract(const Duration(hours: 25))
            .millisecondsSinceEpoch;
        expect(CacheUtils.isCacheExpired(oldTimestamp), isTrue);
      });

      test('should respect custom hours parameter', () {
        final timestamp = DateTime.now()
            .subtract(const Duration(hours: 2))
            .millisecondsSinceEpoch;

        expect(CacheUtils.isCacheExpired(timestamp, hours: 1), isTrue);
        expect(CacheUtils.isCacheExpired(timestamp, hours: 3), isFalse);
      });

      test('should return true after exact boundary', () {
        final timestamp = DateTime.now()
            .subtract(const Duration(hours: 24, milliseconds: 1))
            .millisecondsSinceEpoch;

        expect(CacheUtils.isCacheExpired(timestamp), isTrue);
      });
    });

    group('getCurrentTimestamp', () {
      test('should return non-zero timestamp', () {
        final ts = CacheUtils.getCurrentTimestamp();
        expect(ts, greaterThan(0));
      });

      test('should return current time in milliseconds', () {
        final before = DateTime.now().millisecondsSinceEpoch;
        final ts = CacheUtils.getCurrentTimestamp();
        final after = DateTime.now().millisecondsSinceEpoch;

        expect(ts, greaterThanOrEqualTo(before));
        expect(ts, lessThanOrEqualTo(after));
      });
    });
  });
}
