import 'package:flutter_test/flutter_test.dart';
import 'package:hai_music/services/dio_client.dart';

void main() {
  group('DioClient', () {
    late DioClient dioClient;

    setUp(() {
      dioClient = DioClient();
    });

    test('should create singleton instance', () {
      final instance1 = DioClient();
      final instance2 = DioClient();
      expect(identical(instance1, instance2), isTrue);
    });

    test('should have default timeout settings', () {
      expect(dioClient.dioInstance.options.connectTimeout, const Duration(seconds: 10));
      expect(dioClient.dioInstance.options.receiveTimeout, const Duration(seconds: 10));
    });

    test('should have default headers', () {
      expect(dioClient.dioInstance.options.headers['Accept'], 'application/json');
      expect(dioClient.dioInstance.options.headers['User-Agent'], isNotNull);
    });

    test('should have interceptors', () {
      expect(dioClient.dioInstance.interceptors.length, greaterThan(0));
    });
  });
}
