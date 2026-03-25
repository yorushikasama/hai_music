import '../utils/platform_utils.dart';
import 'platform_audio_service.dart';
import 'mobile_audio_service.dart';
import 'playlist_manager_service.dart';
import 'song_url_service.dart';

/// 平台音频服务工厂
/// 根据平台自动选择合适的音频服务实现
class PlatformAudioServiceFactory {
  /// 创建适合当前平台的音频服务
  static PlatformAudioService createService({
    required PlaylistManagerService playlistManager,
    required SongUrlService urlService,
  }) {
    if (PlatformUtils.isDesktop) {
      return DesktopAudioService(
        playlistManager: playlistManager,
        urlService: urlService,
      );
    } else {
      return MobileAudioService(
        playlistManager: playlistManager,
        urlService: urlService,
      );
    }
  }
}
