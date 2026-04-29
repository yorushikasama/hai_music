import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/app_constants.dart';
import '../../models/audio_quality.dart';
import '../../utils/logger.dart';

/// 偏好存储服务
///
/// 基于 SharedPreferences 的全局单例偏好持久化服务。
/// 管理播放模式、音质等级、搜索历史、收藏列表、会话恢复、WiFi下载限制等偏好数据。
/// 被十余个服务直接依赖，是整个应用最底层的存储基础设施。
class PreferencesService {
  static final PreferencesService _instance = PreferencesService._internal();
  SharedPreferences? _prefs;
  Completer<void>? _initCompleter;

  factory PreferencesService() => _instance;

  PreferencesService._internal();

  Future<void> init() async {
    if (_prefs != null) return;
    if (_initCompleter != null) {
      await _initCompleter!.future;
      return;
    }
    _initCompleter = Completer<void>();
    try {
      _prefs = await SharedPreferences.getInstance();
      _initCompleter!.complete();
      Logger.info('PreferencesService 初始化完成', 'PreferencesService');
    } catch (e) {
      _initCompleter!.completeError(e);
      _initCompleter = null;
      rethrow;
    }
  }

  Future<bool> emergencyClear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final result = await prefs.clear();
      _prefs = prefs;
      Logger.warning('已执行 SharedPreferences 紧急清除', 'PreferencesService');
      return result;
    } catch (e) {
      Logger.error('SharedPreferences 紧急清除失败', e, null, 'PreferencesService');
      return false;
    }
  }

  Future<void> _ensureInitialized() async {
    if (_prefs != null) return;
    await init();
    if (_prefs == null) {
      throw StateError('PreferencesService 初始化失败，无法访问 SharedPreferences');
    }
  }

  bool get isInitialized => _prefs != null;

  Future<String?> getString(String key) async {
    await _ensureInitialized();
    return _prefs!.getString(key);
  }

  Future<bool> setString(String key, String value) async {
    await _ensureInitialized();
    return _prefs!.setString(key, value);
  }

  Future<int?> getInt(String key) async {
    await _ensureInitialized();
    return _prefs!.getInt(key);
  }

  Future<bool> setInt(String key, int value) async {
    await _ensureInitialized();
    return _prefs!.setInt(key, value);
  }

  Future<List<String>?> getStringList(String key) async {
    await _ensureInitialized();
    return _prefs!.getStringList(key);
  }

  Future<bool> setStringList(String key, List<String> value) async {
    await _ensureInitialized();
    return _prefs!.setStringList(key, value);
  }

  Future<bool> remove(String key) async {
    await _ensureInitialized();
    return _prefs!.remove(key);
  }

  Future<Set<String>> getKeys() async {
    await _ensureInitialized();
    return _prefs!.getKeys();
  }

  Future<bool> setPlayMode(String mode) async {
    await _ensureInitialized();
    return _prefs!.setString('play_mode', mode);
  }

  Future<String> getPlayMode() async {
    await _ensureInitialized();
    return _prefs!.getString('play_mode') ?? 'sequence';
  }

  Future<bool> setAudioQuality(AudioQuality quality) async {
    await _ensureInitialized();
    return _prefs!.setString('audio_quality', quality.name);
  }

  Future<AudioQuality> getAudioQuality() async {
    await _ensureInitialized();
    final stored = _prefs!.getString('audio_quality');
    if (stored == null) return AudioQuality.high;
    return AudioQuality.parse(stored);
  }

  Future<bool> setShowLyricsTranslation(bool value) async {
    await _ensureInitialized();
    return _prefs!.setBool('show_lyrics_translation', value);
  }

  Future<bool> getShowLyricsTranslation() async {
    await _ensureInitialized();
    return _prefs!.getBool('show_lyrics_translation') ?? true;
  }

  Future<bool> setPlaybackSpeed(double speed) async {
    await _ensureInitialized();
    return _prefs!.setDouble('playback_speed', speed);
  }

  Future<double> getPlaybackSpeed() async {
    await _ensureInitialized();
    return _prefs!.getDouble('playback_speed') ?? 1.0;
  }

  Future<bool> addSearchHistory(String keyword) async {
    await _ensureInitialized();
    final List<String> history = _prefs!.getStringList('search_history') ?? [];
    history.remove(keyword);
    history.insert(0, keyword);
    if (history.length > AppConstants.maxSearchHistory) {
      history.removeRange(AppConstants.maxSearchHistory, history.length);
    }
    return _prefs!.setStringList('search_history', history);
  }

  Future<List<String>> getSearchHistory() async {
    await _ensureInitialized();
    return _prefs!.getStringList('search_history') ?? [];
  }

  Future<bool> clearSearchHistory() async {
    await _ensureInitialized();
    return _prefs!.remove('search_history');
  }

  Future<bool> addFavorite(String songId) async {
    await _ensureInitialized();
    final List<String> favorites = _prefs!.getStringList('favorites') ?? [];
    if (!favorites.contains(songId)) {
      favorites.add(songId);
      return _prefs!.setStringList('favorites', favorites);
    }
    return true;
  }

  Future<bool> removeFavorite(String songId) async {
    await _ensureInitialized();
    final List<String> favorites = _prefs!.getStringList('favorites') ?? [];
    favorites.remove(songId);
    return _prefs!.setStringList('favorites', favorites);
  }

  Future<List<String>> getFavorites() async {
    await _ensureInitialized();
    return _prefs!.getStringList('favorites') ?? [];
  }

  Future<bool> isFavorite(String songId) async {
    final favorites = await getFavorites();
    return favorites.contains(songId);
  }

  Future<bool> setFavoriteSongs(List<String> songIds) async {
    await _ensureInitialized();
    return _prefs!.setStringList('favorites', songIds);
  }

  Future<bool> setLastSession(String sessionJson) async {
    await _ensureInitialized();
    return _prefs!.setString('last_session', sessionJson);
  }

  Future<String> getLastSession() async {
    await _ensureInitialized();
    return _prefs!.getString('last_session') ?? '';
  }

  Future<bool> clearLastSession() async {
    await _ensureInitialized();
    return _prefs!.remove('last_session');
  }

  Future<bool> setWifiOnlyDownload(bool value) async {
    await _ensureInitialized();
    return _prefs!.setBool('wifi_only_download', value);
  }

  Future<bool> getWifiOnlyDownload() async {
    await _ensureInitialized();
    return _prefs!.getBool('wifi_only_download') ?? false;
  }

  Future<bool> setMaxConcurrentDownloads(int value) async {
    await _ensureInitialized();
    return _prefs!.setInt('max_concurrent_downloads', value);
  }

  Future<int> getMaxConcurrentDownloads() async {
    await _ensureInitialized();
    return _prefs!.getInt('max_concurrent_downloads') ?? 3;
  }

  /// 获取下载大小上限（MB），默认10240（10GB）
  Future<int> getMaxDownloadSizeMB() async {
    await _ensureInitialized();
    return _prefs!.getInt('max_download_size_mb') ?? 10240;
  }

  Future<bool> setMaxDownloadSizeMB(int valueMB) async {
    await _ensureInitialized();
    return _prefs!.setInt('max_download_size_mb', valueMB);
  }

  // ── 用户配置 ──

  /// 获取用户 QQ 号
  Future<String> getQQNumber() async {
    await _ensureInitialized();
    return _prefs!.getString('qq_number') ?? '';
  }

  /// 设置用户 QQ 号
  Future<bool> setQQNumber(String qqNumber) async {
    await _ensureInitialized();
    return _prefs!.setString('qq_number', qqNumber);
  }
}
