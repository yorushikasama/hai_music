import '../models/song.dart';

abstract class PlaybackBackend {
  Stream<bool> get playingStream;
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Stream<void> get completionStream;
  Stream<PlaybackMediaItem?> get mediaItemStream;

  bool get isPlaying;
  Duration get currentPosition;

  Future<void> playSong(Song song);
  Future<void> pause();
  Future<void> resume();
  Future<void> seek(Duration position);
  Future<void> stop();
  Future<void> setVolume(double volume);
  Future<void> setSpeed(double speed);

  Future<void> playSongsFromList(List<Song> songs, int startIndex);
  Future<void> skipToNext();
  Future<void> skipToPrevious();
  Future<void> skipToQueueItem(int index);

  Future<void> updateMediaItem(Song song);
  void updatePlaylist(List<Song> songs, {int initialIndex = 0, Duration? initialPosition});

  void dispose();
}

class PlaybackMediaItem {
  final String id;
  final String title;
  final String artist;
  final String album;
  final Duration? duration;
  final String? coverUrl;
  final String? audioUrl;
  final String? platform;
  final String? r2CoverUrl;
  final String? lyricsLrc;
  final String? lyricsTrans;

  const PlaybackMediaItem({
    required this.id,
    required this.title,
    required this.artist,
    this.album = '',
    this.duration,
    this.coverUrl,
    this.audioUrl,
    this.platform,
    this.r2CoverUrl,
    this.lyricsLrc,
    this.lyricsTrans,
  });

  Song toSong() {
    return Song(
      id: id,
      title: title,
      artist: artist,
      album: album,
      duration: duration?.inSeconds,
      coverUrl: coverUrl ?? '',
      audioUrl: audioUrl ?? '',
      platform: platform,
      r2CoverUrl: r2CoverUrl,
      lyricsLrc: lyricsLrc,
      lyricsTrans: lyricsTrans,
    );
  }
}
