/// 应用常量配置
class AppConstants {
  // ==================== 应用信息 ====================
  static const String appName = 'Hai Music';
  static const String appVersion = '1.0.0';
  
  // ==================== API 配置 ====================
  static const String apiBaseUrl = 'https://api.injahow.cn';
  static const String searchApiUrl = 'https://api.vkeys.cn/v2/music/tencent';
  
  // ==================== 缓存配置 ====================
  static const int maxSearchHistory = 20;
  static const int maxPlayHistory = 50;
  static const int lyricsCacheDays = 7;
  
  // ==================== 播放配置 ====================
  static const int maxConsecutiveFailures = 5;
  static const int playUrlTimeout = 10; // 秒
  static const int defaultSongDuration = 180; // 秒（默认3分钟）
  
  // ==================== 音质配置 ====================
  static const int qualityStandard = 4;  // 标准音质
  static const int qualityHigh = 5;      // HQ高音质
  static const int qualityLossless = 14; // 臻品母带2.0
  
  // ==================== 搜索配置 ====================
  static const int searchResultsPerPage = 30;
  static const int maxSearchResults = 60;
  
  // ==================== 下载配置 ====================
  static const int downloadTimeout = 30; // 秒
  static const int audioDurationTimeout = 3; // 秒
  
  // ==================== UI 配置 ====================
  static const double miniPlayerHeight = 72.0;
  static const double bottomNavHeight = 60.0;
  
  // ==================== 文件路径 ====================
  static const String musicFolder = 'music';
  static const String audioFolder = 'audio';
  static const String coverFolder = 'covers';
  
  // ==================== 文件扩展名 ====================
  static const String audioExtension = '.mp3';
  static const String coverExtension = '.jpg';
}
