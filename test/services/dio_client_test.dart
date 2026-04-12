import 'package:dio/dio.dart';
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

    test('should have correct timeout settings', () {
      expect(dioClient.dio.options.connectTimeout, const Duration(seconds: 10));
      expect(dioClient.dio.options.receiveTimeout, const Duration(seconds: 30));
      expect(dioClient.dio.options.sendTimeout, const Duration(seconds: 30));
    });

    test('should have default headers', () {
      expect(dioClient.dio.options.headers['Accept'], 'application/json');
      expect(dioClient.dio.options.headers['User-Agent'], isNotNull);
    });

    test('should have interceptors', () {
      expect(dioClient.dio.interceptors.length, greaterThan(0));
    });

    test('should classify connection timeout as retryable', () {
      final client = DioClient();
      final method = client.isRetryableError;

      expect(
        method(DioException(
          type: DioExceptionType.connectionTimeout,
          requestOptions: RequestOptions(),
        )),
        isTrue,
      );
    });

    test('should classify 4xx errors as non-retryable', () {
      final client = DioClient();
      final method = client.shouldNotRetry;

      expect(
        method(DioException(
          type: DioExceptionType.badResponse,
          response: Response(
            statusCode: 400,
            requestOptions: RequestOptions(),
          ),
          requestOptions: RequestOptions(),
        )),
        isTrue,
      );

      expect(
        method(DioException(
          type: DioExceptionType.badResponse,
          response: Response(
            statusCode: 404,
            requestOptions: RequestOptions(),
          ),
          requestOptions: RequestOptions(),
        )),
        isTrue,
      );
    });

    test('should classify 5xx errors as retryable', () {
      final client = DioClient();
      final method = client.shouldNotRetry;

      expect(
        method(DioException(
          type: DioExceptionType.badResponse,
          response: Response(
            statusCode: 500,
            requestOptions: RequestOptions(),
          ),
          requestOptions: RequestOptions(),
        )),
        isFalse,
      );
    });
  });
}
