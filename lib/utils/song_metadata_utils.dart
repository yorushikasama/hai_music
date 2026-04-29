import 'package:path/path.dart' as path;

class SongMetadataUtils {
  static final RegExp _trackPattern = RegExp(
    r'^(track\s*\d+|曲目\s*\d+|音轨\s*\d+)$',
    caseSensitive: false,
  );

  static final RegExp _unknownPattern = RegExp(
    r'^(unknown|<unknown>|未知|无标题|untitled)$',
    caseSensitive: false,
  );

  static final RegExp _pureNumberPattern = RegExp(r'^\d+$');

  static final RegExp _unknownArtistPattern = RegExp(
    r'^(unknown|<unknown>|未知|未知艺术家|未知歌手|various\s+artists?)$',
    caseSensitive: false,
  );

  static final RegExp _platformSuffixPattern = RegExp(
    r'\s*\[(mqms\d*|netease|kugou|kuwo|xiami|baidu|qq|qqmusic)\]$',
    caseSensitive: false,
  );

  static const List<String> supportedAudioExtensions = [
    '.mp3', '.m4a', '.aac', '.flac', '.wav', '.ogg', '.opus', '.wma',
  ];

  static const List<String> supportedAudioFormats = [
    'mp3', 'm4a', 'aac', 'flac', 'wav', 'ogg', 'opus', 'wma',
  ];

  bool isLowQualityTitle(String title) {
    if (title.isEmpty) return true;
    final trimmed = title.trim();
    if (_trackPattern.hasMatch(trimmed)) return true;
    if (_unknownPattern.hasMatch(trimmed)) return true;
    if (_pureNumberPattern.hasMatch(trimmed)) return true;
    return false;
  }

  bool isLowQualityArtist(String artist) {
    if (artist.isEmpty) return true;
    final trimmed = artist.trim();
    if (_unknownArtistPattern.hasMatch(trimmed)) return true;
    return false;
  }

  String cleanFileName(String name) {
    var cleaned = path.basenameWithoutExtension(name);
    cleaned = cleaned.replaceAll(_platformSuffixPattern, '');
    return cleaned.trim();
  }

  ({String title, String artist})? parseFromFilePath(String filePath) {
    final cleaned = cleanFileName(filePath);
    if (cleaned.isEmpty) return null;

    if (cleaned.contains(' - ')) {
      final parts = cleaned.split(' - ');
      if (parts.length >= 2) {
        return (
          artist: parts[0].trim(),
          title: parts.sublist(1).join(' - ').trim(),
        );
      }
    }

    return null;
  }

  bool isSupportedAudioFormat(String extension) {
    final ext = extension.toLowerCase();
    return supportedAudioFormats.contains(ext) ||
        supportedAudioExtensions.contains(ext.startsWith('.') ? ext : '.$ext');
  }

  String safeCacheName(String audioPath, String prefix, String ext) {
    final hash = audioPath.hashCode.toRadixString(36);
    final hash2 = audioPath.length.toRadixString(36);
    return '${prefix}_${hash}_$hash2$ext';
  }

  bool isLrcFormat(String text) {
    return text.contains(RegExp(r'\[\d{2}:\d{2}'));
  }
}
