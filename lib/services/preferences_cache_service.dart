import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences 缓存服务 (单例模式)
/// 避免重复获取 SharedPreferences 实例,提升性能
class PreferencesCacheService {
  static final PreferencesCacheService _instance = PreferencesCacheService._internal();
  
  factory PreferencesCacheService() => _instance;
  
  PreferencesCacheService._internal();

  SharedPreferences? _prefs;
  bool _initialized = false;

  /// 初始化服务
  Future<void> init() async {
    if (_initialized) return;
    
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
    print('✅ [PreferencesCache] 初始化完成');
  }

  /// 确保已初始化
  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await init();
    }
  }

  /// 获取 SharedPreferences 实例
  Future<SharedPreferences> get instance async {
    await _ensureInitialized();
    return _prefs!;
  }

  /// 同步获取实例 (仅在确保已初始化后使用)
  SharedPreferences? get instanceSync => _prefs;

  /// 是否已初始化
  bool get isInitialized => _initialized;

  // ========== 便捷方法 ==========

  /// 获取字符串
  Future<String?> getString(String key) async {
    await _ensureInitialized();
    return _prefs!.getString(key);
  }

  /// 设置字符串
  Future<bool> setString(String key, String value) async {
    await _ensureInitialized();
    return _prefs!.setString(key, value);
  }

  /// 获取整数
  Future<int?> getInt(String key) async {
    await _ensureInitialized();
    return _prefs!.getInt(key);
  }

  /// 设置整数
  Future<bool> setInt(String key, int value) async {
    await _ensureInitialized();
    return _prefs!.setInt(key, value);
  }

  /// 获取布尔值
  Future<bool?> getBool(String key) async {
    await _ensureInitialized();
    return _prefs!.getBool(key);
  }

  /// 设置布尔值
  Future<bool> setBool(String key, bool value) async {
    await _ensureInitialized();
    return _prefs!.setBool(key, value);
  }

  /// 获取字符串列表
  Future<List<String>?> getStringList(String key) async {
    await _ensureInitialized();
    return _prefs!.getStringList(key);
  }

  /// 设置字符串列表
  Future<bool> setStringList(String key, List<String> value) async {
    await _ensureInitialized();
    return _prefs!.setStringList(key, value);
  }

  /// 获取双精度浮点数
  Future<double?> getDouble(String key) async {
    await _ensureInitialized();
    return _prefs!.getDouble(key);
  }

  /// 设置双精度浮点数
  Future<bool> setDouble(String key, double value) async {
    await _ensureInitialized();
    return _prefs!.setDouble(key, value);
  }

  /// 删除键
  Future<bool> remove(String key) async {
    await _ensureInitialized();
    return _prefs!.remove(key);
  }

  /// 检查键是否存在
  Future<bool> containsKey(String key) async {
    await _ensureInitialized();
    return _prefs!.containsKey(key);
  }

  /// 清空所有数据
  Future<bool> clear() async {
    await _ensureInitialized();
    return _prefs!.clear();
  }

  /// 获取所有键
  Future<Set<String>> getKeys() async {
    await _ensureInitialized();
    return _prefs!.getKeys();
  }

  /// 重新加载数据
  Future<void> reload() async {
    await _ensureInitialized();
    await _prefs!.reload();
  }
}

