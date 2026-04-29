/// 播放模块
///
/// 负责音频播放的完整链路，从底层播放器到播放控制、播放列表管理。
/// 采用策略模式实现桌面/移动双端适配。
///
/// 架构分层：
/// ┌─────────────────────────────────────────┐
/// │ PlaybackControllerService (播放控制核心) │
/// ├─────────────────────────────────────────┤
/// │ PlaybackBackend (抽象接口)              │
/// │  ├── DesktopPlaybackBackend             │
/// │  └── MobilePlaybackBackend              │
/// ├─────────────────────────────────────────┤
/// │ AudioPlayerInterface (播放器抽象)       │
/// │  ├── MobileAudioPlayer (just_audio)     │
/// │  └── MediaKitDesktopPlayer (media_kit)  │
/// └─────────────────────────────────────────┘
///
/// 关键服务：
/// - [PlaybackControllerService] — 播放控制核心，协调后端/URL/缓存
/// - [PlaylistManagerService] — 播放列表管理，歌曲增删/模式切换
/// - [SongUrlService] — 歌曲URL获取与缓存，含请求去重
/// - [AudioHandlerService] — audio_service 的 AudioHandler 实现
/// - [AudioServiceManager] — AudioHandler 全局访问管理器
library playback;

export 'audio_player_interface.dart';
export 'audio_player_factory.dart';
export 'mobile_audio_player.dart';
export 'media_kit_desktop_player.dart';
export 'audio_handler_service.dart';
export 'audio_service_manager.dart';
export 'playback_backend.dart';
export 'desktop_playback_backend.dart';
export 'mobile_playback_backend.dart';
export 'playback_controller_service.dart';
export 'playlist_manager_service.dart';
export 'song_url_service.dart';
