/// 缓存模块
///
/// 提供多级缓存管理能力，包括智能播放缓存、数据缓存和缓存统计清理。
///
/// 缓存层级：
/// - SmartCacheService — 播放时自动缓存(50首/500MB上限)，LRU淘汰
/// - DataCacheService — 推荐歌单/每日推荐等数据缓存(24小时过期)
/// - CacheManagerService — 缓存统计与一键清理
///
/// 关键服务：
/// - [SmartCacheService] — 智能播放缓存，自动缓存+LRU淘汰+过期清理
/// - [DataCacheService] — 数据缓存，推荐歌单/歌单详情的SP缓存
/// - [CacheManagerService] — 缓存管理，统计大小+一键清理
library cache;

export 'smart_cache_service.dart';
export 'data_cache_service.dart';
export 'cache_manager_service.dart';
