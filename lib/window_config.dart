import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';

Future<void> configureWindow() async {
  await Window.initialize();
  
  // 设置窗口透明效果
  await Window.setEffect(
    effect: WindowEffect.transparent,
  );
  
  doWhenWindowReady(() {
    const initialSize = Size(1280, 800);
    const minSize = Size(900, 600);
    appWindow.minSize = minSize;
    appWindow.size = initialSize;
    appWindow.alignment = Alignment.center;
    appWindow.title = 'Hai Music';
    appWindow.show();
  });
}
