import '../../utils/platform_utils.dart';
import 'audio_player_interface.dart';
import 'media_kit_desktop_player.dart';
import 'mobile_audio_player.dart';

class AudioPlayerFactory {
  static AudioPlayerInterface createPlayer() {
    if (PlatformUtils.isDesktop) {
      return MediaKitDesktopPlayer();
    } else {
      return MobileAudioPlayer();
    }
  }
}
