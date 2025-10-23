import 'song.dart';

class Playlist {
  final String id;
  final String name;
  final String coverUrl;
  final List<Song> songs;
  final String description;

  Playlist({
    required this.id,
    required this.name,
    required this.coverUrl,
    required this.songs,
    this.description = '',
  });

  int get songCount => songs.length;

  static List<Playlist> getMockData() {
    final songs = Song.getMockData();
    return [
      Playlist(
        id: '1',
        name: '我喜欢的音乐',
        coverUrl: 'https://picsum.photos/400/400?random=10',
        songs: songs.take(5).toList(),
        description: '收藏的歌曲',
      ),
      Playlist(
        id: '2',
        name: '华语流行',
        coverUrl: 'https://picsum.photos/400/400?random=11',
        songs: songs.skip(2).take(4).toList(),
        description: '精选华语流行歌曲',
      ),
      Playlist(
        id: '3',
        name: '周杰伦精选',
        coverUrl: 'https://picsum.photos/400/400?random=12',
        songs: songs,
        description: '周杰伦经典歌曲合集',
      ),
      Playlist(
        id: '4',
        name: '夜间模式',
        coverUrl: 'https://picsum.photos/400/400?random=13',
        songs: songs.take(3).toList(),
        description: '适合夜晚聆听',
      ),
    ];
  }
}
