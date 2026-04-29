import 'package:flutter_test/flutter_test.dart';
import 'package:hai_music/providers/favorite_provider.dart';
import 'package:hai_music/service_locator.dart';
import 'package:hai_music/services/favorite/favorite_manager_service.dart';
import 'package:hai_music/services/core/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = PreferencesService();
    await prefs.init();
    locator.preferencesService = prefs;
    locator.favoriteManagerService = FavoriteManagerService();
  });

  group('FavoriteProvider', () {
    test('should return false for unknown song', () {
      final provider = FavoriteProvider();
      expect(provider.isFavorite('unknown-song'), isFalse);
    });

    test('should notify listeners on refresh', () async {
      final provider = FavoriteProvider();
      bool notified = false;
      provider.addListener(() => notified = true);

      await provider.refreshFavorites();

      expect(notified, isTrue);
    });

    test('isFavoriteOperationInProgress should return false initially', () {
      final provider = FavoriteProvider();
      expect(provider.isFavoriteOperationInProgress('song-1'), isFalse);
    });

    test('favoriteManager should be accessible', () {
      final provider = FavoriteProvider();
      expect(provider.favoriteManager, isNotNull);
    });
  });
}
