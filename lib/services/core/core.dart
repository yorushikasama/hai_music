/// 核心基础设施模块
///
/// 提供整个应用的基础服务，被其他所有模块广泛依赖。
/// 包含网络请求、偏好存储、音质管理、路径管理和平台通道等核心能力。
///
/// 模块职责：
/// - [DioClient] — HTTP 客户端封装，含指数退避重试和超时配置
/// - [PreferencesService] — SharedPreferences 封装，全局偏好持久化
/// - [AudioQualityService] — 音质管理，获取/设置当前音质等级
/// - [StoragePathManager] — 存储路径管理，统一管理下载/封面/缓存/歌词目录
/// - [MediaScanService] — Android 平台通道，MediaStore 扫描/删除/保存操作
library core;

export 'dio_client.dart';
export 'preferences_service.dart';
export 'audio_quality_service.dart';
export 'storage_path_manager.dart';
export 'media_scan_service.dart';
