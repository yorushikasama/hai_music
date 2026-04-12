import 'package:flutter_test/flutter_test.dart';
import 'package:hai_music/models/audio_quality.dart';
import 'package:hai_music/models/play_mode.dart';
import 'package:hai_music/models/song.dart';
import 'package:hai_music/providers/theme_provider.dart';
import 'package:hai_music/services/playback_backend.dart';
import 'package:hai_music/services/smart_cache_service.dart';
import 'package:hai_music/services/song_url_service.dart';
import 'package:hai_music/services/play_history_service.dart';
import 'package:hai_music/services/download_service.dart';
import 'package:hai_music/theme/app_styles.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  group('Singleton Pattern Verification', () {
    test('SmartCacheService is singleton', () {
      final a = SmartCacheService();
      final b = SmartCacheService();
      expect(identical(a, b), isTrue);
    });

    test('SongUrlService is singleton', () {
      final a = SongUrlService();
      final b = SongUrlService();
      expect(identical(a, b), isTrue);
    });

    test('PlayHistoryService is singleton', () {
      final a = PlayHistoryService();
      final b = PlayHistoryService();
      expect(identical(a, b), isTrue);
    });

    test('DownloadService is singleton', () {
      final a = DownloadService();
      final b = DownloadService();
      expect(identical(a, b), isTrue);
    });
  });

  group('PlaybackMediaItem Integration', () {
    test('toSong produces Song that round-trips through JSON', () {
      const item = PlaybackMediaItem(
        id: 'integration-test-id',
        title: 'Integration Test Song',
        artist: 'Test Artist',
        album: 'Test Album',
        duration: Duration(seconds: 240),
        coverUrl: 'https://example.com/cover.jpg',
        audioUrl: 'https://example.com/audio.mp3',
        platform: 'netease',
        r2CoverUrl: 'https://r2.example.com/cover.jpg',
        lyricsLrc: '[00:00.00]Test lyrics line',
        lyricsTrans: '[00:00.00]Test translation line',
      );

      final song = item.toSong();
      final json = song.toJson();
      final restored = Song.fromJson(json);

      expect(restored.id, 'integration-test-id');
      expect(restored.title, 'Integration Test Song');
      expect(restored.artist, 'Test Artist');
      expect(restored.album, 'Test Album');
      expect(restored.duration, 240);
      expect(restored.coverUrl, 'https://example.com/cover.jpg');
      expect(restored.audioUrl, 'https://example.com/audio.mp3');
      expect(restored.platform, 'netease');
      expect(restored.r2CoverUrl, 'https://r2.example.com/cover.jpg');
      expect(restored.lyricsLrc, '[00:00.00]Test lyrics line');
      expect(restored.lyricsTrans, '[00:00.00]Test translation line');
    });

    test('PlaybackMediaItem with minimal fields produces valid Song', () {
      const item = PlaybackMediaItem(
        id: 'minimal',
        title: 'Minimal',
        artist: 'Artist',
      );

      final song = item.toSong();
      final json = song.toJson();
      final restored = Song.fromJson(json);

      expect(restored.id, 'minimal');
      expect(restored.title, 'Minimal');
      expect(restored.artist, 'Artist');
      expect(restored.album, '');
      expect(restored.coverUrl, '');
      expect(restored.audioUrl, '');
      expect(restored.duration, isNull);
      expect(restored.platform, isNull);
    });
  });

  group('PlayMode Integration', () {
    test('PlayMode cycle is complete and consistent', () {
      final visitedModes = <PlayMode>{};
      PlayMode current = PlayMode.sequence;

      for (int i = 0; i < PlayMode.values.length; i++) {
        visitedModes.add(current);
        current = current.next;
      }

      expect(visitedModes.length, PlayMode.values.length);
      expect(current, PlayMode.sequence);
    });

    test('PlayMode labels are unique', () {
      final labels = PlayMode.values.map((m) => m.label).toList();
      final uniqueLabels = labels.toSet();
      expect(uniqueLabels.length, labels.length);
    });
  });

  group('AudioQuality Integration', () {
    test('all quality levels have valid file extensions', () {
      for (final quality in AudioQuality.values) {
        expect(quality.fileExtension, isNotEmpty);
        expect(quality.fileExtension, startsWith('.'));
      }
    });

    test('quality categories map correctly', () {
      final standardQualities = AudioQuality.values
          .where((q) => q.category == AudioQualityCategory.standard);
      final highQualities = AudioQuality.values
          .where((q) => q.category == AudioQualityCategory.highQuality);
      final losslessQualities = AudioQuality.values
          .where((q) => q.category == AudioQualityCategory.lossless);

      expect(standardQualities.length, 1);
      expect(highQualities.length, 2);
      expect(losslessQualities.length, 5);
    });

    test('parse handles all enum names', () {
      for (final quality in AudioQuality.values) {
        final parsed = AudioQuality.parse(quality.name);
        expect(parsed, quality);
      }
    });

    test('parse handles all numeric values', () {
      for (final quality in AudioQuality.values) {
        final parsed = AudioQuality.parse(quality.value.toString());
        expect(parsed, quality);
      }
    });
  });

  group('Theme System Integration', () {
    test('all theme modes have corresponding ThemeColors', () {
      for (final mode in AppThemeMode.values) {
        final colors = mode.colors;
        expect(colors, isNotNull);
        expect(colors.background, isNotNull);
        expect(colors.surface, isNotNull);
        expect(colors.accent, isNotNull);
        expect(colors.textPrimary, isNotNull);
        expect(colors.textSecondary, isNotNull);
      }
    });

    test('ThemeProvider cycles through all themes', () {
      final provider = ThemeProvider();
      final visitedThemes = <AppThemeMode>{};

      for (int i = 0; i < AppThemeMode.values.length; i++) {
        visitedThemes.add(provider.currentTheme);
        provider.nextTheme();
      }

      expect(visitedThemes.length, AppThemeMode.values.length);
    });

    test('light and dark themes have contrasting text colors', () {
      final darkTextLum = ThemeColors.dark.textPrimary.computeLuminance();
      final darkBgLum = ThemeColors.dark.background.computeLuminance();
      final lightTextLum = ThemeColors.light.textPrimary.computeLuminance();
      final lightBgLum = ThemeColors.light.background.computeLuminance();

      expect(darkTextLum, greaterThan(darkBgLum));
      expect(lightTextLum, lessThan(lightBgLum));
    });

    test('most themes have distinct accent colors', () {
      final accentColors = <int>{};
      for (final mode in AppThemeMode.values) {
        final value = mode.colors.accent.toARGB32();
        accentColors.add(value);
      }
      expect(accentColors.length, greaterThanOrEqualTo(AppThemeMode.values.length - 1));
    });
  });

  group('SmartCacheService Configuration', () {
    test('cache limits are reasonable', () {
      expect(SmartCacheService.maxPlayCacheCount, greaterThan(0));
      expect(SmartCacheService.maxPlayCacheCount, lessThanOrEqualTo(200));
      expect(SmartCacheService.maxPlayCacheSize, greaterThan(0));
      expect(SmartCacheService.cacheExpiryDays, greaterThan(0));
      expect(SmartCacheService.cacheExpiryDays, lessThanOrEqualTo(30));
    });

    test('cache key is non-empty', () {
      expect(SmartCacheService.playCacheKey, isNotEmpty);
    });
  });

  group('SongUrlService Cache Operations', () {
    test('getCacheStats returns valid structure', () {
      final service = SongUrlService();
      final stats = service.getCacheStats();
      expect(stats, isA<Map<String, dynamic>>());
      expect(stats.containsKey('memoryCacheSize'), isTrue);
      expect(stats.containsKey('pendingRequests'), isTrue);
    });

    test('invalidateSongCache does not throw', () {
      final service = SongUrlService();
      expect(() => service.invalidateSongCache('test-id'), returnsNormally);
    });
  });

  group('Cross-Module Data Flow', () {
    test('Song from PlaybackMediaItem preserves audio quality info', () {
      const item = PlaybackMediaItem(
        id: 'quality-test',
        title: 'Quality Test',
        artist: 'Artist',
        audioUrl: 'https://example.com/audio.flac',
        platform: 'qq',
      );

      final song = item.toSong();
      expect(song.audioUrl, contains('.flac'));
    });

    test('AudioQuality fileExtension matches audio URL patterns', () {
      expect(AudioQuality.lossless.fileExtension, '.flac');
      expect(AudioQuality.high.fileExtension, '.mp3');
      expect(AudioQuality.dolby.fileExtension, '.ec3');
    });
  });
}
