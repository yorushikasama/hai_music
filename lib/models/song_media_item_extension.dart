import 'package:audio_service/audio_service.dart';
import 'song.dart';

/// Song 与 MediaItem 之间的转换扩展
/// 统一 audio_handler_service 和 mobile_playback_backend 中的转换逻辑
extension SongMediaItemExtension on Song {
  MediaItem toMediaItem() {
    return MediaItem(
      id: id,
      title: title,
      artist: artist,
      album: album,
      duration: duration != null ? Duration(seconds: duration!) : null,
      artUri: coverUrl.isNotEmpty ? Uri.tryParse(coverUrl) : null,
      extras: {
        'audioUrl': audioUrl,
        'platform': platform ?? 'unknown',
        'r2CoverUrl': r2CoverUrl ?? '',
        'lyricsLrc': lyricsLrc ?? '',
        'lyricsTrans': lyricsTrans ?? '',
        'localCoverPath': localCoverPath ?? '',
        'localLyricsPath': localLyricsPath ?? '',
        'localTransPath': localTransPath ?? '',
      },
    );
  }
}

extension MediaItemSongExtension on MediaItem {
  Song toSong() {
    String? toNullableString(dynamic value) {
      final str = value?.toString();
      return (str != null && str.isNotEmpty) ? str : null;
    }

    return Song(
      id: id,
      title: title,
      artist: artist ?? '',
      album: album ?? '',
      duration: duration?.inSeconds,
      coverUrl: artUri?.toString() ?? '',
      audioUrl: (extras?['audioUrl'] ?? '').toString(),
      platform: toNullableString(extras?['platform']),
      r2CoverUrl: toNullableString(extras?['r2CoverUrl']),
      lyricsLrc: toNullableString(extras?['lyricsLrc']),
      lyricsTrans: toNullableString(extras?['lyricsTrans']),
      localCoverPath: toNullableString(extras?['localCoverPath']),
      localLyricsPath: toNullableString(extras?['localLyricsPath']),
      localTransPath: toNullableString(extras?['localTransPath']),
    );
  }
}
