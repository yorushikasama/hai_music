/// 存储与文件管理模块
///
/// 负责封面文件的持久化管理和本地音频文件的扫描发现。
///
/// 关键服务：
/// - [CoverPersistenceService] — 封面持久化，下载/复制/索引封面文件，
///   支持 Android 16 平台通道回退(MediaStore API)
/// - [LocalAudioScanner] — 本地音频扫描，Android 用 MediaStore 查询，
///   桌面用文件系统递归扫描，含元数据回退解析
library storage;

export 'cover_persistence_service.dart';
export 'local_audio_scanner.dart';
