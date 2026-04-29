import 'package:flutter_test/flutter_test.dart';
import 'package:hai_music/models/song.dart';
import 'package:hai_music/services/lyrics/lyrics_loading_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('LyricsResult', () {
    test('hasLyrics should be true when lrc is non-empty', () {
      const result = LyricsResult(lrc: '[00:00.00]歌词');
      expect(result.hasLyrics, isTrue);
      expect(result.hasTranslation, isFalse);
    });

    test('hasLyrics should be false when lrc is null', () {
      const result = LyricsResult();
      expect(result.hasLyrics, isFalse);
    });

    test('hasLyrics should be false when lrc is empty', () {
      const result = LyricsResult(lrc: '');
      expect(result.hasLyrics, isFalse);
    });

    test('hasTranslation should be true when trans is non-empty', () {
      const result = LyricsResult(lrc: 'lyrics', trans: 'translation');
      expect(result.hasTranslation, isTrue);
    });

    test('hasTranslation should be false when trans is null', () {
      const result = LyricsResult(lrc: 'lyrics');
      expect(result.hasTranslation, isFalse);
    });

    test('hasTranslation should be false when trans is empty', () {
      const result = LyricsResult(lrc: 'lyrics', trans: '');
      expect(result.hasTranslation, isFalse);
    });
  });

  group('LyricsLoadingService', () {
    test('should create singleton instance', () {
      final instance1 = LyricsLoadingService();
      final instance2 = LyricsLoadingService();
      expect(identical(instance1, instance2), isTrue);
    });

    test('loadLyrics should return null for song without lyrics', () async {
      final service = LyricsLoadingService();
      final song = Song(
        id: 'nonexistent-song-id',
        title: 'No Lyrics Song',
        artist: 'Unknown',
      );

      final result = await service.loadLyrics(song);
      expect(result, isNull);
    }, skip: 'Requires sqflite database initialization');

    test('loadLyrics should use song lyricsLrc when available', () async {
      final service = LyricsLoadingService();
      final song = Song(
        id: 'test-song-with-lyrics',
        title: 'Test Song',
        artist: 'Artist',
        lyricsLrc: '[00:00.00]Test lyrics content',
      );

      final result = await service.loadLyrics(song);
      expect(result, isNotNull);
      expect(result!.lrc, '[00:00.00]Test lyrics content');
    });
  });
}
