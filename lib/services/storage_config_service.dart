import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/storage_config.dart';
import '../utils/logger.dart';

/// 存储配置服务
class StorageConfigService {
  static final StorageConfigService _instance = StorageConfigService._internal();
  late SharedPreferences _prefs;
  bool _initialized = false;
  
  static const String _configKey = 'storage_config';

  factory StorageConfigService() => _instance;

  StorageConfigService._internal();

  /// 初始化
  Future<void> init() async {
    if (!_initialized) {
      _prefs = await SharedPreferences.getInstance();
      _initialized = true;
    }
  }

  /// 保存配置
  Future<bool> saveConfig(StorageConfig config) async {
    try {
      final jsonStr = jsonEncode(config.toJson());
      return await _prefs.setString(_configKey, jsonStr);
    } catch (e) {
      Logger.error('保存配置失败', e, null, 'StorageConfig');
      return false;
    }
  }

  /// 获取配置
  StorageConfig getConfig() {
    try {
      final jsonStr = _prefs.getString(_configKey);
      if (jsonStr == null || jsonStr.isEmpty) {
        return StorageConfig.empty();
      }
      final json = jsonDecode(jsonStr);
      return StorageConfig.fromJson(json);
    } catch (e) {
      Logger.error('读取配置失败', e, null, 'StorageConfig');
      return StorageConfig.empty();
    }
  }

  /// 清除配置
  Future<bool> clearConfig() async {
    return await _prefs.remove(_configKey);
  }

  /// 检查配置是否存在且有效
  bool hasValidConfig() {
    final config = getConfig();
    return config.isValid;
  }
}
