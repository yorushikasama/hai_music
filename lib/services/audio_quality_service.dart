import '../models/audio_quality.dart';
import '../utils/logger.dart';
import 'preferences_service.dart';

class AudioQualityService {
  static final AudioQualityService _instance = AudioQualityService._internal();
  factory AudioQualityService() => _instance;
  AudioQualityService._internal() {
    Logger.info('音质管理服务初始化', 'AudioQualityService');
  }

  static AudioQualityService get instance => _instance;

  static const AudioQuality _defaultQuality = AudioQuality.high;

  AudioQuality getCurrentQuality() {
    final prefs = PreferencesService();
    final quality = prefs.getAudioQuality();
    Logger.debug('当前音质设置: ${quality.description} (代码: ${quality.value})', 'AudioQualityService');
    return quality;
  }

  int getCurrentQualityCode() {
    final quality = getCurrentQuality();
    Logger.debug('当前音质代码: ${quality.value}', 'AudioQualityService');
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
    Logger.debug('使用默认音质代码: $code (${_defaultQuality.description})', 'AudioQualityService');
    return code;
  }

  AudioQuality getDefaultQuality() {
    return _defaultQuality;
  }
}
