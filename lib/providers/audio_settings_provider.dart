import 'package:flutter/foundation.dart';

import '../models/audio_quality.dart';
import '../service_locator.dart';
import '../services/playback_controller_service.dart';
import '../services/preferences_service.dart';
import '../services/song_url_service.dart';
import '../utils/logger.dart';

class AudioSettingsProvider extends ChangeNotifier {
  final PreferencesService _prefs;

  bool _showLyricsTranslation = true;
  bool _isQualitySwitching = false;
  bool _qualitySwitchPending = false;
  AudioQuality? _pendingQuality;

  PlaybackControllerService? _playbackController;

  AudioSettingsProvider({PreferencesService? prefs})
      : _prefs = prefs ?? locator.preferencesService {
    try {
      _showLyricsTranslation = _prefs.getShowLyricsTranslation();
    } catch (e) {
      Logger.warning('读取歌词翻译偏好失败，使用默认值', 'AudioSettings');
      _showLyricsTranslation = true;
    }
  }

  set playbackController(PlaybackControllerService controller) {
    _playbackController = controller;
  }

  AudioQuality get audioQuality => _prefs.getAudioQuality();

  String get audioQualityLabel => audioQuality.label;

  bool get showLyricsTranslation => _showLyricsTranslation;

  bool get isQualitySwitching => _isQualitySwitching;

  Future<void> setAudioQuality(AudioQuality quality) async {
    final previousQuality = audioQuality;
    if (previousQuality == quality) return;

    await _prefs.setAudioQuality(quality);
    Logger.info('设置音质: ${quality.description} (代码: ${quality.value})', 'AudioSettings');

    _invalidateCacheOnQualityChange(previousQuality, quality);

    notifyListeners();

    if (_playbackController == null) {
      Logger.warning('PlaybackController 未设置，音质切换将延迟到下次播放时生效', 'AudioSettings');
      return;
    }

    if (_playbackController!.currentPlayingSong == null) return;

    if (_isQualitySwitching) {
      _pendingQuality = quality;
      _qualitySwitchPending = true;
      Logger.info('音质切换进行中，排队等待: ${quality.description}', 'AudioSettings');
      return;
    }

    await _executeQualitySwitch();
  }

  void _invalidateCacheOnQualityChange(AudioQuality previousQuality, AudioQuality newQuality) {
    if (previousQuality.fileExtension != newQuality.fileExtension) {
      Logger.info('音质文件格式变化 (${previousQuality.fileExtension} → ${newQuality.fileExtension})，清除 URL 缓存', 'AudioSettings');
      SongUrlService().invalidateAllCache();
    } else {
      Logger.info('音质文件格式未变，保留 URL 缓存', 'AudioSettings');
    }
  }

  Future<void> _executeQualitySwitch() async {
    _isQualitySwitching = true;
    notifyListeners();

    try {
      await _playbackController?.reloadWithNewQuality();
    } catch (e) {
      Logger.error('音质切换重载失败', e, null, 'AudioSettings');
    }

    _isQualitySwitching = false;

    if (_qualitySwitchPending && _pendingQuality != null) {
      final pending = _pendingQuality!;
      _qualitySwitchPending = false;
      _pendingQuality = null;

      if (audioQuality != pending) {
        await _prefs.setAudioQuality(pending);
        Logger.info('执行排队的音质切换: ${pending.description}', 'AudioSettings');
        notifyListeners();
        await _executeQualitySwitch();
        return;
      }
    }

    notifyListeners();
  }

  Future<void> setShowLyricsTranslation(bool value) async {
    _showLyricsTranslation = value;
    try {
      await _prefs.setShowLyricsTranslation(value);
    } catch (e) {
      Logger.warning('保存歌词翻译偏好失败', 'AudioSettings');
    }
    notifyListeners();
  }

  @override
  void dispose() {
    Logger.info('释放 AudioSettingsProvider 资源', 'AudioSettings');
    super.dispose();
  }
}
