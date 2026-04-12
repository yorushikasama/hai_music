import 'package:flutter_test/flutter_test.dart';
import 'package:hai_music/models/playlist.dart';
import 'package:hai_music/models/song.dart';

void main() {
  group('Playlist', () {
    group('construction', () {
      test('should create with required fields', () {
        final songs = [
          Song(id: '1', title: 'Song 1', artist: 'Artist 1'),
          Song(id: '2', title: 'Song 2', artist: 'Artist 2'),
        ];

        final playlist = Playlist(
          id: 'pl-001',
          name: '我的歌单',
          coverUrl: 'https://example.com/cover.jpg',
          songs: songs,
        );

        expect(playlist.id, 'pl-001');
        expect(playlist.name, '我的歌单');
        expect(playlist.coverUrl, 'https://example.com/cover.jpg');
        expect(playlist.songs.length, 2);
        expect(playlist.description, '');
      });

      test('should use custom description', () {
        final playlist = Playlist(
          id: 'pl-002',
          name: '简单歌单',
          coverUrl: '',
          songs: [],
          description: '自定义描述',
        );

        expect(playlist.description, '自定义描述');
      });
    });

    group('songCount', () {
      test('should return songs length', () {
        final songs = List.generate(
          5,
          (i) => Song(id: 's-$i', title: 'Song $i', artist: 'Artist $i'),
        );

        final playlist = Playlist(
          id: 'pl-003',
          name: '歌单',
          coverUrl: '',
          songs: songs,
        );

        expect(playlist.songCount, 5);
      });

      test('should return 0 for empty playlist', () {
        final playlist = Playlist(
          id: 'pl-004',
          name: '空歌单',
          coverUrl: '',
          songs: [],
        );

        expect(playlist.songCount, 0);
      });
    });
  });
}
