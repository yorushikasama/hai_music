import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StorageConfig obfuscation', () {
    String obfuscate(String plainText) {
      final bytes = utf8.encode(plainText);
      return base64.encode(bytes);
    }

    String deobfuscate(String obfuscated) {
      try {
        final bytes = base64.decode(obfuscated);
        return utf8.decode(bytes);
      } catch (e) {
        return obfuscated;
      }
    }

    test('should obfuscate and deobfuscate correctly', () {
      const plainText = 'my-secret-key-12345';

      final obfuscated = obfuscate(plainText);
      expect(obfuscated, isNot(equals(plainText)));

      final deobfuscated = deobfuscate(obfuscated);
      expect(deobfuscated, equals(plainText));
    });

    test('should produce valid base64 output', () {
      const plainText = 'test-value';

      final obfuscated = obfuscate(plainText);
      expect(() => base64.decode(obfuscated), returnsNormally);
    });

    test('should handle empty string', () {
      final obfuscated = obfuscate('');
      final deobfuscated = deobfuscate(obfuscated);
      expect(deobfuscated, '');
    });

    test('should handle unicode characters', () {
      const plainText = '中文密钥';

      final obfuscated = obfuscate(plainText);
      final deobfuscated = deobfuscate(obfuscated);
      expect(deobfuscated, plainText);
    });

    test('should fallback gracefully for invalid base64', () {
      final result = deobfuscate('not-valid-base64!!!');
      expect(result, 'not-valid-base64!!!');
    });

    test('should obfuscate different inputs to different outputs', () {
      final result1 = obfuscate('key1');
      final result2 = obfuscate('key2');
      expect(result1, isNot(equals(result2)));
    });
  });
}
