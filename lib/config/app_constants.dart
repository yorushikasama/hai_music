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

  static const int maxSearchHistory = 20;
  static const int maxPlayHistory = 50;
  static const int lyricsCacheDays = 7;

  static const int defaultSongDuration = 180;

  static const int maxSearchResults = 60;

  static const int audioDurationTimeout = 3;

  static const String coverExtension = '.jpg';
}
