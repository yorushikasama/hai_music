const Object _sentinel = Object();

class StorageConfig {
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String r2Endpoint;
  final String r2AccessKey;
  final String r2SecretKey;
  final String r2BucketName;
  final String r2Region;
  final String? r2CustomDomain;
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
      supabaseUrl: (json['supabaseUrl'] ?? '') as String,
      supabaseAnonKey: (json['supabaseAnonKey'] ?? '') as String,
      r2Endpoint: (json['r2Endpoint'] ?? '') as String,
      r2AccessKey: (json['r2AccessKey'] ?? '') as String,
      r2SecretKey: (json['r2SecretKey'] ?? '') as String,
      r2BucketName: (json['r2BucketName'] ?? '') as String,
      r2Region: (json['r2Region'] ?? 'auto') as String,
      r2CustomDomain: json['r2CustomDomain'] as String?,
      enableSync: (json['enableSync'] ?? false) as bool,
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

  /// 返回敏感字段已掩码的安全版本，用于日志和调试
  Map<String, dynamic> toSafeJson() {
    return {
      'supabaseUrl': supabaseUrl,
      'supabaseAnonKey': _maskSecret(supabaseAnonKey),
      'r2Endpoint': r2Endpoint,
      'r2AccessKey': _maskSecret(r2AccessKey),
      'r2SecretKey': _maskSecret(r2SecretKey),
      'r2BucketName': r2BucketName,
      'r2Region': r2Region,
      'r2CustomDomain': r2CustomDomain,
      'enableSync': enableSync,
    };
  }

  static String _maskSecret(String value) {
    if (value.length <= 8) return '****';
    return '${value.substring(0, 4)}****${value.substring(value.length - 4)}';
  }

  bool get isValid {
    return supabaseUrl.isNotEmpty &&
        supabaseAnonKey.isNotEmpty &&
        r2Endpoint.isNotEmpty &&
        r2AccessKey.isNotEmpty &&
        r2SecretKey.isNotEmpty &&
        r2BucketName.isNotEmpty;
  }

  factory StorageConfig.empty() {
    return StorageConfig(
      supabaseUrl: '',
      supabaseAnonKey: '',
      r2Endpoint: '',
      r2AccessKey: '',
      r2SecretKey: '',
      r2BucketName: '',
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
    Object? r2CustomDomain = _sentinel,
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
      r2CustomDomain: r2CustomDomain == _sentinel
          ? this.r2CustomDomain
          : r2CustomDomain as String?,
      enableSync: enableSync ?? this.enableSync,
    );
  }
}
