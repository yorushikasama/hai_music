import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/storage_config.dart';
import '../../utils/logger.dart';

/// 存储配置服务
///
/// 管理 Supabase 和 R2 的连接配置，敏感字段(API Key/Secret)使用
/// FlutterSecureStorage 加密存储，非敏感字段使用 SharedPreferences 回退存储。
/// 被 FavoriteManagerService 依赖，提供云端同步所需的配置信息。
class StorageConfigService {
  static final StorageConfigService _instance = StorageConfigService._internal();
  SharedPreferences? _prefs;
  FlutterSecureStorage? _secureStorage;
  bool _secureStorageAvailable = false;
  Completer<void>? _initCompleter;
  bool _initialized = false;

  static const String _configKey = 'storage_config';
  static const String _secureSupabaseKey = 'secure_supabase_anon_key';
  static const String _secureR2AccessKey = 'secure_r2_access_key';
  static const String _secureR2SecretKey = 'secure_r2_secret_key';

  static const String _fallbackSupabaseKey = 'fallback_supabase_anon_key';
  static const String _fallbackR2AccessKey = 'fallback_r2_access_key';
  static const String _fallbackR2SecretKey = 'fallback_r2_secret_key';

  factory StorageConfigService() => _instance;

  StorageConfigService._internal();

  Future<void> init() async {
    if (_initialized) return;
    if (_initCompleter != null) {
      await _initCompleter!.future;
      return;
    }
    _initCompleter = Completer<void>();
    try {
      _prefs = await SharedPreferences.getInstance();

      try {
        _secureStorage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        );
        await _secureStorage!.read(key: '__init_test__');
        _secureStorageAvailable = true;
        Logger.info('FlutterSecureStorage 加密存储可用', 'StorageConfig');
      } catch (e) {
        Logger.warning('FlutterSecureStorage 加密存储不可用，使用 SharedPreferences 回退: $e', 'StorageConfig');
        _secureStorage = null;
        _secureStorageAvailable = false;
      }

      _initialized = true;
      _initCompleter!.complete();
    } catch (e) {
      _initCompleter!.completeError(e);
      _initCompleter = null;
      rethrow;
    }
  }

  SharedPreferences get _safePrefs {
    if (_prefs == null) {
      throw StateError('StorageConfigService 未初始化，请先调用 init()');
    }
    return _prefs!;
  }

  Future<void> _writeSecure(String key, String value) async {
    if (_secureStorageAvailable && _secureStorage != null) {
      await _secureStorage!.write(key: key, value: value);
    } else {
      await _safePrefs.setString(key, value);
    }
  }

  Future<String?> _readSecure(String key) async {
    if (_secureStorageAvailable && _secureStorage != null) {
      return _secureStorage!.read(key: key);
    } else {
      return _safePrefs.getString(key);
    }
  }

  Future<void> _deleteSecure(String key) async {
    if (_secureStorageAvailable && _secureStorage != null) {
      await _secureStorage!.delete(key: key);
    } else {
      await _safePrefs.remove(key);
    }
  }

  String _mapKeyToStorage(String secureKey) {
    if (_secureStorageAvailable) return secureKey;
    switch (secureKey) {
      case _secureSupabaseKey:
        return _fallbackSupabaseKey;
      case _secureR2AccessKey:
        return _fallbackR2AccessKey;
      case _secureR2SecretKey:
        return _fallbackR2SecretKey;
      default:
        return secureKey;
    }
  }

  Future<bool> saveConfig(StorageConfig config) async {
    try {
      if (!_initialized) await init();

      final jsonData = config.toJson();

      final sensitiveValues = {
        _secureSupabaseKey: jsonData.remove('supabaseAnonKey') as String?,
        _secureR2AccessKey: jsonData.remove('r2AccessKey') as String?,
        _secureR2SecretKey: jsonData.remove('r2SecretKey') as String?,
      };

      for (final entry in sensitiveValues.entries) {
        final storageKey = _mapKeyToStorage(entry.key);
        if (entry.value != null && entry.value!.isNotEmpty) {
          await _writeSecure(storageKey, entry.value!);
        } else {
          await _deleteSecure(storageKey);
        }
      }

      final jsonStr = jsonEncode(jsonData);
      final success = await _safePrefs.setString(_configKey, jsonStr);

      if (success) {
        Logger.success('配置保存成功${_secureStorageAvailable ? '（敏感字段已加密）' : '（使用回退存储）'}', 'StorageConfig');
        return true;
      } else {
        Logger.error('SharedPreferences 保存返回 false', null, null, 'StorageConfig');
        return false;
      }
    } catch (e) {
      Logger.error('保存配置失败', e, null, 'StorageConfig');
      return false;
    }
  }

  Future<StorageConfig> getConfigAsync() async {
    try {
      if (!_initialized) await init();

      final jsonStr = _safePrefs.getString(_configKey);
      if (jsonStr == null || jsonStr.isEmpty) {
        return StorageConfig.empty();
      }

      final jsonData = jsonDecode(jsonStr) as Map<String, dynamic>;

      final supabaseKey = _mapKeyToStorage(_secureSupabaseKey);
      final r2AccessKey = _mapKeyToStorage(_secureR2AccessKey);
      final r2SecretKey = _mapKeyToStorage(_secureR2SecretKey);

      final supabaseAnonKey = await _readSecure(supabaseKey);
      final r2AccessKeyValue = await _readSecure(r2AccessKey);
      final r2SecretKeyValue = await _readSecure(r2SecretKey);

      if (supabaseAnonKey != null) jsonData['supabaseAnonKey'] = supabaseAnonKey;
      if (r2AccessKeyValue != null) jsonData['r2AccessKey'] = r2AccessKeyValue;
      if (r2SecretKeyValue != null) jsonData['r2SecretKey'] = r2SecretKeyValue;

      return StorageConfig.fromJson(jsonData);
    } catch (e) {
      Logger.error('异步读取配置失败', e, null, 'StorageConfig');
      return StorageConfig.empty();
    }
  }

}
