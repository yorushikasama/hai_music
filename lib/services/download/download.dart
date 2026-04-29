/// 下载模块
///
/// 负责音乐文件的完整下载流程，包括任务调度、文件下载、元数据写入和数据库记录。
///
/// 架构分层：
/// ┌─────────────────────────────────────────┐
/// │ DownloadManager (任务调度，并发控制)     │
/// ├─────────────────────────────────────────┤
/// │ DownloadService (完整下载流程)           │
/// │  音频下载 → 封面持久化 → 元数据写入     │
/// │  → 歌词获取 → 数据库记录                │
/// ├─────────────────────────────────────────┤
/// │ AudioDownloadService (纯文件下载)        │
/// │ AudioMetadataService (元数据写入)        │
/// │ DownloadDatabase (SQLite 持久化)         │
/// │ DownloadRecoveryService (下载恢复)       │
/// └─────────────────────────────────────────┘
///
/// 关键服务：
/// - [DownloadManager] — 任务队列调度，并发控制(1-5)，WiFi/存储检查
/// - [DownloadService] — 完整下载流程编排
/// - [AudioDownloadService] — 音频URL解析+文件下载+进度回调
/// - [AudioMetadataService] — 音频元数据写入(标题/歌手/封面嵌入)
/// - [DownloadDatabase] — 下载记录SQLite数据库CRUD
/// - [DownloadRecoveryService] — 卸载重装后从文件系统恢复下载记录
library download;

export 'download_service.dart';
export 'download_manager.dart';
export 'download_database.dart';
export 'audio_download_service.dart';
export 'audio_metadata_service.dart';
export 'download_recovery_service.dart';
