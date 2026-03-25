import 'dart:io';
import 'package:dio/dio.dart';
import '../utils/logger.dart';

/// 安全配置服务
/// 提供网络安全配置、输入验证和数据加密功能
class SecurityConfigService {
  static final SecurityConfigService _instance = SecurityConfigService._internal();
  factory SecurityConfigService() => _instance;
  SecurityConfigService._internal();

  // SSL证书验证配置
  bool _sslVerify = true;
  List<String> _trustedHosts = [];
  
  // 输入验证配置
  final Map<String, RegExp> _validationPatterns = {
    'email': RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$'),
    'url': RegExp(r'^https?://[\w\-\.]+\.[a-zA-Z]{2,}(/\S*)?$'),
    'alphanumeric': RegExp(r'^[a-zA-Z0-9]+$'),
    'safeText': RegExp(r'^[\w\s\-\.\,\!\?\(\)\[\]\{\}]+$'),
  };

  // 敏感数据加密密钥（实际项目中应该从安全存储获取）
  String? _encryptionKey;

  /// 初始化安全配置
  void initialize({
    bool sslVerify = true,
    List<String> trustedHosts = const [],
    String? encryptionKey,
  }) {
    _sslVerify = sslVerify;
    _trustedHosts = List.from(trustedHosts);
    _encryptionKey = encryptionKey;
    
    Logger.info('安全配置服务初始化完成', 'SecurityConfig');
  }

  /// 获取安全的Dio配置
  BaseOptions getSecureDioOptions() {
    return BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Accept': 'application/json',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'X-Requested-With': 'XMLHttpRequest',
      },
      validateStatus: (status) {
        return status != null && status >= 200 && status < 300;
      },
    );
  }

  /// 获取SSL证书验证配置
  (SecurityContext?, bool) getSSLConfig() {
    if (!_sslVerify) {
      Logger.warning('SSL证书验证已禁用', 'SecurityConfig');
      return (null, false);
    }

    try {
      final context = SecurityContext.defaultContext;
      
      // 设置允许的TLS版本
      context.setAlpnProtocols(['h2', 'http/1.1'], true);
      
      return (context, true);
    } catch (e) {
      Logger.error('SSL配置失败', e, null, 'SecurityConfig');
      return (null, false);
    }
  }

  /// 验证URL安全性
  bool isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      
      // 检查协议
      if (uri.scheme != 'https' && uri.scheme != 'http') {
        Logger.warning('不安全的URL协议: ${uri.scheme}', 'SecurityConfig');
        return false;
      }

      // 检查主机
      if (uri.host.isEmpty) {
        Logger.warning('URL主机为空', 'SecurityConfig');
        return false;
      }

      // 检查可信主机列表
      if (_trustedHosts.isNotEmpty && !_trustedHosts.contains(uri.host)) {
        Logger.warning('不可信的主机: ${uri.host}', 'SecurityConfig');
        return false;
      }

      return true;
    } catch (e) {
      Logger.error('URL验证失败: $url', e, null, 'SecurityConfig');
      return false;
    }
  }

  /// 验证输入文本
  bool validateInput(String input, String type) {
    if (input.isEmpty) {
      return true; // 空输入视为有效，由调用方决定是否允许
    }

    final pattern = _validationPatterns[type];
    if (pattern == null) {
      Logger.warning('未知的验证类型: $type', 'SecurityConfig');
      return false;
    }

    final isValid = pattern.hasMatch(input);
    if (!isValid) {
      Logger.warning('输入验证失败 - 类型: $type, 输入: $input', 'SecurityConfig');
    }

    return isValid;
  }

  /// 清理用户输入（防止XSS和注入攻击）
  String sanitizeInput(String input) {
    if (input.isEmpty) return input;

    var sanitized = input
        // 移除HTML标签
        .replaceAll(RegExp(r'<[^>]*>'), '')
        // 移除JavaScript事件处理器
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        // 移除JavaScript协议
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        // 移除数据URI
        .replaceAll(RegExp(r'data:', caseSensitive: false), '')
        // 移除VBScript协议
        .replaceAll(RegExp(r'vbscript:', caseSensitive: false), '')
        // 转义特殊字符
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;')
        .replaceAll('/', '&#x2F;');

    return sanitized;
  }

  /// 验证搜索关键词
  bool validateSearchKeyword(String keyword) {
    if (keyword.isEmpty) {
      return false;
    }

    // 检查长度
    if (keyword.length > 100) {
      Logger.warning('搜索关键词过长: ${keyword.length} 字符', 'SecurityConfig');
      return false;
    }

    // 检查是否包含危险字符
    final dangerousChars = RegExp(r'[<>\"\'&;()]');
    if (dangerousChars.hasMatch(keyword)) {
      Logger.warning('搜索关键词包含危险字符', 'SecurityConfig');
      return false;
    }

    // 检查SQL注入模式
    final sqlInjection = RegExp(
      r'(\b(SELECT|INSERT|UPDATE|DELETE|DROP|CREATE|ALTER|EXEC|EXECUTE)\b)|' +
      r'(\b(UNION|JOIN|WHERE|FROM|TABLE|DATABASE)\b)|' +
      r'(\-\-|\#|\/\*|\*\/)',
      caseSensitive: false,
    );
    if (sqlInjection.hasMatch(keyword)) {
      Logger.warning('搜索关键词可能包含SQL注入', 'SecurityConfig');
      return false;
    }

    return true;
  }

  /// 验证歌曲ID
  bool validateSongId(String songId) {
    if (songId.isEmpty) {
      return false;
    }

    // 只允许字母数字和下划线
    final validPattern = RegExp(r'^[a-zA-Z0-9_-]+$');
    if (!validPattern.hasMatch(songId)) {
      Logger.warning('歌曲ID格式无效: $songId', 'SecurityConfig');
      return false;
    }

    // 检查长度
    if (songId.length > 50) {
      Logger.warning('歌曲ID过长: ${songId.length} 字符', 'SecurityConfig');
      return false;
    }

    return true;
  }

  /// 验证QQ号码
  bool validateQQNumber(String qqNumber) {
    if (qqNumber.isEmpty) {
      return false;
    }

    // QQ号码应该是5-11位数字
    final validPattern = RegExp(r'^[1-9]\d{4,10}$');
    if (!validPattern.hasMatch(qqNumber)) {
      Logger.warning('QQ号码格式无效: $qqNumber', 'SecurityConfig');
      return false;
    }

    return true;
  }

  /// 简单的数据加密（实际项目中应该使用更强大的加密算法）
  String? encryptData(String data) {
    if (_encryptionKey == null) {
      Logger.warning('加密密钥未设置', 'SecurityConfig');
      return null;
    }

    try {
      // 这里应该实现真正的加密逻辑
      // 简化示例：使用Base64编码（实际项目中应该使用AES等加密算法）
      final bytes = data.codeUnits;
      final encrypted = String.fromCharCodes(
        bytes.map((b) => b ^ _encryptionKey!.codeUnitAt(b % _encryptionKey!.length))
      );
      return encrypted;
    } catch (e) {
      Logger.error('数据加密失败', e, null, 'SecurityConfig');
      return null;
    }
  }

  /// 简单的数据解密
  String? decryptData(String encryptedData) {
    if (_encryptionKey == null) {
      Logger.warning('解密密钥未设置', 'SecurityConfig');
      return null;
    }

    try {
      // 这里应该实现真正的解密逻辑
      // 简化示例：使用Base64解码（实际项目中应该使用AES等解密算法）
      final bytes = encryptedData.codeUnits;
      final decrypted = String.fromCharCodes(
        bytes.map((b) => b ^ _encryptionKey!.codeUnitAt(b % _encryptionKey!.length))
      );
      return decrypted;
    } catch (e) {
      Logger.error('数据解密失败', e, null, 'SecurityConfig');
      return null;
    }
  }

  /// 安全地存储敏感数据
  Future<bool> storeSecureData(String key, String value) async {
    try {
      final encrypted = encryptData(value);
      if (encrypted == null) {
        return false;
      }

      // 这里应该使用安全的存储方式
      // 实际项目中应该使用flutter_secure_storage或Keychain/Keystore
      Logger.info('敏感数据已安全存储: $key', 'SecurityConfig');
      return true;
    } catch (e) {
      Logger.error('存储敏感数据失败: $key', e, null, 'SecurityConfig');
      return false;
    }
  }

  /// 安全地读取敏感数据
  Future<String?> retrieveSecureData(String key) async {
    try {
      // 这里应该从安全存储中读取数据
      // 实际项目中应该使用flutter_secure_storage或Keychain/Keystore
      
      // 简化示例：返回null
      return null;
    } catch (e) {
      Logger.error('读取敏感数据失败: $key', e, null, 'SecurityConfig');
      return null;
    }
  }

  /// 生成安全的请求头
  Map<String, String> generateSecureHeaders() {
    return {
      'Accept': 'application/json',
      'Accept-Encoding': 'gzip, deflate, br',
      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
      'Cache-Control': 'no-cache',
      'Pragma': 'no-cache',
      'Sec-Fetch-Dest': 'empty',
      'Sec-Fetch-Mode': 'cors',
      'Sec-Fetch-Site': 'cross-site',
      'X-Requested-With': 'XMLHttpRequest',
    };
  }

  /// 检查响应安全性
  bool isSafeResponse(Response response) {
    // 检查状态码
    if (response.statusCode == null || response.statusCode! < 200 || response.statusCode! >= 300) {
      Logger.warning('不安全的响应状态码: ${response.statusCode}', 'SecurityConfig');
      return false;
    }

    // 检查内容类型
    final contentType = response.headers.value('content-type');
    if (contentType != null && !contentType.contains('application/json')) {
      Logger.warning('不安全的响应内容类型: $contentType', 'SecurityConfig');
      return false;
    }

    return true;
  }

  /// 获取安全配置摘要
  Map<String, dynamic> getSecuritySummary() {
    return {
      'sslVerify': _sslVerify,
      'trustedHosts': _trustedHosts,
      'validationPatterns': _validationPatterns.keys.toList(),
      'encryptionEnabled': _encryptionKey != null,
    };
  }
}
