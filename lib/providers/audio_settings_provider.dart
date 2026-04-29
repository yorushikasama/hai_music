import 'package:flutter/foundation.dart';

import '../models/audio_quality.dart';
import '../service_locator.dart';
import '../services/playback/playback_controller_service.dart';
import '../services/core/preferences_service.dart';
import '../services/playback/song_url_service.dart';
import '../utils/logger.dart';

enum QualitySwitchResult { idle, switching, success, failed }

class AudioSettingsProvider extends ChangeNotifier {
  final PreferencesService _prefs;

  bool _showLyricsTranslation = true;
  bool _isQualitySwitching = false;
  bool _qualitySwitchPending = false;
  AudioQuality? _pendingQuality;
  QualitySwitchResult _switchResult = QualitySwitchResult.idle;
  String? _switchError;

  PlaybackControllerService? _playbackController;

  AudioQuality? _currentAudioQuality;

  AudioSettingsProvider({PreferencesService? prefs})
      : _prefs = prefs ?? locator.preferencesService {
    _showLyricsTranslation = true;
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      _showLyricsTranslation = await _prefs.getShowLyricsTranslation();
      _currentAudioQuality = await _prefs.getAudioQuality();
      notifyListeners();
    } catch (e) {
      Logger.warning('读取音频设置失败，使用默认值', 'AudioSettings');
    }
  }

  set playbackController(PlaybackControllerService controller) {
    _playbackController = controller;
  }

  AudioQuality get audioQuality => _currentAudioQuality ?? AudioQuality.high;

  String get audioQualityLabel => audioQuality.label;

  bool get showLyricsTranslation => _showLyricsTranslation;

  bool get isQualitySwitching => _isQualitySwitching;

  QualitySwitchResult get switchResult => _switchResult;

  String? get switchError => _switchError;

  Future<void> setAudioQuality(AudioQuality quality) async {
    final previousQuality = audioQuality;
    if (previousQuality == quality) return;

    Logger.info('开始切换音质: ${previousQuality.description} → ${quality.description} (代码: ${quality.value})', 'AudioSettings');

    await _prefs.setAudioQuality(quality);
    _currentAudioQuality = quality;
    _invalidateCacheOnQualityChange(previousQuality, quality);

    notifyListeners();

    if (_playbackController == null) {
      Logger.warning('PlaybackController 未设置，音质切换将延迟到下次播放时生效', 'AudioSettings');
      _switchResult = QualitySwitchResult.success;
      notifyListeners();
      _resetSwitchResultAfterDelay();
      return;
    }

    if (_playbackController!.currentPlayingSong == null) {
      Logger.info('当前无播放歌曲，音质切换将在下次播放时生效', 'AudioSettings');
      _switchResult = QualitySwitchResult.success;
      notifyListeners();
      _resetSwitchResultAfterDelay();
      return;
    }

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
    _switchResult = QualitySwitchResult.switching;
    _switchError = null;
    notifyListeners();

    bool success = false;
    try {
      await _playbackController?.reloadWithNewQuality();
      success = true;
      Logger.success('音质切换成功: ${audioQuality.description}', 'AudioSettings');
    } catch (e) {
      Logger.error('音质切换重载失败', e, null, 'AudioSettings');
      _switchError = e.toString();
    }

    _isQualitySwitching = false;
    _switchResult = success ? QualitySwitchResult.success : QualitySwitchResult.failed;

    if (_qualitySwitchPending && _pendingQuality != null) {
      final pending = _pendingQuality!;
      _qualitySwitchPending = false;
      _pendingQuality = null;

      if (audioQuality != pending) {
        await _prefs.setAudioQuality(pending);
        _currentAudioQuality = pending;
        Logger.info('执行排队的音质切换: ${pending.description}', 'AudioSettings');
        notifyListeners();
        await _executeQualitySwitch();
        return;
      }
    }

    notifyListeners();
    if (success) {
      _resetSwitchResultAfterDelay();
    }
  }

  void _resetSwitchResultAfterDelay() {
    Future.delayed(const Duration(seconds: 3), () {
      if (_disposed) return;
      if (_switchResult == QualitySwitchResult.success || _switchResult == QualitySwitchResult.failed) {
        _switchResult = QualitySwitchResult.idle;
        _switchError = null;
        notifyListeners();
      }
    });
  }

  void clearSwitchError() {
    _switchResult = QualitySwitchResult.idle;
    _switchError = null;
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

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    Logger.info('释放 AudioSettingsProvider 资源', 'AudioSettings');
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }
}
