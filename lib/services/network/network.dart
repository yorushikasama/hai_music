/// 网络与API模块
///
/// 提供音乐 API 调用和网页数据抓取能力。
///
/// 关键服务：
/// - [MusicApiService] — 音乐API服务，搜索/歌词/URL/歌单，
///   含音质降级和翻译歌词支持
/// - [PlaylistScraperService] — QQ音乐首页推荐歌单爬虫，
///   解析HTML提取歌单ID/标题/封面
library network;

export 'music_api_service.dart';
export 'playlist_scraper_service.dart';
