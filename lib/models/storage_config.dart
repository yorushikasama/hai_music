/// 存储配置模型
class StorageConfig {
  // Supabase 配置
  final String supabaseUrl;
  final String supabaseAnonKey;
  
  // Cloudflare R2 配置
  final String r2Endpoint;
  final String r2AccessKey;
  final String r2SecretKey;
  final String r2BucketName;
  final String r2Region;
  final String? r2CustomDomain; // R2 自定义域名（如：music.ysnight.cn）
  
  // 是否启用云端同步
  final bool enableSync;

  StorageConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.r2Endpoint,
    required this.r2AccessKey,
    required this.r2SecretKey,
    required this.r2BucketName,
    this.r2Region = 'auto',
    this.r2CustomDomain,
    this.enableSync = false,
  });

  factory StorageConfig.fromJson(Map<String, dynamic> json) {
    return StorageConfig(
      supabaseUrl: json['supabaseUrl'] ?? '',
      supabaseAnonKey: json['supabaseAnonKey'] ?? '',
      r2Endpoint: json['r2Endpoint'] ?? '',
      r2AccessKey: json['r2AccessKey'] ?? '',
      r2SecretKey: json['r2SecretKey'] ?? '',
      r2BucketName: json['r2BucketName'] ?? '',
      r2Region: json['r2Region'] ?? 'auto',
      r2CustomDomain: json['r2CustomDomain'],
      enableSync: json['enableSync'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'supabaseUrl': supabaseUrl,
      'supabaseAnonKey': supabaseAnonKey,
      'r2Endpoint': r2Endpoint,
      'r2AccessKey': r2AccessKey,
      'r2SecretKey': r2SecretKey,
      'r2BucketName': r2BucketName,
      'r2Region': r2Region,
      'r2CustomDomain': r2CustomDomain,
      'enableSync': enableSync,
    };
  }

  /// 检查配置是否完整
  bool get isValid {
    return supabaseUrl.isNotEmpty &&
        supabaseAnonKey.isNotEmpty &&
        r2Endpoint.isNotEmpty &&
        r2AccessKey.isNotEmpty &&
        r2SecretKey.isNotEmpty &&
        r2BucketName.isNotEmpty;
  }

  /// 创建空配置
  factory StorageConfig.empty() {
    return StorageConfig(
      supabaseUrl: '',
      supabaseAnonKey: '',
      r2Endpoint: '',
      r2AccessKey: '',
      r2SecretKey: '',
      r2BucketName: '',
      r2CustomDomain: null,
      enableSync: false,
    );
  }

  StorageConfig copyWith({
    String? supabaseUrl,
    String? supabaseAnonKey,
    String? r2Endpoint,
    String? r2AccessKey,
    String? r2SecretKey,
    String? r2BucketName,
    String? r2Region,
    String? r2CustomDomain,
    bool? enableSync,
  }) {
    return StorageConfig(
      supabaseUrl: supabaseUrl ?? this.supabaseUrl,
      supabaseAnonKey: supabaseAnonKey ?? this.supabaseAnonKey,
      r2Endpoint: r2Endpoint ?? this.r2Endpoint,
      r2AccessKey: r2AccessKey ?? this.r2AccessKey,
      r2SecretKey: r2SecretKey ?? this.r2SecretKey,
      r2BucketName: r2BucketName ?? this.r2BucketName,
      r2Region: r2Region ?? this.r2Region,
      r2CustomDomain: r2CustomDomain ?? this.r2CustomDomain,
      enableSync: enableSync ?? this.enableSync,
    );
  }
}
