import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'providers/music_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';
import 'services/preferences_service.dart';
import 'window_config_desktop.dart' if (dart.library.html) 'window_config_web.dart';

void main() async {
  // 确保 Flutter 绑定初始化
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化 SharedPreferences
  await PreferencesService().init();
  
  // 初始化主题
  final themeProvider = ThemeProvider();
  await themeProvider.loadTheme();
  
  runApp(MyApp(themeProvider: themeProvider));
  
  // 只在桌面平台配置窗口
  if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    configureWindow();
  }
}

class MyApp extends StatelessWidget {
  final ThemeProvider themeProvider;
  
  const MyApp({super.key, required this.themeProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MusicProvider()),
        ChangeNotifierProvider.value(value: themeProvider),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Hai Music',
            debugShowCheckedModeBanner: false,
            theme: themeProvider.themeData,
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
