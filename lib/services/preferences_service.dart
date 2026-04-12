import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_constants.dart';
import '../models/audio_quality.dart';
import '../utils/logger.dart';

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
  }

  SharedPreferences get _safePrefs {
    if (_prefs == null) {
      throw StateError('PreferencesService 未初始化，请先调用 init()');
    }
    return _prefs!;
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

  Future<bool> containsKey(String key) async {
    await _ensureInitialized();
    return _prefs!.containsKey(key);
  }

  Future<bool> clear() async {
    await _ensureInitialized();
    return _prefs!.clear();
  }

  Future<Set<String>> getKeys() async {
    await _ensureInitialized();
    return _prefs!.getKeys();
  }

  Future<void> reload() async {
    await _ensureInitialized();
    await _prefs!.reload();
  }

  Future<bool> setVolume(double volume) {
    return _safePrefs.setDouble('volume', volume);
  }

  double getVolume() {
    if (_prefs == null) return 1.0;
    return _prefs!.getDouble('volume') ?? 1.0;
  }

  Future<bool> setPlayMode(String mode) {
    return _safePrefs.setString('play_mode', mode);
  }

  String getPlayMode() {
    if (_prefs == null) return 'sequence';
    return _prefs!.getString('play_mode') ?? 'sequence';
  }

  Future<bool> setAudioQuality(AudioQuality quality) {
    return _safePrefs.setString('audio_quality', quality.name);
  }

  AudioQuality getAudioQuality() {
    if (_prefs == null) return AudioQuality.high;
    final stored = _prefs!.getString('audio_quality');
    if (stored == null) return AudioQuality.high;
    return AudioQuality.parse(stored);
  }

  Future<bool> setShowLyricsTranslation(bool value) {
    return _safePrefs.setBool('show_lyrics_translation', value);
  }

  bool getShowLyricsTranslation() {
    if (_prefs == null) return true;
    return _prefs!.getBool('show_lyrics_translation') ?? true;
  }

  Future<bool> setPlaybackSpeed(double speed) {
    return _safePrefs.setDouble('playback_speed', speed);
  }

  double getPlaybackSpeed() {
    if (_prefs == null) return 1.0;
    return _prefs!.getDouble('playback_speed') ?? 1.0;
  }

  Future<bool> addSearchHistory(String keyword) async {
    final List<String> history = getSearchHistory();
    history.remove(keyword);
    history.insert(0, keyword);
    if (history.length > AppConstants.maxSearchHistory) {
      history.removeRange(AppConstants.maxSearchHistory, history.length);
    }
    return _safePrefs.setStringList('search_history', history);
  }

  List<String> getSearchHistory() {
    if (_prefs == null) return [];
    return _prefs!.getStringList('search_history') ?? [];
  }

  Future<bool> clearSearchHistory() {
    return _safePrefs.remove('search_history');
  }

  Future<bool> addFavorite(String songId) async {
    final List<String> favorites = getFavorites();
    if (!favorites.contains(songId)) {
      favorites.add(songId);
      return _safePrefs.setStringList('favorites', favorites);
    }
    return Future.value(true);
  }

  Future<bool> removeFavorite(String songId) async {
    final List<String> favorites = getFavorites();
    favorites.remove(songId);
    return _safePrefs.setStringList('favorites', favorites);
  }

  List<String> getFavorites() {
    if (_prefs == null) return [];
    return _prefs!.getStringList('favorites') ?? [];
  }

  bool isFavorite(String songId) {
    return getFavorites().contains(songId);
  }

  Future<bool> setFavoriteSongs(List<String> songIds) {
    return _safePrefs.setStringList('favorites', songIds);
  }

  List<String> getFavoriteSongs() {
    return getFavorites();
  }

  Future<bool> setLastSession(String sessionJson) {
    return _safePrefs.setString('last_session', sessionJson);
  }

  String getLastSession() {
    return _safePrefs.getString('last_session') ?? '';
  }

  Future<bool> clearLastSession() {
    return _safePrefs.remove('last_session');
  }
}
