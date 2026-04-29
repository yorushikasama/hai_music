import 'package:flutter_test/flutter_test.dart';
import 'package:hai_music/models/favorite_song.dart';

void main() {
  group('FavoriteSong', () {
    group('construction', () {
      test('should use current time as default createdAt', () {
        final before = DateTime.now();
        final song = FavoriteSong(
          id: '1',
          title: '测试',
          artist: '歌手',
          album: '专辑',
          coverUrl: 'https://example.com/cover.jpg',
        );
        final after = DateTime.now();

        expect(song.createdAt.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
        expect(song.createdAt.isBefore(after.add(const Duration(seconds: 1))), isTrue);
        expect(song.syncedAt, isNull);
      });
    });

    group('fromJson', () {
      test('should parse JSON with snake_case keys (Supabase format)', () {
        final json = {
          'id': 'song-1',
          'title': '测试歌曲',
          'artist': '测试歌手',
          'album': '测试专辑',
          'original_cover_url': 'https://example.com/cover.jpg',
          'local_audio_path': '/path/to/audio.mp3',
          'r2_audio_url': 'https://r2.example.com/audio.mp3',
          'r2_cover_url': 'https://r2.example.com/cover.jpg',
          'duration': 210,
          'platform': 'qq',
          'lyrics_lrc': '[00:00.00]歌词',
          'created_at': '2024-06-15T12:00:00.000',
          'synced_at': '2024-06-15T13:00:00.000',
        };

        final song = FavoriteSong.fromJson(json);

        expect(song.id, 'song-1');
        expect(song.coverUrl, 'https://example.com/cover.jpg');
        expect(song.localAudioPath, '/path/to/audio.mp3');
        expect(song.r2AudioUrl, 'https://r2.example.com/audio.mp3');
        expect(song.lyricsLrc, '[00:00.00]歌词');
        expect(song.syncedAt, isNotNull);
      });

      test('should parse JSON with cover_url fallback', () {
        final json = {
          'id': 'song-2',
          'title': 'test',
          'artist': 'artist',
          'album': 'album',
          'cover_url': 'https://example.com/cover2.jpg',
          'created_at': '2024-06-15T12:00:00.000',
        };

        final song = FavoriteSong.fromJson(json);
        expect(song.coverUrl, 'https://example.com/cover2.jpg');
      });

      test('should parse JSON with coverUrl fallback', () {
        final json = {
          'id': 'song-3',
          'title': 'test',
          'artist': 'artist',
          'album': 'album',
          'coverUrl': 'https://example.com/cover3.jpg',
          'created_at': '2024-06-15T12:00:00.000',
        };

        final song = FavoriteSong.fromJson(json);
        expect(song.coverUrl, 'https://example.com/cover3.jpg');
      });
    });

    group('toJson', () {
      test('should output snake_case keys', () {
        final song = FavoriteSong(
          id: '1',
          title: '测试',
          artist: '歌手',
          album: '专辑',
          coverUrl: 'https://example.com/cover.jpg',
          localAudioPath: '/path/to/audio.mp3',
        );

        final json = song.toJson();

        expect(json.containsKey('original_cover_url'), isTrue);
        expect(json.containsKey('local_audio_path'), isTrue);
        expect(json.containsKey('created_at'), isTrue);
        expect(json.containsKey('coverUrl'), isFalse);
      });
    });

    group('copyWith', () {
      test('should preserve unchanged fields', () {
        final original = FavoriteSong(
          id: '1',
          title: '测试',
          artist: '歌手',
          album: '专辑',
          coverUrl: 'https://example.com/cover.jpg',
        );

        final copied = original.copyWith(title: '新标题');

        expect(copied.id, '1');
        expect(copied.title, '新标题');
        expect(copied.artist, '歌手');
      });

      test('should set optional field to null', () {
        final original = FavoriteSong(
          id: '1',
          title: '测试',
          artist: '歌手',
          album: '专辑',
          coverUrl: 'https://example.com/cover.jpg',
          localAudioPath: '/path/to/audio.mp3',
        );

        final copied = original.copyWith(localAudioPath: null);
        expect(copied.localAudioPath, isNull);
      });
    });
  });
}
