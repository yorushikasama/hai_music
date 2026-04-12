import 'package:flutter_test/flutter_test.dart';
import 'package:hai_music/services/smart_cache_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('SmartCacheService', () {
    test('should create singleton instance', () {
      final instance1 = SmartCacheService();
      final instance2 = SmartCacheService();
      expect(identical(instance1, instance2), isTrue);
    });

    test('should have correct cache configuration constants', () {
      expect(SmartCacheService.maxPlayCacheCount, 50);
      expect(SmartCacheService.maxPlayCacheSize, 500 * 1024 * 1024);
      expect(SmartCacheService.cacheExpiryDays, 7);
      expect(SmartCacheService.playCacheKey, 'play_cache_list');
    });
  });
}
