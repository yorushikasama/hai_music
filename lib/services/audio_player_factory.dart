import '../utils/platform_utils.dart';
import 'audio_player_interface.dart';
import 'desktop_audio_player.dart';
import 'mobile_audio_player.dart';

/// 音频播放器工厂类
/// 根据平台自动选择合适的音频播放器实现
class AudioPlayerFactory {
  /// 创建适合当前平台的音频播放器
  static AudioPlayerInterface createPlayer() {
    if (PlatformUtils.isDesktop) {
      return DesktopAudioPlayer();
    } else {
      return MobileAudioPlayer();
    }
  }
}
