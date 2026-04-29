import 'package:flutter_test/flutter_test.dart';
import 'package:hai_music/utils/result.dart';

void main() {
  group('Result', () {
    group('Success', () {
      test('should hold value', () {
        const result = Success<int>(42);
        expect(result.value, 42);
        expect(result.isSuccess, isTrue);
        expect(result.isFailure, isFalse);
        expect(result.errorMessage, isNull);
        expect(result.error, isNull);
        expect(result.errorCode, isNull);
      });

      test('should map value', () {
        const result = Success<int>(10);
        final mapped = result.map((v) => v * 2);
        expect(mapped.value, 20);
        expect(mapped.isSuccess, isTrue);
      });

      test('should execute success branch in when', () {
        const result = Success<String>('hello');
        final output = result.when(
          success: (v) => 'ok:$v',
          failure: (m, e) => 'err:$m',
        );
        expect(output, 'ok:hello');
      });

      test('should execute success branch in whenCode', () {
        const result = Success<String>('hello');
        final output = result.whenCode(
          success: (v) => 'ok:$v',
          failure: (m, e, code) => 'err:$m',
        );
        expect(output, 'ok:hello');
      });

      test('getOrElse should return value', () {
        const result = Success<int>(42);
        expect(result.getOrElse(0), 42);
      });

      test('getOrThrow should return value', () {
        const result = Success<int>(42);
        expect(result.getOrThrow(), 42);
      });

      test('asyncMap should transform value asynchronously', () async {
        const result = Success<int>(10);
        final mapped = await result.asyncMap((v) async => v * 3);
        expect(mapped.value, 30);
        expect(mapped.isSuccess, isTrue);
      });

      test('toString should contain value', () {
        const result = Success<int>(42);
        expect(result.toString(), contains('42'));
      });
    });

    group('Failure', () {
      test('should hold error message', () {
        const result = Failure<int>('something went wrong');
        expect(result.message, 'something went wrong');
        expect(result.isFailure, isTrue);
        expect(result.isSuccess, isFalse);
        expect(result.value, isNull);
      });

      test('should hold optional error object', () {
        final exception = Exception('test');
        final result = Failure<int>('error', error: exception);
        expect(result.error, exception);
      });

      test('should hold error code', () {
        const result = Failure<int>('network error', code: ErrorCode.network);
        expect(result.errorCode, ErrorCode.network);
      });

      test('should preserve message, error and code in map', () {
        final result = Failure<String>('fail msg',
            error: Exception('e'), code: ErrorCode.timeout);
        final mapped = result.map((v) => v.toUpperCase());
        expect(mapped.isFailure, isTrue);
        expect(mapped.errorMessage, 'fail msg');
        expect(mapped.errorCode, ErrorCode.timeout);
      });

      test('should preserve message, error and code in asyncMap', () async {
        final result = Failure<String>('fail msg',
            error: Exception('e'), code: ErrorCode.network);
        final mapped = await result.asyncMap((v) async => v.toUpperCase());
        expect(mapped.isFailure, isTrue);
        expect(mapped.errorMessage, 'fail msg');
        expect(mapped.errorCode, ErrorCode.network);
      });

      test('should execute failure branch in when', () {
        final result = Failure<String>('oops', error: Exception('x'));
        final output = result.when(
          success: (v) => 'ok:$v',
          failure: (m, e) => 'err:$m',
        );
        expect(output, 'err:oops');
      });

      test('should execute failure branch in whenCode', () {
        final result = Failure<String>('oops',
            error: Exception('x'), code: ErrorCode.network);
        final output = result.whenCode(
          success: (v) => 'ok:$v',
          failure: (m, e, code) => 'err:$m:$code',
        );
        expect(output, 'err:oops:ErrorCode.network');
      });

      test('getOrElse should return default value', () {
        const result = Failure<int>('error');
        expect(result.getOrElse(99), 99);
      });

      test('getOrThrow should throw', () {
        final exception = Exception('test');
        final result = Failure<int>('error', error: exception);
        expect(() => result.getOrThrow(), throwsA(exception));
      });

      test('getOrThrow without error should throw Exception with message', () {
        const result = Failure<int>('custom error');
        expect(() => result.getOrThrow(), throwsA(isA<Exception>()));
      });

      test('toString should contain message', () {
        const result = Failure<int>('bad');
        expect(result.toString(), contains('bad'));
      });

      test('toString with code should contain code', () {
        const result = Failure<int>('bad', code: ErrorCode.network);
        expect(result.toString(), contains('network'));
      });
    });

    group('ErrorCode', () {
      test('should have all expected values', () {
        expect(ErrorCode.values, containsAll([
          ErrorCode.network,
          ErrorCode.unauthorized,
          ErrorCode.notFound,
          ErrorCode.paymentRequired,
          ErrorCode.storage,
          ErrorCode.timeout,
          ErrorCode.cancelled,
          ErrorCode.unknown,
        ]));
      });
    });
  });
}
