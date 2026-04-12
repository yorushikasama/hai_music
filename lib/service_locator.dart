import 'repositories/music_repository.dart';
import 'services/data_cache_service.dart';
import 'services/dio_client.dart';
import 'services/download_service.dart';
import 'services/favorite_manager_service.dart';
import 'services/music_api_service.dart';
import 'services/preferences_service.dart';
import 'utils/logger.dart';

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
