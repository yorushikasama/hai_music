import 'package:flutter_test/flutter_test.dart';
import 'package:hai_music/models/play_history.dart';

void main() {
  group('PlayHistory', () {
    final testTime = DateTime(2024, 1, 15, 10, 30, 0);

    group('construction', () {
      test('should create with required fields', () {
        final history = PlayHistory(
          id: 'song-1',
          title: '测试歌曲',
          artist: '测试歌手',
          album: '测试专辑',
          coverUrl: 'https://example.com/cover.jpg',
          playedAt: testTime,
        );

        expect(history.id, 'song-1');
        expect(history.title, '测试歌曲');
        expect(history.artist, '测试歌手');
        expect(history.album, '测试专辑');
        expect(history.coverUrl, 'https://example.com/cover.jpg');
        expect(history.duration, isNull);
        expect(history.platform, isNull);
        expect(history.playedAt, testTime);
      });

      test('should default playedAt to now when not provided', () {
        final before = DateTime.now();
        final history = PlayHistory(
          id: '1',
          title: 'test',
          artist: 'artist',
          album: 'album',
          coverUrl: '',
        );
        final after = DateTime.now();

        expect(history.playedAt.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
        expect(history.playedAt.isBefore(after.add(const Duration(seconds: 1))), isTrue);
      });

      test('should support optional fields', () {
        final history = PlayHistory(
          id: '1',
          title: 'test',
          artist: 'artist',
          album: 'album',
          coverUrl: '',
          duration: 210,
          platform: 'qq',
          playedAt: testTime,
        );

        expect(history.duration, 210);
        expect(history.platform, 'qq');
      });
    });

    group('fromJson', () {
      test('should parse complete JSON', () {
        final json = {
          'id': 'song-1',
          'title': '测试歌曲',
          'artist': '测试歌手',
          'album': '测试专辑',
          'coverUrl': 'https://example.com/cover.jpg',
          'duration': 210,
          'platform': 'qq',
          'playedAt': testTime.toIso8601String(),
        };

        final history = PlayHistory.fromJson(json);

        expect(history.id, 'song-1');
        expect(history.title, '测试歌曲');
        expect(history.artist, '测试歌手');
        expect(history.album, '测试专辑');
        expect(history.coverUrl, 'https://example.com/cover.jpg');
        expect(history.duration, 210);
        expect(history.platform, 'qq');
      });

      test('should handle numeric id', () {
        final json = {
          'id': 12345,
          'title': 'test',
          'artist': 'artist',
          'album': 'album',
          'coverUrl': '',
          'playedAt': testTime.toIso8601String(),
        };

        final history = PlayHistory.fromJson(json);
        expect(history.id, '12345');
      });

      test('should handle null fields with defaults', () {
        final json = <String, dynamic>{};

        final history = PlayHistory.fromJson(json);

        expect(history.id, '');
        expect(history.title, '');
        expect(history.artist, '');
        expect(history.album, '');
        expect(history.coverUrl, '');
        expect(history.duration, isNull);
        expect(history.platform, isNull);
      });

      test('should handle invalid playedAt gracefully', () {
        final json = {
          'id': '1',
          'title': 'test',
          'artist': 'artist',
          'album': 'album',
          'coverUrl': '',
          'playedAt': 'invalid-date',
        };

        final history = PlayHistory.fromJson(json);
        expect(history.playedAt, isNotNull);
      });

      test('should handle missing playedAt', () {
        final json = {
          'id': '1',
          'title': 'test',
          'artist': 'artist',
          'album': 'album',
          'coverUrl': '',
        };

        final history = PlayHistory.fromJson(json);
        expect(history.playedAt, isNotNull);
      });
    });

    group('toJson', () {
      test('should serialize all fields', () {
        final history = PlayHistory(
          id: 'song-1',
          title: '测试歌曲',
          artist: '测试歌手',
          album: '测试专辑',
          coverUrl: 'https://example.com/cover.jpg',
          duration: 210,
          platform: 'qq',
          playedAt: testTime,
        );

        final json = history.toJson();

        expect(json['id'], 'song-1');
        expect(json['title'], '测试歌曲');
        expect(json['artist'], '测试歌手');
        expect(json['album'], '测试专辑');
        expect(json['coverUrl'], 'https://example.com/cover.jpg');
        expect(json['duration'], 210);
        expect(json['platform'], 'qq');
        expect(json['playedAt'], testTime.toIso8601String());
      });
    });

    group('round-trip', () {
      test('should preserve all fields through toJson/fromJson', () {
        final original = PlayHistory(
          id: 'song-1',
          title: '测试歌曲',
          artist: '测试歌手',
          album: '测试专辑',
          coverUrl: 'https://example.com/cover.jpg',
          duration: 210,
          platform: 'qq',
          playedAt: testTime,
        );

        final json = original.toJson();
        final restored = PlayHistory.fromJson(json);

        expect(restored.id, original.id);
        expect(restored.title, original.title);
        expect(restored.artist, original.artist);
        expect(restored.album, original.album);
        expect(restored.coverUrl, original.coverUrl);
        expect(restored.duration, original.duration);
        expect(restored.platform, original.platform);
      });
    });
  });
}
