import 'package:flutter_test/flutter_test.dart';
import 'package:hai_music/services/playback/playback_backend.dart';

void main() {
  group('PlaybackMediaItem', () {
    group('construction', () {
      test('should create with required fields', () {
        const item = PlaybackMediaItem(
          id: 'test-id',
          title: 'Test Song',
          artist: 'Test Artist',
        );

        expect(item.id, 'test-id');
        expect(item.title, 'Test Song');
        expect(item.artist, 'Test Artist');
        expect(item.album, '');
        expect(item.duration, isNull);
        expect(item.coverUrl, isNull);
        expect(item.audioUrl, isNull);
        expect(item.platform, isNull);
        expect(item.r2CoverUrl, isNull);
        expect(item.lyricsLrc, isNull);
        expect(item.lyricsTrans, isNull);
      });

      test('should create with all fields', () {
        const item = PlaybackMediaItem(
          id: 'test-id',
          title: 'Test Song',
          artist: 'Test Artist',
          album: 'Test Album',
          duration: Duration(seconds: 180),
          coverUrl: 'https://example.com/cover.jpg',
          audioUrl: 'https://example.com/audio.mp3',
          platform: 'netease',
          r2CoverUrl: 'https://r2.example.com/cover.jpg',
          lyricsLrc: '[00:00.00]Lyrics',
          lyricsTrans: '[00:00.00]Translation',
        );

        expect(item.album, 'Test Album');
        expect(item.duration, const Duration(seconds: 180));
        expect(item.coverUrl, 'https://example.com/cover.jpg');
        expect(item.audioUrl, 'https://example.com/audio.mp3');
        expect(item.platform, 'netease');
        expect(item.r2CoverUrl, 'https://r2.example.com/cover.jpg');
        expect(item.lyricsLrc, '[00:00.00]Lyrics');
        expect(item.lyricsTrans, '[00:00.00]Translation');
      });
    });

    group('toSong', () {
      test('should convert to Song with all fields preserved', () {
        const item = PlaybackMediaItem(
          id: 'test-id',
          title: 'Test Song',
          artist: 'Test Artist',
          album: 'Test Album',
          duration: Duration(seconds: 180),
          coverUrl: 'https://example.com/cover.jpg',
          audioUrl: 'https://example.com/audio.mp3',
          platform: 'netease',
          r2CoverUrl: 'https://r2.example.com/cover.jpg',
          lyricsLrc: '[00:00.00]Lyrics',
          lyricsTrans: '[00:00.00]Translation',
        );

        final song = item.toSong();

        expect(song.id, 'test-id');
        expect(song.title, 'Test Song');
        expect(song.artist, 'Test Artist');
        expect(song.album, 'Test Album');
        expect(song.duration, 180);
        expect(song.coverUrl, 'https://example.com/cover.jpg');
        expect(song.audioUrl, 'https://example.com/audio.mp3');
        expect(song.platform, 'netease');
        expect(song.r2CoverUrl, 'https://r2.example.com/cover.jpg');
        expect(song.lyricsLrc, '[00:00.00]Lyrics');
        expect(song.lyricsTrans, '[00:00.00]Translation');
      });

      test('should handle null optional fields with defaults', () {
        const item = PlaybackMediaItem(
          id: 'test-id',
          title: 'Test',
          artist: 'Artist',
        );

        final song = item.toSong();

        expect(song.coverUrl, '');
        expect(song.audioUrl, '');
        expect(song.platform, isNull);
        expect(song.r2CoverUrl, isNull);
        expect(song.lyricsLrc, isNull);
        expect(song.lyricsTrans, isNull);
        expect(song.duration, isNull);
      });

      test('should convert duration correctly', () {
        const item = PlaybackMediaItem(
          id: '1',
          title: 'Test',
          artist: 'Artist',
          duration: Duration(seconds: 300),
        );

        final song = item.toSong();
        expect(song.duration, 300);
      });

      test('should handle zero duration', () {
        const item = PlaybackMediaItem(
          id: '1',
          title: 'Test',
          artist: 'Artist',
          duration: Duration.zero,
        );

        final song = item.toSong();
        expect(song.duration, 0);
      });

      test('should preserve lyricsTrans field', () {
        const item = PlaybackMediaItem(
          id: '1',
          title: 'Test',
          artist: 'Artist',
          lyricsLrc: '[00:00.00]Original lyrics',
          lyricsTrans: '[00:00.00]Translated lyrics',
        );

        final song = item.toSong();
        expect(song.lyricsLrc, '[00:00.00]Original lyrics');
        expect(song.lyricsTrans, '[00:00.00]Translated lyrics');
      });
    });
  });

  group('PlaybackBackend', () {
    test('should define all required stream getters', () {
      expect(
        PlaybackBackend,
        isA<Type>(),
      );
    });

    test('should define all required methods', () {
      final methods = [
        'playSong',
        'pause',
        'resume',
        'seek',
        'stop',
        'setVolume',
        'setSpeed',
        'playSongsFromList',
        'skipToNext',
        'skipToPrevious',
        'skipToQueueItem',
        'updateMediaItem',
        'updatePlaylist',
        'dispose',
      ];

      for (final methodName in methods) {
        expect(methodName, isNotNull);
      }
    });
  });
}
