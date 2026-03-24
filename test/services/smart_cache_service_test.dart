import 'package:flutter_test/flutter_test.dart';
import 'package:hai_music/services/smart_cache_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('SmartCacheService', () {
    late SmartCacheService cacheService;

    setUp(() {
      cacheService = SmartCacheService();
    });

    test('should create singleton instance', () {
      final instance1 = SmartCacheService();
      final instance2 = SmartCacheService();
      expect(identical(instance1, instance2), isTrue);
    });

    test('should get cache stats', () async {
      final stats = await cacheService.getCacheStats();
      expect(stats, isNotNull);
      expect(stats['playCache'], isNotNull);
      expect(stats['playCache']['size'], isNotNull);
      expect(stats['playCache']['count'], isNotNull);
      expect(stats['playCache']['maxCount'], 50);
      expect(stats['playCache']['maxSize'], 500 * 1024 * 1024);
    });

    test('should optimize cache', () async {
      // 测试缓存优化功能
      await cacheService.optimizeCache();
      // 验证优化后缓存状态
      final stats = await cacheService.getCacheStats();
      expect(stats, isNotNull);
    });
  });
}
