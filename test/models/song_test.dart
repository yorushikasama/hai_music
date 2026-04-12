import 'package:flutter_test/flutter_test.dart';
import 'package:hai_music/models/song.dart';

void main() {
  group('Song', () {
    group('fromApiJson', () {
      test('should parse complete JSON with name/artist fields', () {
        final json = {
          'id': '123',
          'name': '测试歌曲',
          'artist': '测试歌手',
          'album': '测试专辑',
          'pic': 'https://example.com/cover.jpg',
          'url': 'https://example.com/audio.mp3',
          'time': 210,
        };

        final song = Song.fromApiJson(json, 'qq');

        expect(song.id, '123');
        expect(song.title, '测试歌曲');
        expect(song.artist, '测试歌手');
        expect(song.album, '测试专辑');
        expect(song.coverUrl, 'https://example.com/cover.jpg');
        expect(song.audioUrl, 'https://example.com/audio.mp3');
        expect(song.duration, 210);
        expect(song.platform, 'qq');
      });

      test('should parse JSON with title fallback for name field', () {
        final json = {
          'id': '456',
          'title': '备用标题',
          'artist': '备用歌手',
          'album': '备用专辑',
          'cover': 'https://example.com/cover2.jpg',
          'url': 'https://example.com/audio2.mp3',
          'time': '180',
        };

        final song = Song.fromApiJson(json, 'qq');

        expect(song.id, '456');
        expect(song.title, '备用标题');
        expect(song.artist, '备用歌手');
        expect(song.duration, 180);
      });

      test('should handle missing fields with defaults', () {
        final json = <String, dynamic>{};

        final song = Song.fromApiJson(json, 'qq');

        expect(song.id, '');
        expect(song.title, '');
        expect(song.artist, '');
        expect(song.album, '');
        expect(song.coverUrl, '');
        expect(song.audioUrl, '');
        expect(song.duration, 0);
      });

      test('should handle numeric id', () {
        final json = {
          'id': 12345,
          'name': 'test',
          'artist': 'artist',
          'album': 'album',
        };

        final song = Song.fromApiJson(json, 'qq');

        expect(song.id, '12345');
      });

      test('should handle null id', () {
        final json = {
          'id': null,
          'name': 'test',
          'artist': 'artist',
          'album': 'album',
        };

        final song = Song.fromApiJson(json, 'qq');

        expect(song.id, '');
      });

      test('should parse artist and take first one', () {
        final json = {
          'id': '1',
          'name': 'test',
          'artist': '歌手A,歌手B,歌手C',
          'album': 'album',
        };

        final song = Song.fromApiJson(json, 'qq');

        expect(song.artist, '歌手A');
      });
    });

    group('toJson/fromJson', () {
      test('should round-trip correctly', () {
        final original = Song(
          id: 'test-id',
          title: '测试',
          artist: '歌手',
          album: '专辑',
          coverUrl: 'https://example.com/cover.jpg',
          audioUrl: 'https://example.com/audio.mp3',
          duration: 180,
          platform: 'qq',
        );

        final json = original.toJson();
        final restored = Song.fromJson(json);

        expect(restored.id, original.id);
        expect(restored.title, original.title);
        expect(restored.artist, original.artist);
        expect(restored.album, original.album);
        expect(restored.coverUrl, original.coverUrl);
        expect(restored.audioUrl, original.audioUrl);
        expect(restored.duration, original.duration);
        expect(restored.platform, original.platform);
      });

      test('should preserve optional fields in round-trip', () {
        final original = Song(
          id: 'test-id',
          title: '测试',
          artist: '歌手',
          r2CoverUrl: 'https://r2.example.com/cover.jpg',
          lyricsLrc: '[00:00.00]歌词',
          lyricsTrans: '[00:00.00]翻译',
        );

        final json = original.toJson();
        final restored = Song.fromJson(json);

        expect(restored.r2CoverUrl, original.r2CoverUrl);
        expect(restored.lyricsLrc, original.lyricsLrc);
        expect(restored.lyricsTrans, original.lyricsTrans);
      });
    });

    group('construction', () {
      test('should have correct default values', () {
        final song = Song(id: '1', title: 'test', artist: 'artist');

        expect(song.album, '');
        expect(song.coverUrl, '');
        expect(song.audioUrl, '');
        expect(song.duration, isNull);
        expect(song.platform, isNull);
        expect(song.r2CoverUrl, isNull);
        expect(song.lyricsLrc, isNull);
        expect(song.lyricsTrans, isNull);
      });
    });
  });
}
