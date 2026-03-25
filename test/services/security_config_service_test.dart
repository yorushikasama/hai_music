import 'package:flutter_test/flutter_test.dart';
import 'package:hai_music/services/security_config_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SecurityConfigService', () {
    late SecurityConfigService securityService;

    setUp(() {
      securityService = SecurityConfigService();
      securityService.initialize(
        sslVerify: true,
        trustedHosts: ['api.example.com', 'music.example.com'],
        encryptionKey: 'test_key_123',
      );
    });

    test('should create singleton instance', () {
      final instance1 = SecurityConfigService();
      final instance2 = SecurityConfigService();
      expect(identical(instance1, instance2), isTrue);
    });

    test('should validate URLs correctly', () {
      // 有效的URL
      expect(securityService.isValidUrl('https://api.example.com/songs'), isTrue);
      expect(securityService.isValidUrl('http://music.example.com/search'), isTrue);
      
      // 无效的URL
      expect(securityService.isValidUrl('ftp://example.com/file'), isFalse);
      expect(securityService.isValidUrl('javascript:alert("xss")'), isFalse);
      expect(securityService.isValidUrl(''), isFalse);
      expect(securityService.isValidUrl('not-a-url'), isFalse);
    });

    test('should validate search keywords correctly', () {
      // 有效的关键词
      expect(securityService.validateSearchKeyword('周杰伦'), isTrue);
      expect(securityService.validateSearchKeyword('love song'), isTrue);
      expect(securityService.validateSearchKeyword('123'), isTrue);
      
      // 无效的关键词
      expect(securityService.validateSearchKeyword(''), isFalse);
      expect(securityService.validateSearchKeyword('a' * 101), isFalse); // 过长
      expect(securityService.validateSearchKeyword('SELECT * FROM users'), isFalse); // SQL注入
      expect(securityService.validateSearchKeyword('<script>alert("xss")</script>'), isFalse); // XSS
    });

    test('should validate song IDs correctly', () {
      // 有效的歌曲ID
      expect(securityService.validateSongId('123456'), isTrue);
      expect(securityService.validateSongId('abc123'), isTrue);
      expect(securityService.validateSongId('song_001'), isTrue);
      
      // 无效的歌曲ID
      expect(securityService.validateSongId(''), isFalse);
      expect(securityService.validateSongId('song<123>'), isFalse); // 包含特殊字符
      expect(securityService.validateSongId('a' * 51), isFalse); // 过长
    });

    test('should validate QQ numbers correctly', () {
      // 有效的QQ号码
      expect(securityService.validateQQNumber('123456'), isTrue);
      expect(securityService.validateQQNumber('12345678901'), isTrue);
      
      // 无效的QQ号码
      expect(securityService.validateQQNumber(''), isFalse);
      expect(securityService.validateQQNumber('1234'), isFalse); // 太短
      expect(securityService.validateQQNumber('123456789012'), isFalse); // 太长
      expect(securityService.validateQQNumber('012345'), isFalse); // 以0开头
      expect(securityService.validateQQNumber('abc123'), isFalse); // 包含字母
    });

    test('should sanitize input correctly', () {
      // 包含HTML标签
      expect(
        securityService.sanitizeInput('<script>alert("xss")</script>'),
        equals('&lt;script&gt;alert(&quot;xss&quot;)&lt;/script&gt;'),
      );
      
      // 包含JavaScript协议
      expect(
        securityService.sanitizeInput('javascript:alert("xss")'),
        equals('alert(&quot;xss&quot;)'),
      );
      
      // 正常文本
      expect(
        securityService.sanitizeInput('Hello World'),
        equals('Hello World'),
      );
    });

    test('should encrypt and decrypt data correctly', () {
      const testData = 'sensitive information';
      
      final encrypted = securityService.encryptData(testData);
      expect(encrypted, isNotNull);
      expect(encrypted, isNot(equals(testData)));
      
      final decrypted = securityService.decryptData(encrypted!);
      expect(decrypted, equals(testData));
    });

    test('should generate secure headers', () {
      final headers = securityService.generateSecureHeaders();
      
      expect(headers['Accept'], equals('application/json'));
      expect(headers['X-Requested-With'], equals('XMLHttpRequest'));
      expect(headers['Cache-Control'], equals('no-cache'));
      expect(headers.containsKey('Accept-Encoding'), isTrue);
    });

    test('should get security summary', () {
      final summary = securityService.getSecuritySummary();
      
      expect(summary['sslVerify'], isTrue);
      expect(summary['trustedHosts'], isA<List<String>>());
      expect(summary['validationPatterns'], isA<List<String>>());
      expect(summary['encryptionEnabled'], isTrue);
    });

    test('should validate input with different types', () {
      // 邮箱验证
      expect(securityService.validateInput('test@example.com', 'email'), isTrue);
      expect(securityService.validateInput('invalid-email', 'email'), isFalse);
      
      // URL验证
      expect(securityService.validateInput('https://example.com', 'url'), isTrue);
      expect(securityService.validateInput('not-a-url', 'url'), isFalse);
      
      // 字母数字验证
      expect(securityService.validateInput('abc123', 'alphanumeric'), isTrue);
      expect(securityService.validateInput('abc-123', 'alphanumeric'), isFalse);
      
      // 安全文本验证
      expect(securityService.validateInput('Hello World!', 'safeText'), isTrue);
      expect(securityService.validateInput('Hello <World>', 'safeText'), isFalse);
      
      // 未知类型
      expect(securityService.validateInput('test', 'unknown'), isFalse);
    });

    test('should handle empty input validation', () {
      // 空输入应该被视为有效（由调用方决定是否允许）
      expect(securityService.validateInput('', 'email'), isTrue);
      expect(securityService.validateInput('', 'url'), isTrue);
    });
  });
}
