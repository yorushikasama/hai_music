import 'package:flutter_test/flutter_test.dart';
import 'package:hai_music/utils/song_filter_mixin.dart';

class TestFilter with SongFilterMixin {}

void main() {
  group('SongFilterMixin', () {
    late TestFilter filter;

    setUp(() {
      filter = TestFilter();
    });

    group('matchesQuery', () {
      test('should return true when query is empty', () {
        expect(
          filter.matchesQuery(
            title: 'Hello',
            artist: 'World',
            album: 'Test',
            query: '',
          ),
          isTrue,
        );
      });

      test('should match by title', () {
        expect(
          filter.matchesQuery(
            title: 'Hello World',
            artist: 'Artist',
            album: 'Album',
            query: 'hello',
          ),
          isTrue,
        );
      });

      test('should match by artist', () {
        expect(
          filter.matchesQuery(
            title: 'Title',
            artist: 'Taylor Swift',
            album: 'Album',
            query: 'swift',
          ),
          isTrue,
        );
      });

      test('should match by album', () {
        expect(
          filter.matchesQuery(
            title: 'Title',
            artist: 'Artist',
            album: '1989',
            query: '1989',
          ),
          isTrue,
        );
      });

      test('should be case insensitive', () {
        expect(
          filter.matchesQuery(
            title: 'HELLO',
            artist: 'WORLD',
            album: 'TEST',
            query: 'hello',
          ),
          isTrue,
        );
      });

      test('should return false when no match', () {
        expect(
          filter.matchesQuery(
            title: 'Hello',
            artist: 'World',
            album: 'Test',
            query: 'nonexistent',
          ),
          isFalse,
        );
      });

      test('should support partial matching', () {
        expect(
          filter.matchesQuery(
            title: 'Bohemian Rhapsody',
            artist: 'Queen',
            album: 'A Night at the Opera',
            query: 'rhap',
          ),
          isTrue,
        );
      });

      test('should support CJK characters', () {
        expect(
          filter.matchesQuery(
            title: '晴天',
            artist: '周杰伦',
            album: '叶惠美',
            query: '周杰',
          ),
          isTrue,
        );
      });
    });
  });
}
