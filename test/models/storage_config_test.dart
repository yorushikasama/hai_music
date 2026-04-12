import 'package:flutter_test/flutter_test.dart';
import 'package:hai_music/models/storage_config.dart';

void main() {
  group('StorageConfig', () {
    group('construction', () {
      test('should create with required fields', () {
        final config = StorageConfig(
          supabaseUrl: 'https://example.supabase.co',
          supabaseAnonKey: 'key123',
          r2Endpoint: 'https://r2.example.com',
          r2AccessKey: 'access123',
          r2SecretKey: 'secret123',
          r2BucketName: 'my-bucket',
        );

        expect(config.supabaseUrl, 'https://example.supabase.co');
        expect(config.supabaseAnonKey, 'key123');
        expect(config.r2Region, 'auto');
        expect(config.r2CustomDomain, isNull);
        expect(config.enableSync, isFalse);
      });
    });

    group('isValid', () {
      test('should be valid when all required fields are filled', () {
        final config = StorageConfig(
          supabaseUrl: 'url',
          supabaseAnonKey: 'key',
          r2Endpoint: 'endpoint',
          r2AccessKey: 'access',
          r2SecretKey: 'secret',
          r2BucketName: 'bucket',
        );
        expect(config.isValid, isTrue);
      });

      test('should be invalid when any required field is empty', () {
        final baseConfig = StorageConfig(
          supabaseUrl: 'url',
          supabaseAnonKey: 'key',
          r2Endpoint: 'endpoint',
          r2AccessKey: 'access',
          r2SecretKey: 'secret',
          r2BucketName: 'bucket',
        );

        expect(baseConfig.copyWith(supabaseUrl: '').isValid, isFalse);
        expect(baseConfig.copyWith(supabaseAnonKey: '').isValid, isFalse);
        expect(baseConfig.copyWith(r2Endpoint: '').isValid, isFalse);
        expect(baseConfig.copyWith(r2AccessKey: '').isValid, isFalse);
        expect(baseConfig.copyWith(r2SecretKey: '').isValid, isFalse);
        expect(baseConfig.copyWith(r2BucketName: '').isValid, isFalse);
      });

      test('empty config should be invalid', () {
        expect(StorageConfig.empty().isValid, isFalse);
      });
    });

    group('toJson/fromJson', () {
      test('should round-trip correctly', () {
        final original = StorageConfig(
          supabaseUrl: 'https://example.supabase.co',
          supabaseAnonKey: 'key123',
          r2Endpoint: 'https://r2.example.com',
          r2AccessKey: 'access123',
          r2SecretKey: 'secret123',
          r2BucketName: 'my-bucket',
          r2Region: 'us-east-1',
          r2CustomDomain: 'cdn.example.com',
          enableSync: true,
        );

        final json = original.toJson();
        final restored = StorageConfig.fromJson(json);

        expect(restored.supabaseUrl, original.supabaseUrl);
        expect(restored.supabaseAnonKey, original.supabaseAnonKey);
        expect(restored.r2Endpoint, original.r2Endpoint);
        expect(restored.r2AccessKey, original.r2AccessKey);
        expect(restored.r2SecretKey, original.r2SecretKey);
        expect(restored.r2BucketName, original.r2BucketName);
        expect(restored.r2Region, original.r2Region);
        expect(restored.r2CustomDomain, original.r2CustomDomain);
        expect(restored.enableSync, original.enableSync);
      });
    });

    group('copyWith', () {
      test('should preserve unchanged fields', () {
        final original = StorageConfig(
          supabaseUrl: 'url',
          supabaseAnonKey: 'key',
          r2Endpoint: 'endpoint',
          r2AccessKey: 'access',
          r2SecretKey: 'secret',
          r2BucketName: 'bucket',
          enableSync: true,
        );

        final copied = original.copyWith(enableSync: false);

        expect(copied.supabaseUrl, 'url');
        expect(copied.enableSync, isFalse);
      });

      test('should set r2CustomDomain to null', () {
        final original = StorageConfig(
          supabaseUrl: 'url',
          supabaseAnonKey: 'key',
          r2Endpoint: 'endpoint',
          r2AccessKey: 'access',
          r2SecretKey: 'secret',
          r2BucketName: 'bucket',
          r2CustomDomain: 'cdn.example.com',
        );

        final copied = original.copyWith(r2CustomDomain: null);
        expect(copied.r2CustomDomain, isNull);
      });
    });
  });
}
