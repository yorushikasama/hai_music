import 'package:audio_service/audio_service.dart';
import '../utils/platform_utils.dart';
import '../utils/logger.dart';
import 'audio_handler_service.dart';

/// AudioService 管理器
/// 提供全局的 AudioHandler 访问
class AudioServiceManager {
  static AudioServiceManager? _instance;
  static AudioServiceManager get instance => _instance ??= AudioServiceManager._();
  
  AudioServiceManager._();
  
  // 保存 AudioHandler 实例的引用
  MusicAudioHandler? _audioHandler;
  
  /// 设置 AudioHandler 实例
  void setAudioHandler(MusicAudioHandler handler) {
    _audioHandler = handler;
  }
  
  /// 获取当前的 AudioHandler
  MusicAudioHandler? get audioHandler {
    if (PlatformUtils.isDesktop) return null;
    return _audioHandler;
  }
  
  /// 检查 AudioService 是否可用
  bool get isAvailable {
    return !PlatformUtils.isDesktop && _audioHandler != null;
  }
  
  /// 更新媒体项
  void updateMediaItem(MediaItem mediaItem) {
    final handler = audioHandler;
    if (handler != null) {
      Logger.debug('🎵 通过 AudioHandler 更新媒体项: ${mediaItem.title}', 'AudioServiceManager');
      handler.updateCurrentMediaItem(mediaItem);
    } else {
      Logger.warning('⚠️ AudioHandler 为空，无法更新媒体项', 'AudioServiceManager');
    }
  }
}
