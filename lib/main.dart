import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audio_service/audio_service.dart';
import 'providers/music_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';
import 'services/preferences_service.dart';
import 'services/audio_handler_service.dart';
import 'services/audio_service_manager.dart';
import 'utils/platform_utils.dart';
import 'window_config.dart';

void main() async {
  // 确保 Flutter 绑定初始化
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化 SharedPreferences
  await PreferencesService().init();
  
  // 初始化 AudioService (仅在移动端)
  if (!PlatformUtils.isDesktop) {
    print('🎵 [Main] 开始初始化 AudioService...');
    final audioHandler = MusicAudioHandler();
    
    try {
      await AudioService.init(
        builder: () => audioHandler,
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.example.hai_music.channel.audio',
          androidNotificationChannelName: 'Hai Music',
          androidNotificationOngoing: false, // 与 androidStopForegroundOnPause: false 兼容
          androidShowNotificationBadge: true,
          androidNotificationChannelDescription: 'Hai Music 音频播放控制',
          androidNotificationIcon: 'drawable/ic_notification',
          androidStopForegroundOnPause: false, // 保持前台服务运行
        ),
      );
      
      // 等待 AudioHandler 完全初始化
      print('🎵 [Main] 等待 AudioHandler 完全初始化...');
      await audioHandler.ready;
      
      // 将 AudioHandler 实例保存到管理器中
      AudioServiceManager.instance.setAudioHandler(audioHandler);
      print('✅ [Main] AudioService 初始化成功');
    } catch (e, stackTrace) {
      print('❌ [Main] AudioService 初始化失败: $e');
      print('❌ [Main] 堆栈跟踪: $stackTrace');
    }
  } else {
    print('🖥️ [Main] 桌面端，跳过 AudioService 初始化');
  }
  
  // 初始化主题
  final themeProvider = ThemeProvider();
  await themeProvider.loadTheme();

  // 初始化音乐提供者
  final musicProvider = MusicProvider();

  runApp(MyApp(
    themeProvider: themeProvider,
    musicProvider: musicProvider,
  ));

  // 只在桌面平台配置窗口
  if (PlatformUtils.isDesktop) {
    configureWindow();
  }
}

class MyApp extends StatelessWidget {
  final ThemeProvider themeProvider;
  final MusicProvider musicProvider;

  const MyApp({super.key, required this.themeProvider, required this.musicProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: musicProvider),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Hai Music',
            debugShowCheckedModeBanner: false,
            theme: themeProvider.themeData,
            home: const HomeScreen(),
            scrollBehavior: const MaterialScrollBehavior().copyWith(
              dragDevices: {
                PointerDeviceKind.mouse,
                PointerDeviceKind.touch,
                PointerDeviceKind.stylus,
                PointerDeviceKind.trackpad,
              },
            ),
          );
        },
      ),
    );
  }
}
