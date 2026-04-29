import 'package:flutter_test/flutter_test.dart';
import 'package:hai_music/utils/song_metadata_utils.dart';

void main() {
  group('SongMetadataUtils', () {
    late SongMetadataUtils utils;

    setUp(() {
      utils = SongMetadataUtils();
    });

    group('isLowQualityTitle', () {
      test('should return true for empty string', () {
        expect(utils.isLowQualityTitle(''), isTrue);
      });

      test('should return true for track patterns', () {
        expect(utils.isLowQualityTitle('Track 1'), isTrue);
        expect(utils.isLowQualityTitle('track 5'), isTrue);
        expect(utils.isLowQualityTitle('曲目3'), isTrue);
        expect(utils.isLowQualityTitle('音轨12'), isTrue);
      });

      test('should return true for unknown patterns', () {
        expect(utils.isLowQualityTitle('Unknown'), isTrue);
        expect(utils.isLowQualityTitle('unknown'), isTrue);
        expect(utils.isLowQualityTitle('未知'), isTrue);
        expect(utils.isLowQualityTitle('无标题'), isTrue);
        expect(utils.isLowQualityTitle('untitled'), isTrue);
        expect(utils.isLowQualityTitle('<unknown>'), isTrue);
      });

      test('should return true for pure numbers', () {
        expect(utils.isLowQualityTitle('123'), isTrue);
        expect(utils.isLowQualityTitle('1'), isTrue);
      });

      test('should return false for normal titles', () {
        expect(utils.isLowQualityTitle('Hello World'), isFalse);
        expect(utils.isLowQualityTitle('晴天'), isFalse);
        expect(utils.isLowQualityTitle('Song Title 2'), isFalse);
      });

      test('should handle whitespace', () {
        expect(utils.isLowQualityTitle('  Unknown  '), isTrue);
        expect(utils.isLowQualityTitle('  Hello  '), isFalse);
      });
    });

    group('isLowQualityArtist', () {
      test('should return true for empty string', () {
        expect(utils.isLowQualityArtist(''), isTrue);
      });

      test('should return true for unknown patterns', () {
        expect(utils.isLowQualityArtist('Unknown'), isTrue);
        expect(utils.isLowQualityArtist('未知'), isTrue);
        expect(utils.isLowQualityArtist('未知艺术家'), isTrue);
        expect(utils.isLowQualityArtist('未知歌手'), isTrue);
        expect(utils.isLowQualityArtist('Various Artists'), isTrue);
        expect(utils.isLowQualityArtist('various artist'), isTrue);
      });

      test('should return false for normal artists', () {
        expect(utils.isLowQualityArtist('周杰伦'), isFalse);
        expect(utils.isLowQualityArtist('Taylor Swift'), isFalse);
      });
    });

    group('cleanFileName', () {
      test('should remove platform suffixes', () {
        expect(utils.cleanFileName('song [mqms2]'), 'song');
        expect(utils.cleanFileName('song [netease]'), 'song');
        expect(utils.cleanFileName('song [kugou]'), 'song');
        expect(utils.cleanFileName('song [kuwo]'), 'song');
      });

      test('should handle file paths', () {
        expect(utils.cleanFileName('/path/to/song.mp3'), 'song');
      });

      test('should not modify clean names', () {
        expect(utils.cleanFileName('My Song'), 'My Song');
      });
    });

    group('parseFromFilePath', () {
      test('should parse "artist - title" format', () {
        final result = utils.parseFromFilePath('/path/Artist - Title.mp3');
        expect(result, isNotNull);
        expect(result!.artist, 'Artist');
        expect(result.title, 'Title');
      });

      test('should parse "artist - title - subtitle" format', () {
        final result =
            utils.parseFromFilePath('/path/A - B - C.mp3');
        expect(result, isNotNull);
        expect(result!.artist, 'A');
        expect(result.title, 'B - C');
      });

      test('should return null for simple names without separator', () {
        final result = utils.parseFromFilePath('/path/SongTitle.mp3');
        expect(result, isNull);
      });

      test('should return null for empty input', () {
        final result = utils.parseFromFilePath('');
        expect(result, isNull);
      });
    });

    group('isSupportedAudioFormat', () {
      test('should recognize supported formats', () {
        expect(utils.isSupportedAudioFormat('mp3'), isTrue);
        expect(utils.isSupportedAudioFormat('flac'), isTrue);
        expect(utils.isSupportedAudioFormat('.mp3'), isTrue);
        expect(utils.isSupportedAudioFormat('.flac'), isTrue);
      });

      test('should reject unsupported formats', () {
        expect(utils.isSupportedAudioFormat('txt'), isFalse);
        expect(utils.isSupportedAudioFormat('pdf'), isFalse);
      });

      test('should be case insensitive', () {
        expect(utils.isSupportedAudioFormat('MP3'), isTrue);
        expect(utils.isSupportedAudioFormat('FLAC'), isTrue);
      });
    });

    group('isLrcFormat', () {
      test('should detect LRC format', () {
        expect(utils.isLrcFormat('[00:01.00]Hello'), isTrue);
        expect(utils.isLrcFormat('[01:23.45]World'), isTrue);
      });

      test('should reject non-LRC text', () {
        expect(utils.isLrcFormat('Hello World'), isFalse);
        expect(utils.isLrcFormat(''), isFalse);
      });
    });

    group('safeCacheName', () {
      test('should generate deterministic cache name', () {
        final name1 = utils.safeCacheName('/path/song.mp3', 'cover', '.jpg');
        final name2 = utils.safeCacheName('/path/song.mp3', 'cover', '.jpg');
        expect(name1, equals(name2));
      });

      test('should include prefix and extension', () {
        final name = utils.safeCacheName('/path/song.mp3', 'cover', '.jpg');
        expect(name, startsWith('cover_'));
        expect(name, endsWith('.jpg'));
      });

      test('should generate different names for different paths', () {
        final name1 = utils.safeCacheName('/path/song1.mp3', 'cover', '.jpg');
        final name2 = utils.safeCacheName('/path/song2.mp3', 'cover', '.jpg');
        expect(name1, isNot(equals(name2)));
      });
    });
  });
}
