import 'package:flutter_test/flutter_test.dart';
import 'package:hai_music/models/play_mode.dart';
import 'package:hai_music/models/song.dart';
import 'package:hai_music/services/playlist_manager_service.dart';

void main() {
  group('PlaylistManagerService', () {
    late PlaylistManagerService playlistManager;

    final testSongs = List.generate(
      10,
      (i) => Song(id: 'song-$i', title: 'Song $i', artist: 'Artist $i'),
    );

    setUp(() {
      playlistManager = PlaylistManagerService();
      playlistManager.setPlaylist(testSongs);
    });

    group('setPlaylist', () {
      test('should set playlist and reset index', () {
        expect(playlistManager.playlist.length, 10);
        expect(playlistManager.currentIndex, 0);
      });

      test('should set start index', () {
        playlistManager.setPlaylist(testSongs, startIndex: 5);
        expect(playlistManager.currentIndex, 5);
      });
    });

    group('addSong', () {
      test('should add song to end of playlist', () {
        final newSong = Song(id: 'new', title: 'New Song', artist: 'New Artist');
        playlistManager.addSong(newSong);
        expect(playlistManager.playlist.length, 11);
        expect(playlistManager.playlist.last.id, 'new');
      });

      test('should add duplicate song to end', () {
        playlistManager.addSong(testSongs[0]);
        expect(playlistManager.playlist.length, 11);
      });
    });

    group('removeSongAt', () {
      test('should remove song at index', () {
        playlistManager.removeSongAt(0);
        expect(playlistManager.playlist.length, 9);
        expect(playlistManager.playlist[0].id, 'song-1');
      });
    });

    group('navigation', () {
      test('moveToNext should advance in sequence mode', () {
        playlistManager.setPlayMode(PlayMode.sequence);
        final result = playlistManager.moveToNext();
        expect(result, isTrue);
        expect(playlistManager.currentIndex, 1);
      });

      test('moveToPrevious should go back', () {
        playlistManager.jumpToIndex(5);
        final result = playlistManager.moveToPrevious();
        expect(result, isTrue);
        expect(playlistManager.currentIndex, 4);
      });

      test('jumpToIndex should set current index', () {
        final result = playlistManager.jumpToIndex(3);
        expect(result, isTrue);
        expect(playlistManager.currentIndex, 3);
      });

      test('jumpToIndex should return false for invalid index', () {
        final result = playlistManager.jumpToIndex(100);
        expect(result, isFalse);
      });

      test('jumpToSong should find and jump to song', () {
        final result = playlistManager.jumpToSong(testSongs[7]);
        expect(result, isTrue);
        expect(playlistManager.currentIndex, 7);
      });
    });

    group('playMode', () {
      test('should default to sequence mode', () {
        expect(playlistManager.playMode, PlayMode.sequence);
      });

      test('should change play mode', () {
        playlistManager.setPlayMode(PlayMode.shuffle);
        expect(playlistManager.playMode, PlayMode.shuffle);

        playlistManager.setPlayMode(PlayMode.single);
        expect(playlistManager.playMode, PlayMode.single);
      });

      test('togglePlayMode should cycle through modes', () {
        expect(playlistManager.playMode, PlayMode.sequence);
        playlistManager.togglePlayMode();
        expect(playlistManager.playMode, PlayMode.single);
        playlistManager.togglePlayMode();
        expect(playlistManager.playMode, PlayMode.shuffle);
        playlistManager.togglePlayMode();
        expect(playlistManager.playMode, PlayMode.sequence);
      });
    });

    group('clearPlaylist', () {
      test('should clear playlist', () {
        playlistManager.clearPlaylist();
        expect(playlistManager.playlist.isEmpty, isTrue);
        expect(playlistManager.currentIndex, 0);
      });
    });

    group('isEmpty', () {
      test('should return true when empty', () {
        playlistManager.clearPlaylist();
        expect(playlistManager.isEmpty, isTrue);
      });

      test('should return false when not empty', () {
        expect(playlistManager.isEmpty, isFalse);
      });
    });

    group('hasPrevious/hasNext', () {
      test('hasPrevious should be false at start', () {
        expect(playlistManager.hasPrevious, isFalse);
      });

      test('hasPrevious should be true after advancing', () {
        playlistManager.moveToNext();
        expect(playlistManager.hasPrevious, isTrue);
      });

      test('hasNext should be true before end', () {
        expect(playlistManager.hasNext, isTrue);
      });

      test('hasNext should be false at end in sequence mode', () {
        playlistManager.jumpToIndex(9);
        expect(playlistManager.hasNext, isFalse);
      });
    });
  });
}
