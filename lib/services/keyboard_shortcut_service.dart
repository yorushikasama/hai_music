import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/logger.dart';
import '../providers/music_provider.dart';

/// 键盘快捷键服务
/// 提供全局快捷键支持,无需自定义配置
class KeyboardShortcutService {
  static const bool _enableDebugLog = true;

  /// 统一的日志输出
  static void _log(String message) {
    if (_enableDebugLog) {
      print(message);
    }
  }

  /// 处理键盘事件
  /// 返回 KeyEventResult.handled 表示事件已处理
  /// 返回 KeyEventResult.ignored 表示事件未处理,继续传递
  ///
  /// [onSearchRequested] 当用户按下 Ctrl+F 时调用,用于切换到搜索页面
  static KeyEventResult handleKeyEvent(
    KeyEvent event,
    MusicProvider musicProvider,
    BuildContext context, {
    VoidCallback? onSearchRequested,
  }) {
    // 只处理按键按下事件,忽略释放事件
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    // 检查是否在输入框中
    final focusNode = FocusScope.of(context).focusedChild;
    if (focusNode != null && focusNode.context != null) {
      // 检查当前焦点的 widget
      final widget = focusNode.context!.widget;
      if (widget is TextField || widget is TextFormField || widget is EditableText) {
        return KeyEventResult.ignored;
      }
      
      // 检查焦点所在的 Element 是否包含 EditableText
      // 这能捕获 TextField 内部的焦点情况
      if (focusNode.context is Element) {
        final element = focusNode.context as Element;
        // 查找祖先节点中是否有 TextField 或 TextFormField
        final hasTextFieldAncestor = element.findAncestorWidgetOfExactType<TextField>() != null ||
                                      element.findAncestorWidgetOfExactType<TextFormField>() != null;
        if (hasTextFieldAncestor) {
          return KeyEventResult.ignored;
        }
      }
    }

    final isCtrlPressed = HardwareKeyboard.instance.isControlPressed;
    final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
    final isAltPressed = HardwareKeyboard.instance.isAltPressed;

    // 获取按键
    final key = event.logicalKey;

    Logger.debug('快捷键: ${event.logicalKey.keyLabel}', 'KeyboardShortcut');

    // ==================== 播放控制 ====================
    
    // Space: 播放/暂停
    if (key == LogicalKeyboardKey.space && !isCtrlPressed && !isShiftPressed && !isAltPressed) {
      _log('⌨️ [快捷键] Space - 播放/暂停');
      musicProvider.togglePlayPause();
      return KeyEventResult.handled;
    }

    // 左箭头: 上一首
    if (key == LogicalKeyboardKey.arrowLeft && !isCtrlPressed && !isShiftPressed && !isAltPressed) {
      _log('⌨️ [快捷键] ← - 上一首');
      musicProvider.playPrevious();
      return KeyEventResult.handled;
    }

    // 右箭头: 下一首
    if (key == LogicalKeyboardKey.arrowRight && !isCtrlPressed && !isShiftPressed && !isAltPressed) {
      _log('⌨️ [快捷键] → - 下一首');
      musicProvider.playNext();
      return KeyEventResult.handled;
    }

    // ==================== 音量控制 ====================
    
    // 上箭头: 增加音量
    if (key == LogicalKeyboardKey.arrowUp && !isCtrlPressed && !isShiftPressed && !isAltPressed) {
      final newVolume = (musicProvider.volume + 0.1).clamp(0.0, 1.0);
      _log('⌨️ [快捷键] ↑ - 增加音量: ${(newVolume * 100).toInt()}%');
      musicProvider.setVolume(newVolume);
      return KeyEventResult.handled;
    }

    // 下箭头: 降低音量
    if (key == LogicalKeyboardKey.arrowDown && !isCtrlPressed && !isShiftPressed && !isAltPressed) {
      final newVolume = (musicProvider.volume - 0.1).clamp(0.0, 1.0);
      _log('⌨️ [快捷键] ↓ - 降低音量: ${(newVolume * 100).toInt()}%');
      musicProvider.setVolume(newVolume);
      return KeyEventResult.handled;
    }

    // ==================== 收藏功能 ====================
    
    // Ctrl+D: 收藏当前歌曲
    if (key == LogicalKeyboardKey.keyD && isCtrlPressed && !isShiftPressed && !isAltPressed) {
      if (musicProvider.currentSong != null) {
        _log('⌨️ [快捷键] Ctrl+D - 收藏/取消收藏');
        musicProvider.toggleFavorite(musicProvider.currentSong!.id);
      }
      return KeyEventResult.handled;
    }

    // ==================== 搜索功能 ====================

    // Ctrl+F: 聚焦搜索框
    if (key == LogicalKeyboardKey.keyF && isCtrlPressed && !isShiftPressed && !isAltPressed) {
      _log('⌨️ [快捷键] Ctrl+F - 搜索');
      onSearchRequested?.call();
      return KeyEventResult.handled;
    }

    // ==================== 进度控制 ====================
    
    // Shift+左箭头: 后退10秒
    if (key == LogicalKeyboardKey.arrowLeft && !isCtrlPressed && isShiftPressed && !isAltPressed) {
      final newPosition = musicProvider.currentPosition - const Duration(seconds: 10);
      if (newPosition.inSeconds >= 0) {
        _log('⌨️ [快捷键] Shift+← - 后退10秒');
        musicProvider.seek(newPosition);
      }
      return KeyEventResult.handled;
    }

    // Shift+右箭头: 前进10秒
    if (key == LogicalKeyboardKey.arrowRight && !isCtrlPressed && isShiftPressed && !isAltPressed) {
      final newPosition = musicProvider.currentPosition + const Duration(seconds: 10);
      if (newPosition <= musicProvider.totalDuration) {
        _log('⌨️ [快捷键] Shift+→ - 前进10秒');
        musicProvider.seek(newPosition);
      }
      return KeyEventResult.handled;
    }

    // 未匹配任何快捷键
    return KeyEventResult.ignored;
  }

  /// 获取快捷键帮助信息
  static List<ShortcutInfo> getShortcutList() {
    return [
      // 播放控制
      ShortcutInfo(
        category: '播放控制',
        shortcuts: [
          ShortcutItem('Space', '播放/暂停'),
          ShortcutItem('←', '上一首'),
          ShortcutItem('→', '下一首'),
          ShortcutItem('Shift+←', '后退10秒'),
          ShortcutItem('Shift+→', '前进10秒'),
        ],
      ),
      // 音量控制
      ShortcutInfo(
        category: '音量控制',
        shortcuts: [
          ShortcutItem('↑', '增加音量'),
          ShortcutItem('↓', '降低音量'),
        ],
      ),
      // 功能操作
      ShortcutInfo(
        category: '功能操作',
        shortcuts: [
          ShortcutItem('Ctrl+D', '收藏/取消收藏'),
          ShortcutItem('Ctrl+F', '搜索'),
        ],
      ),
    ];
  }

  /// 显示快捷键帮助对话框
  static void showShortcutHelp(BuildContext context) {
    final shortcuts = getShortcutList();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.keyboard, size: 24),
            SizedBox(width: 12),
            Text('快捷键帮助'),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: shortcuts.map((info) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Text(
                      info.category,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...info.shortcuts.map((item) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.grey.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                item.key,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(item.description),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}

/// 快捷键分类信息
class ShortcutInfo {
  final String category;
  final List<ShortcutItem> shortcuts;

  ShortcutInfo({
    required this.category,
    required this.shortcuts,
  });
}

/// 快捷键项
class ShortcutItem {
  final String key;
  final String description;

  ShortcutItem(this.key, this.description);
}

