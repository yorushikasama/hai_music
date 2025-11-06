import '../models/storage_config.dart';

/// 粘贴板配置解析服务
class ClipboardConfigParser {
  /// 从粘贴板文本中解析云端配置
  static StorageConfig? parseConfig(String clipboardText) {
    if (clipboardText.isEmpty) return null;

    try {
      // 初始化配置对象
      String? supabaseUrl;
      String? supabaseAnonKey;
      String? r2Endpoint;
      String? r2AccessKeyId;
      String? r2SecretAccessKey;
      String? r2BucketName;
      String? r2Region;
      String? r2CustomDomain;

      // 按行分割文本
      final lines = clipboardText.split('\n');

      for (var line in lines) {
        line = line.trim();
        if (line.isEmpty) continue;

        // 解析 Supabase URL
        if (_matchesPattern(line, ['supabase', 'url'])) {
          supabaseUrl = _extractValue(line);
        }
        // 解析 Supabase Anon Key
        else if (_matchesPattern(line, ['supabase', 'anon', 'key'])) {
          supabaseAnonKey = _extractValue(line);
        }
        // 解析 R2 Endpoint
        else if (_matchesPattern(line, ['r2', 'endpoint'])) {
          r2Endpoint = _extractValue(line);
        }
        // 解析 Access Key Id
        else if (_matchesPattern(line, ['access', 'key', 'id'])) {
          r2AccessKeyId = _extractValue(line);
        }
        // 解析 Secret Access Key
        else if (_matchesPattern(line, ['secret', 'access', 'key'])) {
          r2SecretAccessKey = _extractValue(line);
        }
        // 解析 Bucket 名称
        else if (_matchesPattern(line, ['bucket'])) {
          r2BucketName = _extractValue(line);
        }
        // 解析 Region
        else if (_matchesPattern(line, ['region'])) {
          r2Region = _extractValue(line);
        }
        // 解析 R2 自定义域名
        else if (_matchesPattern(line, ['r2', '自定义', '域名']) || 
                 _matchesPattern(line, ['r2', 'custom', 'domain'])) {
          r2CustomDomain = _extractValue(line);
        }
      }

      // 验证必填字段
      if (supabaseUrl == null || supabaseAnonKey == null) {
        print('❌ 缺少 Supabase 配置');
        return null;
      }

      if (r2Endpoint == null || r2AccessKeyId == null || 
          r2SecretAccessKey == null || r2BucketName == null) {
        print('❌ 缺少 R2 配置');
        return null;
      }

      // 创建配置对象
      final config = StorageConfig(
        supabaseUrl: supabaseUrl,
        supabaseAnonKey: supabaseAnonKey,
        r2Endpoint: r2Endpoint,
        // 🔧 优化:移除不必要的 ! 操作符
        r2AccessKey: r2AccessKeyId,
        r2SecretKey: r2SecretAccessKey,
        r2BucketName: r2BucketName,
        r2Region: r2Region ?? 'auto',
        r2CustomDomain: r2CustomDomain,
      );

      // 🔧 优化:移除不必要的字符串插值大括号
      print('✅ 成功解析配置');
      print('  Supabase URL: $supabaseUrl');
      print('  R2 Bucket: $r2BucketName');
      print('  R2 Custom Domain: ${r2CustomDomain ?? "未设置"}');

      return config;
    } catch (e) {
      print('❌ 解析配置失败: $e');
      return null;
    }
  }

  /// 检查行是否匹配指定的关键词模式
  static bool _matchesPattern(String line, List<String> keywords) {
    final lowerLine = line.toLowerCase();
    return keywords.every((keyword) => lowerLine.contains(keyword.toLowerCase()));
  }

  /// 从行中提取值
  static String? _extractValue(String line) {
    // 尝试多种分隔符：冒号、等号
    final separators = [':', '：', '='];
    
    for (var separator in separators) {
      if (line.contains(separator)) {
        final parts = line.split(separator);
        if (parts.length >= 2) {
          var value = parts.sublist(1).join(separator).trim();
          // 移除可能的逗号、引号等
          value = value.replaceAll(',', '').replaceAll('，', '').replaceAll('"', '').replaceAll("'", '').trim();
          if (value.isNotEmpty) {
            return value;
          }
        }
      }
    }

    // 如果没有分隔符，尝试提取URL或长字符串
    final urlMatch = RegExp(r'https?://[^\s,，]+').firstMatch(line);
    if (urlMatch != null) {
      return urlMatch.group(0);
    }

    // 提取长字符串（可能是key）
    final keyMatch = RegExp(r'[a-zA-Z0-9_\-\.]{20,}').firstMatch(line);
    if (keyMatch != null) {
      return keyMatch.group(0);
    }

    return null;
  }

  /// 生成配置文本示例
  static String generateExample() {
    return '''
supabase url: https://your-project.supabase.co
supabase anon key: your-anon-key-here
R2 Endpoint: https://your-account-id.r2.cloudflarestorage.com
Access Key Id: your-access-key-id
Secret Access Key: your-secret-access-key
Bucket 名称: your-bucket-name
Region: APAC
R2 自定义域名: your-custom-domain.com
''';
  }

  /// 验证配置格式
  static bool validateConfigText(String text) {
    if (text.isEmpty) return false;

    final lowerText = text.toLowerCase();
    
    // 检查必需的关键词
    final requiredKeywords = [
      'supabase',
      'url',
      'anon',
      'key',
      'r2',
      'endpoint',
      'access',
      'bucket',
    ];

    int matchCount = 0;
    for (var keyword in requiredKeywords) {
      if (lowerText.contains(keyword)) {
        matchCount++;
      }
    }

    // 至少匹配6个关键词才认为是有效配置
    return matchCount >= 6;
  }
}
