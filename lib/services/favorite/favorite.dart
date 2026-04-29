/// 收藏与云同步模块
///
/// 负责歌曲收藏管理和云端同步，协调 Supabase 数据库、R2 对象存储和本地存储。
///
/// 数据流向：
/// 收藏操作 → FavoriteManagerService (协调)
///   ├── SupabaseService (云端数据库 CRUD)
///   ├── R2StorageService (云端文件上传/删除)
///   ├── StorageConfigService (加密配置管理)
///   └── PreferencesService (本地收藏列表)
///
/// 关键服务：
/// - [FavoriteManagerService] — 收藏协调服务，统一管理本地+云端收藏
/// - [SupabaseService] — Supabase 数据库服务，收藏表 CRUD
/// - [R2StorageService] — Cloudflare R2 对象存储(S3兼容)
/// - [StorageConfigService] — 存储配置服务，敏感字段加密存储
/// - [ClipboardConfigParser] — 剪贴板配置解析，快速导入配置
library favorite;

export 'favorite_manager_service.dart';
export 'supabase_service.dart';
export 'r2_storage_service.dart';
export 'storage_config_service.dart';
export 'clipboard_config_parser.dart';
