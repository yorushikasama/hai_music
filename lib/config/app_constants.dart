import 'package:package_info_plus/package_info_plus.dart';

class AppConstants {
  static const String appName = 'Hai Music';

  static Future<String> getAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version;
    } catch (e) {
      return '1.0.11';
    }
  }

  static const String searchApiUrl = 'https://api.vkeys.cn/v2/music/tencent';
  static const String lyricApiUrl = 'https://api.vkeys.cn/v2/music/tencent/lyric';
  static const String songInfoApiUrl = 'https://api.vkeys.cn/v2/music/tencent/info';
  static const String playlistInfoApiUrl = 'https://api.vkeys.cn/v2/music/tencent/dissinfo';

  static const String playlistScraperUrl = 'https://y.qq.com/';
  static const String scraperUserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  static const int maxSearchHistory = 20;
  static const int maxPlayHistory = 50;
  static const int lyricsCacheDays = 7;
  static const int dataCacheHours = 24;

  static const int defaultSongDuration = 180;
  static const int maxSearchResults = 60;
  static const int defaultSearchLimit = 30;

  static const int audioDurationTimeout = 3;

  static const String coverExtension = '.jpg';

  static const int maxCoverSizeBytes = 5 * 1024 * 1024;
  static const int maxDownloadSpaceBytes = 10 * 1024 * 1024 * 1024;
  static const int defaultMaxConcurrentDownloads = 3;
  static const int smartCacheMaxSongs = 50;
  static const int smartCacheMaxSizeBytes = 500 * 1024 * 1024;

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);
  static const Duration retryDelay = Duration(milliseconds: 1000);
  static const Duration urlRequestTimeout = Duration(seconds: 10);
  static const Duration coverExtractTimeout = Duration(seconds: 5);
  static const Duration playbackTimeout = Duration(seconds: 15);
  static const Duration sessionSaveDebounce = Duration(seconds: 3);
  static const Duration cachePersistDelay = Duration(seconds: 5);
  static const Duration audioServiceInitTimeout = Duration(seconds: 10);

  static const int fileValidationCacheMinutes = 5;
}
