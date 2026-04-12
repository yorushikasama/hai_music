# 海音乐 (Hai Music) 项目架构文档

## 1. 项目概述

海音乐是一款跨平台音乐播放器应用，基于 Flutter 框架构建，支持 Android、iOS、Windows、macOS、Linux 平台。应用采用 Provider 状态管理模式，结合自定义 Service Locator 实现依赖注入，实现了播放、缓存、下载、歌词、收藏等核心功能。

## 2. 技术选型

| 领域 | 技术方案 | 选型依据 |
|------|----------|----------|
| UI 框架 | Flutter 3.x | 跨平台一致性、Dart 语言优势 |
| 状态管理 | Provider + ChangeNotifier | 轻量级、与 Flutter 深度集成、调试友好 |
| 依赖注入 | 自定义 ServiceLocator | 避免 get_it 网络依赖问题、满足项目需求 |
| 网络请求 | Dio | 拦截器支持、取消请求、下载进度 |
| 本地存储 | SharedPreferences | 轻量级键值存储、跨平台支持 |
| 音频播放（桌面端） | media_kit / just_audio | 桌面端原生音频支持 |
| 音频播放（移动端） | audio_service + just_audio | 后台播放、系统通知栏控制 |
| 音频服务管理 | audio_service | 系统级媒体控制集成 |

## 3. 系统架构

### 3.1 分层架构

```
┌─────────────────────────────────────────────────┐
│                   UI 层 (Screens/Widgets)         │
│  ┌──────────┐ ┌──────────┐ ┌──────────────────┐ │
│  │ Screens  │ │ Widgets  │ │  Theme System     │ │
│  └────┬─────┘ └────┬─────┘ └────────┬─────────┘ │
├───────┼─────────────┼───────────────┼────────────┤
│       │        Provider 层           │            │
│  ┌────▼─────────────▼───────────────▼──────────┐ │
│  │ MusicProvider │ FavoriteProvider │ Theme...  │ │
│  │ AudioSettings │ SleepTimerProvider           │ │
│  └────┬──────────────────────────────┬─────────┘ │
├───────┼──────────────────────────────┼────────────┤
│       │        Service 层             │            │
│  ┌────▼──────────────────────────────▼──────────┐ │
│  │ PlaybackController │ SmartCache │ Download   │ │
│  │ SongUrl │ FavoriteManager │ PlayHistory      │ │
│  │ Preferences │ MusicApi │ DioClient           │ │
│  └────┬──────────────────────────────┬─────────┘ │
├───────┼──────────────────────────────┼────────────┤
│       │        数据层                 │            │
│  ┌────▼──────────────────────────────▼──────────┐ │
│  │ Repository (MusicRepository)                  │ │
│  │ Models (Song, PlayHistory, DownloadedSong)    │ │
│  │ Storage (SharedPreferences, File System)      │ │
│  └──────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────┘
```

### 3.2 核心设计模式

#### 策略模式 - PlaybackBackend

播放系统采用策略模式，通过抽象接口 `PlaybackBackend` 隔离平台差异：

```
PlaybackBackend (abstract)
├── DesktopPlaybackBackend  → media_kit / just_audio
└── MobilePlaybackBackend   → audio_service + MusicAudioHandler
```

- `DesktopPlaybackBackend`：封装 just_audio，通过 AudioPlayerFactory 获取播放器实例
- `MobilePlaybackBackend`：封装 audio_service，通过 AudioServiceManager 获取 MusicAudioHandler

`PlaybackControllerService` 通过 `PlaybackBackend` 接口与底层交互，消除了 75% 的平台分支代码。

#### 服务定位器模式 - ServiceLocator

自定义轻量级服务定位器，用于管理单例服务的注册和获取：

```dart
class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._();
  
  late final PreferencesService preferencesService;
  late final DioClient dioClient;
  late final MusicApiService musicApiService;
  late final DataCacheService dataCacheService;
  late final FavoriteManagerService favoriteManagerService;
  late final DownloadService downloadService;
  late final MusicRepository musicRepository;
}
```

#### 仓库模式 - MusicRepository

封装数据访问逻辑，提供缓存优先策略：

```dart
class MusicRepository {
  Future<List<Song>> searchSongs(String keyword) async {
    // 1. 检查缓存
    // 2. 缓存未命中则请求 API
    // 3. 写入缓存并返回
  }
}
```

#### 乐观更新模式 - FavoriteProvider

收藏操作采用乐观更新策略，先更新本地状态和 UI，再异步执行云端同步，失败时回滚：

```dart
// 1. 立即更新本地状态 + 通知 UI
_favoriteSongIds.add(songId);
if (wasFavorite) _favoriteSongIds.remove(songId);
notifyListeners();

// 2. 异步执行云端同步
final success = await _favoriteManager.toggleFavorite(...);

// 3. 失败时回滚
if (!success) { /* 恢复原状态 */ }
```

## 4. 模块详解

### 4.1 Provider 层

| Provider | 职责 | 监听的 Service |
|----------|------|---------------|
| MusicProvider | 播放控制、播放列表、播放模式、会话管理 | PlaybackControllerService |
| FavoriteProvider | 收藏状态管理、收藏切换、FavoriteSong 列表缓存 | FavoriteManagerService, PreferencesService |
| AudioSettingsProvider | 音质设置、歌词翻译开关、音质切换、缓存联动失效 | PreferencesService, PlaybackControllerService, SongUrlService |
| SleepTimerProvider | 睡眠定时器状态、定时器控制 | SleepTimerService |
| ThemeProvider | 主题切换、主题持久化、ThemeData 生成 | PreferencesService |

**Provider 间交互关系：**
- `SleepTimerProvider.onPausePlayback` → `MusicProvider.forcePause()`
- `AudioSettingsProvider.playbackController` → `MusicProvider.playbackController`（setter 注入）
- `AudioSettingsProvider.setAudioQuality()` → `SongUrlService.invalidateAllCache()`（音质格式变化时联动失效）
- `FavoriteProvider.toggleFavorite()` → 乐观更新 UI + 异步云端同步 + 失败回滚

### 4.2 Service 层

#### 播放系统

```
PlaybackControllerService
├── PlaybackBackend (策略接口)
│   ├── playingStream / positionStream / durationStream
│   ├── completionStream / mediaItemStream
│   └── playSong / pause / resume / seek / stop / ...
├── ValueNotifier<Duration> positionNotifier
├── ValueNotifier<Duration?> durationNotifier
└── _handlePlaybackCompleted() (桌面端专用)
```

关键设计决策：
- 播放完成检测仅在桌面端执行（移动端由 AudioHandler 自行处理）
- 单曲循环通过 `await seek(Duration.zero)` + `resume()` 避免竞态条件
- `_completionHandled` 标志防止重复触发完成事件

#### 缓存系统

```
SmartCacheService (单例)
├── _memoryCache: List<_CacheEntry>    ← 内存缓存层
├── _memoryCacheDirty: bool            ← 脏标记
├── _persistTimer: Timer               ← 延迟回写 (5秒)
├── cacheOnPlay() → 边播边缓存
├── getCachedAudioPath() → 获取缓存路径 (在 _synchronized 内)
├── _synchronized() → 互斥锁防竞态
├── _deleteAllQualityVariants() → 清理所有音质变体
├── _cleanExpiredCache() / _cleanOldCache() → 缓存淘汰
├── _cacheHits / _cacheMisses → 命中率统计
└── getCacheStats() → 返回 hitRate, hits, misses

SongUrlService (单例)
├── 内存缓存 + 持久化缓存
├── _cleanupTimer: Timer.periodic(30分钟) → 定时清理
├── invalidateSongCache() → 同步清理内存+持久化
├── _cacheHits / _cacheMisses → 命中率统计
├── getCacheStats() → 返回 hitRate, hits, misses
└── dispose() → 释放 Timer

DataCacheService
└── API 数据缓存（搜索结果、歌单等）
```

关键设计决策：
- SmartCacheService 使用内存缓存层 + 延迟回写：运行时直接操作内存数据结构，修改后 5 秒批量回写 SharedPreferences
- `getCachedAudioPath` 纳入 `_synchronized` 保护，消除竞态条件
- `_deleteAllQualityVariants()` 确保清理缓存时删除所有音质变体文件（.mp3, .flac, .ec3）
- SongUrlService 使用 `Timer.periodic(30 分钟)` 定时清理过期缓存
- 音质切换时，`AudioSettingsProvider` 检测文件格式变化并触发 `SongUrlService.invalidateAllCache()`

#### 下载系统

```
DownloadService (单例)
├── downloadSongWithCancel() → 带取消的下载
├── _synchronized() → 互斥锁防竞态
├── getDownloadedSongs() → 文件验证 + 缓存
└── deleteDownloadedSong() → 删除音频+封面+歌词
```

#### 收藏系统

```
FavoriteProvider
├── _favoriteSongIds: Set<String>       ← ID 集合 (快速查询)
├── _favoriteSongs: List<FavoriteSong>  ← 完整列表 (页面展示)
├── _isFavoritesLoaded: bool            ← 加载状态
├── toggleFavorite() → 乐观更新 + 异步同步 + 失败回滚
├── loadFavoriteSongs() → 首次加载 (带缓存)
└── refreshFavoriteSongs() → 强制刷新

FavoriteManagerService (单例)
├── addFavorite() → 本地存储 + 云端同步 (Supabase + R2)
├── removeFavorite() → 本地删除 + 云端删除
├── getFavorites() → 云端获取 (同步模式) / 本地获取
└── toggleFavorite() → 无重复写入的切换
```

关键设计决策：
- FavoriteProvider 维护两层缓存：`_favoriteSongIds`（O(1) 查询）和 `_favoriteSongs`（页面展示）
- FavoritesScreen 首次进入使用 Provider 缓存数据，后台异步刷新
- 收藏按钮使用 `AnimatedSwitcher` 实现平滑过渡动画
- 批量操作使用 `Future.wait` 并行执行

### 4.3 主题系统

```
ThemeProvider
├── AppThemeMode (8 种主题模式)
│   └── colors getter → ThemeColors
├── ThemeColors (语义化颜色系统)
│   ├── 基础色: background, surface, card, accent, border
│   ├── 文字色: textPrimary, textSecondary
│   └── 语义色: error, warning, success, info, favorite
├── AppStyles (统一间距和圆角)
└── ThemeData 生成 (缓存机制)
```

关键设计决策：
- 语义化颜色 token（error/warning/success/info/favorite）替代硬编码颜色
- 亮色主题边框使用 `Color(0x1A000000)` 而非白色（确保可见性）
- ThemeProvider 缓存 ThemeData，仅在主题切换时失效
- 所有 UI 组件使用 `colors.favorite` 统一收藏图标颜色

### 4.4 数据模型

| Model | 关键字段 | 序列化 |
|-------|----------|--------|
| Song | id, title, artist, album, coverUrl, audioUrl, duration, platform, lyricsLrc, lyricsTrans | fromApiJson / fromJson / toJson |
| FavoriteSong | id, title, artist, album, coverUrl, duration, platform, lyricsLrc, localAudioPath, r2AudioUrl | fromJson / toJson |
| PlaybackMediaItem | id, title, artist, album, duration, coverUrl, audioUrl, platform, lyricsTrans | toSong() |
| PlayHistory | id, title, artist, album, coverUrl, duration, platform, playedAt | fromJson / toJson |
| DownloadedSong | id, title, artist, localAudioPath, localCoverPath, localLyricsPath, localTransPath, source | fromJson / toJson |
| AudioQuality | 8 级音质枚举 (standard → masterPlus) | parse / fromName / fromValue |
| PlayMode | sequence / single / shuffle | next 循环 |

## 5. 数据流

### 5.1 播放流程

```
用户点击播放 → MusicProvider.playSongList()
  → PlaybackControllerService.playSongsFromList()
    → PlaybackBackend.playSongsFromList()
      ├── DesktopPlaybackBackend → AudioPlayerFactory.play()
      └── MobilePlaybackBackend → MusicAudioHandler.updatePlaylist() + play()
    → PlaybackBackend.mediaItemStream → PlaybackControllerService
      → MusicProvider 更新当前歌曲 → UI 重建
```

### 5.2 缓存流程

```
歌曲开始播放 → SmartCacheService.cacheOnPlay()
  → _synchronized() 获取互斥锁
  → 检查 _memoryCache 中的缓存条目
  → 检查当前音质缓存文件是否存在
  → _ensureCacheSpace() 清理过期/超量缓存
    → _deleteAllQualityVariants() 删除所有音质变体
  → _downloadToPlayCache() 下载音频文件
  → _addToCacheList() 更新内存缓存 + 标记脏
  → 5秒后 _persistToDisk() 批量回写
  → 释放互斥锁
```

### 5.3 音质切换缓存联动流程

```
用户切换音质 → AudioSettingsProvider.setAudioQuality()
  → 保存新音质到 SharedPreferences
  → _invalidateCacheOnQualityChange()
    → 检查 fileExtension 是否变化
    → 如果变化 (.mp3 → .flac): SongUrlService.invalidateAllCache()
    → 如果未变 (.mp3 → .mp3): 保留 URL 缓存
  → notifyListeners()
  → _executeQualitySwitch() 重载当前播放
```

### 5.4 收藏操作流程

```
用户点击收藏 → FavoriteProvider.toggleFavorite()
  → 乐观更新: 立即修改 _favoriteSongIds + _favoriteSongs
  → notifyListeners() → UI 即时响应 (<100ms)
  → 异步: FavoriteManagerService.toggleFavorite()
    → 本地: PreferencesService 写入
    → 云端: Supabase + R2 同步 (10-30秒)
  → 失败回滚: 恢复 _favoriteSongIds + _favoriteSongs
  → notifyListeners() → UI 回滚
```

### 5.5 主题切换流程

```
用户切换主题 → ThemeProvider.setTheme()
  → 更新 _currentTheme
  → 失效 _cachedThemeData
  → notifyListeners()
  → 持久化到 SharedPreferences
  → UI 通过 Provider.of<ThemeProvider> 重建
    → colors.* 语义化颜色应用到所有组件
```

## 6. 关键设计决策

### 6.1 MusicProvider 拆分

原始 MusicProvider（557 行，40+ 公开方法）被拆分为 4 个职责单一的 Provider：
- **MusicProvider**（351 行）：播放控制、播放列表、播放模式
- **FavoriteProvider**：收藏状态管理、FavoriteSong 列表缓存、乐观更新
- **AudioSettingsProvider**：音质和歌词设置、缓存联动失效
- **SleepTimerProvider**：睡眠定时器

### 6.2 播放后端抽象

通过 `PlaybackBackend` 接口消除平台分支：
- 桌面端和移动端各自实现独立的播放逻辑
- `PlaybackControllerService` 不再包含 `isDesktop` 条件判断
- 新增平台只需实现 `PlaybackBackend` 接口

### 6.3 竞态条件防护

SmartCacheService、DownloadService、PlayHistoryService 均使用基于 Completer 的互斥锁：
```dart
Completer<void>? _lock;

Future<T> _synchronized<T>(Future<T> Function() action) async {
  while (_lock != null) {
    await _lock!.future;
  }
  _lock = Completer<void>();
  try {
    return await action();
  } finally {
    final lock = _lock!;
    _lock = null;
    lock.complete();
  }
}
```

### 6.4 音质变体缓存清理

缓存文件路径格式为 `{songId}{extension}`，不同音质有不同扩展名。清理时必须遍历所有可能的扩展名（.mp3, .flac, .ec3），否则切换音质后旧文件会成为孤立文件。

### 6.5 缓存内存层 + 延迟回写

SmartCacheService 的缓存元数据采用内存优先策略：
- 启动时从 SharedPreferences 加载到 `_memoryCache` 列表
- 运行时直接操作内存数据结构（O(1) 查找）
- 修改后标记 `_memoryCacheDirty`，5 秒后批量回写
- 避免每次缓存操作都进行 JSON 序列化/反序列化

### 6.6 乐观更新策略

FavoriteProvider 的收藏操作采用乐观更新：
- 先更新本地状态和 UI，用户感知延迟 <100ms
- 异步执行云端同步（可能需要 10-30 秒）
- 同步失败时自动回滚本地状态
- FavoriteProvider 同时维护 ID 集合（O(1) 查询）和完整列表（页面展示）

### 6.7 音质切换缓存联动

音质切换时自动检测文件格式变化：
- 格式变化（如 .mp3 → .flac）时清除 SongUrlService 缓存，确保获取新格式 URL
- 格式未变（如 HQ → HQ+，同为 .mp3）时保留缓存，避免不必要的网络请求

## 7. 测试体系

### 7.1 测试结构

```
test/
├── models/
│   ├── audio_quality_test.dart     (音质枚举全面测试)
│   ├── downloaded_song_test.dart   (下载歌曲模型测试)
│   ├── favorite_song_test.dart     (收藏歌曲模型测试)
│   ├── play_history_test.dart      (播放历史模型测试)
│   ├── play_mode_test.dart         (播放模式测试)
│   ├── playlist_test.dart          (播放列表测试)
│   ├── song_test.dart              (歌曲模型测试)
│   └── storage_config_test.dart    (存储配置测试)
├── providers/
│   ├── favorite_provider_test.dart (收藏 Provider 测试)
│   └── theme_provider_test.dart    (主题 Provider 测试)
├── services/
│   ├── dio_client_test.dart        (HTTP 客户端测试)
│   ├── lyrics_loading_service_test.dart
│   ├── playback_backend_test.dart  (播放后端接口测试)
│   ├── play_history_service_test.dart
│   ├── playlist_manager_service_test.dart
│   ├── smart_cache_service_test.dart
│   ├── sleep_timer_service_test.dart (睡眠定时器测试)
│   ├── song_url_service_test.dart
│   └── storage_config_service_test.dart
├── theme/
│   └── theme_colors_test.dart      (主题颜色系统测试)
├── utils/
│   ├── cache_utils_test.dart
│   ├── format_utils_test.dart
│   └── result_test.dart
├── test_helper.dart                (测试辅助：SharedPreferences mock)
└── system_integration_test.dart     (跨模块集成测试)
```

### 7.2 测试覆盖范围

- **Model 层**：序列化/反序列化、字段默认值、往返一致性
- **Provider 层**：状态变更通知、初始化、Provider 间交互、乐观更新
- **Service 层**：单例模式、缓存操作、竞态条件防护、定时清理
- **Theme 系统**：颜色可见性、语义化 token、主题切换
- **集成测试**：跨模块数据流、PlaybackMediaItem→Song→JSON 往返、PlayMode 循环、缓存命中率统计

## 8. 目录结构

```
lib/
├── config/           # 应用常量配置
├── extensions/       # Dart 扩展方法
├── models/           # 数据模型
├── providers/        # Provider 状态管理
├── repositories/     # 数据仓库层
├── screens/          # 页面
│   ├── discover/     # 发现页子组件
│   ├── downloaded/   # 已下载页子组件
│   ├── library/      # 音乐库子组件
│   ├── player/       # 播放器子组件
│   ├── playlist/     # 播放列表子组件
│   └── search/       # 搜索页子组件
├── services/         # 业务服务
├── theme/            # 主题系统
├── utils/            # 工具类
├── widgets/          # 共享组件
├── main.dart         # 应用入口
├── service_locator.dart  # 服务定位器
└── window_config.dart    # 窗口配置
```
