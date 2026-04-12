import 'package:flutter_test/flutter_test.dart';
import 'package:hai_music/services/song_url_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SongUrlService', () {
    test('is a singleton', () {
      final instance1 = SongUrlService();
      final instance2 = SongUrlService();

      expect(identical(instance1, instance2), isTrue,
          reason: 'SongUrlService should be a singleton so in-memory cache is shared');
    });

    test('invalidateSongCache removes from in-memory cache', () {
      final service = SongUrlService();

      service.invalidateSongCache('test-song-id');

      final stats = service.getCacheStats();
      expect(stats['memoryCacheSize'], 0);
    });

    test('getCacheStats returns valid structure', () {
      final service = SongUrlService();

      final stats = service.getCacheStats();
      expect(stats, isA<Map<String, dynamic>>());
      expect(stats.containsKey('memoryCacheSize'), isTrue);
      expect(stats.containsKey('pendingRequests'), isTrue);
    });
  });
}
