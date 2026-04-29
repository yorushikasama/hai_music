import 'package:audio_service/audio_service.dart';

import '../../utils/logger.dart';
import '../../utils/platform_utils.dart';
import 'audio_handler_service.dart';

/// AudioService 管理器
/// 提供全局的 AudioHandler 访问
class AudioServiceManager {
  static AudioServiceManager? _instance;
  /// 单例实例（懒初始化）
  static AudioServiceManager get instance => _instance ??= AudioServiceManager._();
  
  AudioServiceManager._();
  
  // 保存 AudioHandler 实例的引用
  MusicAudioHandler? _audioHandler;
  
  /// 设置 AudioHandler 实例
  set audioHandler(MusicAudioHandler handler) {
    _audioHandler = handler;
  }
  
  /// 获取当前的 AudioHandler
  MusicAudioHandler? get currentAudioHandler {
    if (PlatformUtils.isDesktop) return null;
    return _audioHandler;
  }
  
  /// 检查 AudioService 是否可用
  bool get isAvailable {
    return !PlatformUtils.isDesktop && _audioHandler != null;
  }
  
  /// 更新媒体项
  void updateMediaItem(MediaItem mediaItem) {
    final handler = currentAudioHandler;
    if (handler != null) {
      handler.updateCurrentMediaItem(mediaItem);
    } else {
      Logger.warning('⚠️ AudioHandler 为空，无法更新媒体项', 'AudioServiceManager');
    }
  }

  /// 释放资源并清除引用
  Future<void> dispose() async {
    await _audioHandler?.dispose();
    _audioHandler = null;
  }
}
