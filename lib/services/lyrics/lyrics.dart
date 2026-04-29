/// 歌词模块
///
/// 提供歌词的获取、缓存和加载能力，支持多级回退加载策略。
///
/// 加载策略（按优先级）：
/// 1. Song 内嵌歌词
/// 2. 本地缓存文件
/// 3. 本地目录扫描
/// 4. Supabase 数据库
/// 5. 音乐 API
///
/// 关键服务：
/// - [LyricsLoadingService] — 歌词加载服务，多级回退加载
/// - [LyricsService] — 歌词数据库服务(Supabase)，读写歌词字段
/// - [LyricsCacheService] — 歌词缓存服务，文件缓存(7天过期)
library lyrics;

export 'lyrics_service.dart';
export 'lyrics_cache_service.dart';
export 'lyrics_loading_service.dart';
