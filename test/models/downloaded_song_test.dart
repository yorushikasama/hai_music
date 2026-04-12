import 'package:flutter_test/flutter_test.dart';
import 'package:hai_music/models/downloaded_song.dart';

void main() {
  group('DownloadedSong', () {
    final testTime = DateTime(2024, 1, 15, 10, 30, 0);

    group('construction', () {
      test('should create with required fields', () {
        final song = DownloadedSong(
          id: 'song-1',
          title: '测试歌曲',
          artist: '测试歌手',
          localAudioPath: '/path/to/audio.mp3',
          downloadedAt: testTime,
        );

        expect(song.id, 'song-1');
        expect(song.title, '测试歌曲');
        expect(song.artist, '测试歌手');
        expect(song.album, '');
        expect(song.coverUrl, '');
        expect(song.localAudioPath, '/path/to/audio.mp3');
        expect(song.localCoverPath, isNull);
        expect(song.localLyricsPath, isNull);
        expect(song.localTransPath, isNull);
        expect(song.duration, isNull);
        expect(song.platform, isNull);
        expect(song.source, SongSource.downloaded);
      });

      test('should support all optional fields', () {
        final song = DownloadedSong(
          id: 'song-1',
          title: '测试歌曲',
          artist: '测试歌手',
          album: '测试专辑',
          coverUrl: 'https://example.com/cover.jpg',
          localAudioPath: '/path/to/audio.mp3',
          localCoverPath: '/path/to/cover.jpg',
          localLyricsPath: '/path/to/lyrics.lrc',
          localTransPath: '/path/to/trans.lrc',
          duration: 210,
          platform: 'qq',
          downloadedAt: testTime,
          source: SongSource.local,
        );

        expect(song.album, '测试专辑');
        expect(song.coverUrl, 'https://example.com/cover.jpg');
        expect(song.localCoverPath, '/path/to/cover.jpg');
        expect(song.localLyricsPath, '/path/to/lyrics.lrc');
        expect(song.localTransPath, '/path/to/trans.lrc');
        expect(song.duration, 210);
        expect(song.platform, 'qq');
        expect(song.source, SongSource.local);
      });
    });

    group('SongSource', () {
      test('should have downloaded and local values', () {
        expect(SongSource.values.length, 2);
        expect(SongSource.values, contains(SongSource.downloaded));
        expect(SongSource.values, contains(SongSource.local));
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
          'localAudioPath': '/path/to/audio.mp3',
          'localCoverPath': '/path/to/cover.jpg',
          'localLyricsPath': '/path/to/lyrics.lrc',
          'localTransPath': '/path/to/trans.lrc',
          'duration': 210,
          'platform': 'qq',
          'downloadedAt': testTime.toIso8601String(),
          'source': 'downloaded',
        };

        final song = DownloadedSong.fromJson(json);

        expect(song.id, 'song-1');
        expect(song.title, '测试歌曲');
        expect(song.artist, '测试歌手');
        expect(song.album, '测试专辑');
        expect(song.localAudioPath, '/path/to/audio.mp3');
        expect(song.localCoverPath, '/path/to/cover.jpg');
        expect(song.localLyricsPath, '/path/to/lyrics.lrc');
        expect(song.localTransPath, '/path/to/trans.lrc');
        expect(song.duration, 210);
        expect(song.platform, 'qq');
        expect(song.source, SongSource.downloaded);
      });

      test('should parse local source', () {
        final json = {
          'id': '1',
          'title': 'test',
          'artist': 'artist',
          'localAudioPath': '/path',
          'downloadedAt': testTime.toIso8601String(),
          'source': 'local',
        };

        final song = DownloadedSong.fromJson(json);
        expect(song.source, SongSource.local);
      });

      test('should default to downloaded source for unknown source', () {
        final json = {
          'id': '1',
          'title': 'test',
          'artist': 'artist',
          'localAudioPath': '/path',
          'downloadedAt': testTime.toIso8601String(),
          'source': 'unknown',
        };

        final song = DownloadedSong.fromJson(json);
        expect(song.source, SongSource.downloaded);
      });

      test('should handle null optional fields', () {
        final json = {
          'id': '1',
          'title': 'test',
          'artist': 'artist',
          'localAudioPath': '/path',
          'downloadedAt': testTime.toIso8601String(),
        };

        final song = DownloadedSong.fromJson(json);

        expect(song.album, '');
        expect(song.coverUrl, '');
        expect(song.localCoverPath, isNull);
        expect(song.localLyricsPath, isNull);
        expect(song.localTransPath, isNull);
        expect(song.duration, isNull);
        expect(song.platform, isNull);
      });
    });

    group('toJson', () {
      test('should serialize all fields', () {
        final song = DownloadedSong(
          id: 'song-1',
          title: '测试歌曲',
          artist: '测试歌手',
          album: '测试专辑',
          coverUrl: 'https://example.com/cover.jpg',
          localAudioPath: '/path/to/audio.mp3',
          localCoverPath: '/path/to/cover.jpg',
          localLyricsPath: '/path/to/lyrics.lrc',
          localTransPath: '/path/to/trans.lrc',
          duration: 210,
          platform: 'qq',
          downloadedAt: testTime,
          source: SongSource.local,
        );

        final json = song.toJson();

        expect(json['id'], 'song-1');
        expect(json['title'], '测试歌曲');
        expect(json['artist'], '测试歌手');
        expect(json['album'], '测试专辑');
        expect(json['localAudioPath'], '/path/to/audio.mp3');
        expect(json['localCoverPath'], '/path/to/cover.jpg');
        expect(json['localLyricsPath'], '/path/to/lyrics.lrc');
        expect(json['localTransPath'], '/path/to/trans.lrc');
        expect(json['duration'], 210);
        expect(json['platform'], 'qq');
        expect(json['source'], 'local');
      });

      test('should serialize downloaded source', () {
        final song = DownloadedSong(
          id: '1',
          title: 'test',
          artist: 'artist',
          localAudioPath: '/path',
          downloadedAt: testTime,
          source: SongSource.downloaded,
        );

        expect(song.toJson()['source'], 'downloaded');
      });
    });

    group('round-trip', () {
      test('should preserve all fields through toJson/fromJson', () {
        final original = DownloadedSong(
          id: 'song-1',
          title: '测试歌曲',
          artist: '测试歌手',
          album: '测试专辑',
          coverUrl: 'https://example.com/cover.jpg',
          localAudioPath: '/path/to/audio.mp3',
          localCoverPath: '/path/to/cover.jpg',
          localLyricsPath: '/path/to/lyrics.lrc',
          localTransPath: '/path/to/trans.lrc',
          duration: 210,
          platform: 'qq',
          downloadedAt: testTime,
          source: SongSource.local,
        );

        final json = original.toJson();
        final restored = DownloadedSong.fromJson(json);

        expect(restored.id, original.id);
        expect(restored.title, original.title);
        expect(restored.artist, original.artist);
        expect(restored.album, original.album);
        expect(restored.coverUrl, original.coverUrl);
        expect(restored.localAudioPath, original.localAudioPath);
        expect(restored.localCoverPath, original.localCoverPath);
        expect(restored.localLyricsPath, original.localLyricsPath);
        expect(restored.localTransPath, original.localTransPath);
        expect(restored.duration, original.duration);
        expect(restored.platform, original.platform);
        expect(restored.source, original.source);
      });
    });
  });
}
