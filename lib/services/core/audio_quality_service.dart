import '../../models/audio_quality.dart';
import '../../utils/logger.dart';
import 'preferences_service.dart';

/// 音质管理服务
///
/// 管理当前音质等级的全局单例服务，默认 HQ(320kbps)。
/// 被下载/缓存/播放/收藏等多条业务链路依赖，
/// 音质变更会触发播放URL重新获取和缓存策略调整。
class AudioQualityService {
  static final AudioQualityService _instance = AudioQualityService._internal();
  factory AudioQualityService() => _instance;
  AudioQualityService._internal() {
    Logger.info('音质管理服务初始化', 'AudioQualityService');
  }

  static AudioQualityService get instance => _instance;

  static const AudioQuality _defaultQuality = AudioQuality.high;

  Future<AudioQuality> getCurrentQuality() async {
    final prefs = PreferencesService();
    final quality = await prefs.getAudioQuality();
    return quality;
  }

  Future<int> getCurrentQualityCode() async {
    final quality = await getCurrentQuality();
    return quality.value;
  }

  Future<void> setQuality(AudioQuality quality) async {
    final prefs = PreferencesService();
    await prefs.setAudioQuality(quality);
    Logger.info(
      '音质已切换: ${quality.description} (代码: ${quality.value})',
      'AudioQualityService',
    );
  }

  int getDefaultQualityCode() {
    final code = _defaultQuality.value;
    return code;
  }

  AudioQuality getDefaultQuality() {
    return _defaultQuality;
  }
}
