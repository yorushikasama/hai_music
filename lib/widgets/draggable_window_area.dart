import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart' if (dart.library.html) '';
import '../utils/platform_utils.dart';

/// 可拖动窗口区域组件
/// 在桌面平台上允许用户通过拖动该区域来移动窗口
/// 在非桌面平台上仅显示子组件,不添加拖动功能
class DraggableWindowArea extends StatelessWidget {
  /// 子组件
  final Widget child;

  /// 区域高度 (可选)
  final double? height;

  /// 区域宽度 (可选)
  final double? width;

  /// 背景颜色 (可选)
  final Color? color;

  const DraggableWindowArea({
    super.key,
    required this.child,
    this.height,
    this.width,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    // 非桌面平台直接返回子组件
    if (!PlatformUtils.supportsWindowDragging) {
      return child;
    }

    // 桌面平台添加拖动功能
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) {
        try {
          appWindow.startDragging();
        } catch (e) {
          // 忽略错误 (Web 平台或其他不支持的情况)
        }
      },
      child: Container(
        height: height,
        width: width,
        color: color ?? Colors.transparent,
        child: child,
      ),
    );
  }
}

/// 简化版拖动区域 - 仅用于占位
/// 常用于顶部标题栏区域
class DraggableWindowBar extends StatelessWidget {
  /// 高度,默认 40
  final double height;

  /// 背景颜色
  final Color? color;

  const DraggableWindowBar({
    super.key,
    this.height = 40,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableWindowArea(
      height: height,
      color: color ?? Colors.transparent,
      child: const SizedBox.expand(),
    );
  }
}

