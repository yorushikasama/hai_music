
import 'repositories/music_repository.dart';
import 'services/cache/data_cache_service.dart';
import 'services/core/dio_client.dart';
import 'services/download/download_service.dart';
import 'services/favorite/favorite_manager_service.dart';
import 'services/network/music_api_service.dart';
import 'services/core/preferences_service.dart';
import 'utils/logger.dart';

/// 全局服务定位器
///
/// 集中管理核心服务的创建与初始化，确保单例生命周期可控。
/// 仅注册需要显式初始化顺序的核心服务，其他服务通过自身工厂构造函数保证单例。
///
/// 已注册服务：
/// - [PreferencesService] — 偏好存储（需最先初始化，被其他服务依赖）
/// - [DioClient] — HTTP 客户端
/// - [MusicApiService] — 音乐 API
/// - [DataCacheService] — 数据缓存
/// - [FavoriteManagerService] — 收藏管理
/// - [DownloadService] — 下载服务
/// - [MusicRepository] — 音乐数据仓库
class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  late PreferencesService preferencesService;
  late DioClient dioClient;
  late MusicApiService musicApiService;
  late DataCacheService dataCacheService;
  late FavoriteManagerService favoriteManagerService;
  late DownloadService downloadService;
  late MusicRepository musicRepository;

  Future<void> setup() async {
    Logger.info('初始化 Service Locator', 'ServiceLocator');

    preferencesService = PreferencesService();
    dioClient = DioClient();
    musicApiService = MusicApiService();
    dataCacheService = DataCacheService();
    favoriteManagerService = FavoriteManagerService();
    downloadService = DownloadService();
    musicRepository = MusicRepository();
  }
}

final locator = ServiceLocator();

Future<void> setupServiceLocator() async {
  await locator.setup();
}
