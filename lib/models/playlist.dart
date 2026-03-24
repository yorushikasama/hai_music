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
}
