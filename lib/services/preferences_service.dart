import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences 服务类
/// 用于保存和读取用户设置、播放历史等
class PreferencesService {
  static final PreferencesService _instance = PreferencesService._internal();
  late SharedPreferences _prefs;
  bool _initialized = false;

  factory PreferencesService() => _instance;

  PreferencesService._internal();

  /// 初始化 SharedPreferences
  Future<void> init() async {
    if (!_initialized) {
      _prefs = await SharedPreferences.getInstance();
      _initialized = true;
    }
  }

  // ==================== 音量设置 ====================
  
  /// 保存音量
  Future<bool> setVolume(double volume) async {
    return await _prefs.setDouble('volume', volume);
  }

  /// 获取音量
  double getVolume() {
    return _prefs.getDouble('volume') ?? 1.0;
  }

  // ==================== 播放模式 ====================
  
  /// 保存播放模式
  Future<bool> setPlayMode(String mode) async {
    return await _prefs.setString('play_mode', mode);
  }

  /// 获取播放模式
  String getPlayMode() {
    return _prefs.getString('play_mode') ?? 'sequence';
  }

  // ==================== 音质设置 ====================
  
  /// 保存音质
  Future<bool> setAudioQuality(String quality) async {
    return await _prefs.setString('audio_quality', quality);
  }

  /// 获取音质
  String getAudioQuality() {
    return _prefs.getString('audio_quality') ?? 'high';
  }

  // ==================== 主题设置 ====================
  
  /// 保存主题模式
  Future<bool> setThemeMode(String mode) async {
    return await _prefs.setString('theme_mode', mode);
  }

  /// 获取主题模式
  String getThemeMode() {
    return _prefs.getString('theme_mode') ?? 'system';
  }

  // ==================== 搜索历史 ====================
  
  /// 保存搜索历史
  Future<bool> addSearchHistory(String keyword) async {
    List<String> history = getSearchHistory();
    // 如果已存在，先移除
    history.remove(keyword);
    // 添加到最前面
    history.insert(0, keyword);
    // 最多保存20条
    if (history.length > 20) {
      history = history.sublist(0, 20);
    }
    return await _prefs.setStringList('search_history', history);
  }

  /// 获取搜索历史
  List<String> getSearchHistory() {
    return _prefs.getStringList('search_history') ?? [];
  }

  /// 清除搜索历史
  Future<bool> clearSearchHistory() async {
    return await _prefs.remove('search_history');
  }

  // ==================== 播放历史 ====================
  
  /// 保存最近播放的歌曲ID列表
  Future<bool> addPlayHistory(String songId) async {
    List<String> history = getPlayHistory();
    history.remove(songId);
    history.insert(0, songId);
    if (history.length > 50) {
      history = history.sublist(0, 50);
    }
    return await _prefs.setStringList('play_history', history);
  }

  /// 获取播放历史
  List<String> getPlayHistory() {
    return _prefs.getStringList('play_history') ?? [];
  }

  // ==================== 收藏歌曲 ====================
  
  /// 添加收藏
  Future<bool> addFavorite(String songId) async {
    List<String> favorites = getFavorites();
    if (!favorites.contains(songId)) {
      favorites.add(songId);
      return await _prefs.setStringList('favorites', favorites);
    }
    return true;
  }

  /// 移除收藏
  Future<bool> removeFavorite(String songId) async {
    List<String> favorites = getFavorites();
    favorites.remove(songId);
    return await _prefs.setStringList('favorites', favorites);
  }

  /// 获取收藏列表
  List<String> getFavorites() {
    return _prefs.getStringList('favorites') ?? [];
  }

  /// 检查是否已收藏
  bool isFavorite(String songId) {
    return getFavorites().contains(songId);
  }

  /// 批量设置收藏列表
  Future<bool> setFavoriteSongs(List<String> songIds) async {
    return await _prefs.setStringList('favorites', songIds);
  }

  /// 获取收藏歌曲列表（别名方法）
  List<String> getFavoriteSongs() {
    return getFavorites();
  }

  // ==================== 清除所有数据 ====================
  
  /// 清除所有数据
  Future<bool> clearAll() async {
    return await _prefs.clear();
  }
}
