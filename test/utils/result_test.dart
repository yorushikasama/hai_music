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

      test('should preserve message and error in map', () {
        final result = Failure<String>('fail msg', error: Exception('e'));
        final mapped = result.map((v) => v.toUpperCase());
        expect(mapped.isFailure, isTrue);
        expect(mapped.errorMessage, 'fail msg');
      });

      test('should execute failure branch in when', () {
        final result = Failure<String>('oops', error: Exception('x'));
        final output = result.when(
          success: (v) => 'ok:$v',
          failure: (m, e) => 'err:$m',
        );
        expect(output, 'err:oops');
      });

      test('toString should contain message', () {
        const result = Failure<int>('bad');
        expect(result.toString(), contains('bad'));
      });
    });
  });
}
