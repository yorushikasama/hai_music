import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';

import 'providers/audio_settings_provider.dart';
import 'providers/favorite_provider.dart';
import 'providers/music_provider.dart';
import 'providers/sleep_timer_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';
import 'service_locator.dart';
import 'services/playback/audio_handler_service.dart';
import 'services/playback/audio_service_manager.dart';
import 'services/download/download_service.dart';
import 'services/storage/cover_persistence_service.dart';
import 'services/lyrics/lyrics_cache_service.dart';
import 'services/core/media_scan_service.dart';
import 'services/core/preferences_service.dart';
import 'services/playback/song_url_service.dart';
import 'services/core/storage_path_manager.dart';
import 'utils/logger.dart';
import 'utils/platform_utils.dart';
import 'window_config.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (details) {
      Logger.error('Flutter 框架错误', details.exception, details.stack, 'Main');
    };

    try {
      await PreferencesService().init();
    } catch (e, stackTrace) {
      Logger.error('PreferencesService 初始化失败，尝试清除数据恢复', e, stackTrace, 'Main');
      try {
        await PreferencesService().emergencyClear();
        Logger.info('已清除 SharedPreferences 数据，重试初始化', 'Main');
        await PreferencesService().init();
      } catch (e2, st2) {
        Logger.error('PreferencesService 重试初始化仍失败', e2, st2, 'Main');
      }
    }

    try {
      await setupServiceLocator();
    } catch (e, stackTrace) {
      Logger.error('ServiceLocator 初始化失败，无法继续启动', e, stackTrace, 'Main');
      return;
    }

    final themeProvider = ThemeProvider();
    try {
      await themeProvider.loadTheme();
    } catch (e, stackTrace) {
      Logger.error('ThemeProvider 初始化失败', e, stackTrace, 'Main');
    }

    await _initAudioService();

    MusicProvider musicProvider;
    try {
      musicProvider = MusicProvider();
    } catch (e, stackTrace) {
      Logger.error('MusicProvider 初始化失败', e, stackTrace, 'Main');
      musicProvider = MusicProvider();
    }

    FavoriteProvider favoriteProvider;
    try {
      favoriteProvider = FavoriteProvider();
    } catch (e, stackTrace) {
      Logger.error('FavoriteProvider 初始化失败', e, stackTrace, 'Main');
      favoriteProvider = FavoriteProvider();
    }

    final audioSettingsProvider = AudioSettingsProvider();
    final sleepTimerProvider = SleepTimerProvider(
      onPausePlayback: musicProvider.forcePause,
    );

    audioSettingsProvider.playbackController = musicProvider.playbackController;

    runApp(MyApp(
      themeProvider: themeProvider,
      musicProvider: musicProvider,
      favoriteProvider: favoriteProvider,
      audioSettingsProvider: audioSettingsProvider,
      sleepTimerProvider: sleepTimerProvider,
    ));

    unawaited(_runStartupCleanup());

    if (PlatformUtils.isDesktop) {
      unawaited(configureWindow());
    }
  }, (error, stackTrace) {
    Logger.error('未捕获的异步异常', error, stackTrace, 'Main');
  });
}

/// 初始化 AudioService，必须在 MusicProvider 之前调用
Future<void> _initAudioService() async {
  if (PlatformUtils.isDesktop) {
    Logger.info('桌面端，跳过 AudioService 初始化', 'Main');
    return;
  }

  Logger.info('开始初始化 AudioService...', 'Main');
  MusicAudioHandler? audioHandler;

  try {
    audioHandler = MusicAudioHandler();
  } catch (e, stackTrace) {
    Logger.error('MusicAudioHandler 创建失败', e, stackTrace, 'Main');
    return;
  }

  try {
    final handler = audioHandler;
    await AudioService.init(
      builder: () => handler,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.hai.music.channel.audio',
        androidNotificationChannelName: 'Hai Music',
        androidShowNotificationBadge: true,
        androidNotificationChannelDescription: 'Hai Music 音频播放控制',
        androidNotificationIcon: 'drawable/ic_notification',
        androidStopForegroundOnPause: false,
      ),
    );

    Logger.info('等待 AudioHandler 完全初始化...', 'Main');
    await audioHandler.ready.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        Logger.warning('AudioHandler 初始化超时，继续启动应用', 'Main');
      },
    );

    AudioServiceManager.instance.audioHandler = audioHandler;
    Logger.success('AudioService 初始化成功', 'Main');
  } catch (e, stackTrace) {
    Logger.error('AudioService 初始化失败', e, stackTrace, 'Main');
  }
}

/// 执行启动清理任务（歌词缓存迁移、URL缓存清理等）
Future<void> _runStartupCleanup() async {
  try {
    await LyricsCacheService().migrateFromSharedPreferences();
    unawaited(LyricsCacheService().cleanExpired());
    final songUrlService = SongUrlService();
    unawaited(songUrlService.cleanExpiredCache());
    unawaited(_migrateAndroidDownloads());
    unawaited(_initCoverPersistence());
    unawaited(_requestManageStoragePermissionIfNeeded());
  } catch (e) {
    Logger.error('启动清理任务失败', e, null, 'Main');
  }
}

/// 初始化封面持久化服务并重建索引
Future<void> _initCoverPersistence() async {
  try {
    final coverService = CoverPersistenceService();
    await coverService.init();
    await coverService.rebuildIndex();
    Logger.success('封面持久化服务启动完成', 'Main');
  } catch (e) {
    Logger.error('封面持久化服务初始化失败', e, null, 'Main');
  }
}

/// 迁移 Android 旧版下载目录、封面、歌词缓存到新路径
Future<void> _migrateAndroidDownloads() async {
  if (!PlatformUtils.isAndroid) return;
  try {
    final pathManager = StoragePathManager();
    await pathManager.init();
    final result = await pathManager.migrateDownloadsIfNeeded();
    if (result > 0) {
      final oldDir = await pathManager.getLegacyDownloadsDir();
      final newDir = await pathManager.getDownloadsDir();
      if (oldDir != null) {
        await DownloadService().migratePathsIfNeeded(oldDir.path, newDir.path);
      }
    }
    await pathManager.migrateCoversIfNeeded();
    await pathManager.migrateLyricsCacheIfNeeded();
  } catch (e) {
    Logger.error('Android 下载目录迁移失败', e, null, 'Main');
  }
}

/// 请求 Android 管理存储权限（Android 11+ 所需）
Future<void> _requestManageStoragePermissionIfNeeded() async {
  if (!PlatformUtils.isAndroid) return;
  try {
    final mediaScan = MediaScanService();
    final hasPermission = await mediaScan.checkManageStoragePermission();
    if (!hasPermission) {
      Logger.info('未拥有管理存储权限，请求授权...', 'Main');
      await mediaScan.requestManageStoragePermission();
    } else {
      Logger.info('已拥有管理存储权限', 'Main');
    }
  } catch (e) {
    Logger.warning('请求管理存储权限失败: $e', 'Main');
  }
}

class MyApp extends StatelessWidget {
  final ThemeProvider themeProvider;
  final MusicProvider musicProvider;
  final FavoriteProvider favoriteProvider;
  final AudioSettingsProvider audioSettingsProvider;
  final SleepTimerProvider sleepTimerProvider;

  const MyApp({
    required this.themeProvider,
    required this.musicProvider,
    required this.favoriteProvider,
    required this.audioSettingsProvider,
    required this.sleepTimerProvider,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: musicProvider),
        ChangeNotifierProvider.value(value: favoriteProvider),
        ChangeNotifierProvider.value(value: audioSettingsProvider),
        ChangeNotifierProvider.value(value: sleepTimerProvider),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return ToastificationWrapper(
            child: MaterialApp(
              title: 'Hai Music',
              debugShowCheckedModeBanner: false,
              theme: themeProvider.themeData,
              themeAnimationDuration: const Duration(milliseconds: 400),
              themeAnimationCurve: Curves.easeInOutCubic,
              home: const HomeScreen(),
              scrollBehavior: const MaterialScrollBehavior().copyWith(
                dragDevices: {
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.touch,
                  PointerDeviceKind.stylus,
                  PointerDeviceKind.trackpad,
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
