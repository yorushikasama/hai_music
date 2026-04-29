import 'package:flutter_test/flutter_test.dart';
import 'package:hai_music/services/ui/sleep_timer_service.dart';

void main() {
  group('SleepTimerService', () {
    late SleepTimerService service;
    bool _disposed = false;

    setUp(() {
      _disposed = false;
      service = SleepTimerService();
    });

    tearDown(() {
      if (!_disposed) {
        service.cancel();
      }
    });

    group('initial state', () {
      test('should not be active initially', () {
        expect(service.isActive, isFalse);
      });

      test('should have no remaining time initially', () {
        expect(service.remainingTime, isNull);
      });

      test('should have no end time initially', () {
        expect(service.endTime, isNull);
      });

      test('should have empty formatted remaining time initially', () {
        expect(service.formattedRemainingTime, '');
      });
    });

    group('start', () {
      test('should activate timer on start', () {
        service.start(const Duration(minutes: 15), () {});

        expect(service.isActive, isTrue);
        expect(service.remainingTime, isNotNull);
        expect(service.endTime, isNotNull);
      });

      test('should set correct remaining time', () {
        service.start(const Duration(minutes: 15), () {});

        expect(service.remainingTime!.inMinutes, lessThanOrEqualTo(15));
        expect(service.remainingTime!.inMinutes, greaterThan(13));
      });

      test('should set end time in the future', () {
        final before = DateTime.now();
        service.start(const Duration(minutes: 15), () {});
        final after = DateTime.now();

        expect(service.endTime!.isAfter(before), isTrue);
        expect(service.endTime!.isBefore(after.add(const Duration(minutes: 16))), isTrue);
      });

      test('should not start with zero duration', () {
        service.start(Duration.zero, () {});

        expect(service.isActive, isFalse);
      });

      test('should not start with negative duration', () {
        service.start(const Duration(seconds: -1), () {});

        expect(service.isActive, isFalse);
      });

      test('should cancel previous timer when starting new one', () {
        bool firstCallbackCalled = false;
        service.start(const Duration(minutes: 1), () {
          firstCallbackCalled = true;
        });

        service.start(const Duration(minutes: 2), () {});

        expect(firstCallbackCalled, isFalse);
        expect(service.isActive, isTrue);
      });

      test('should notify listeners on start', () {
        bool notified = false;
        service.addListener(() => notified = true);

        service.start(const Duration(minutes: 15), () {});

        expect(notified, isTrue);
      });
    });

    group('cancel', () {
      test('should deactivate timer on cancel', () {
        service.start(const Duration(minutes: 15), () {});
        service.cancel();

        expect(service.isActive, isFalse);
      });

      test('should clear remaining time on cancel', () {
        service.start(const Duration(minutes: 15), () {});
        service.cancel();

        expect(service.remainingTime, isNull);
      });

      test('should clear end time on cancel', () {
        service.start(const Duration(minutes: 15), () {});
        service.cancel();

        expect(service.endTime, isNull);
      });

      test('should notify listeners on cancel', () {
        service.start(const Duration(minutes: 15), () {});
        bool notified = false;
        service.addListener(() => notified = true);

        service.cancel();

        expect(notified, isTrue);
      });

      test('should do nothing when cancelling inactive timer', () {
        service.cancel();

        expect(service.isActive, isFalse);
        expect(service.remainingTime, isNull);
      });
    });

    group('extend', () {
      test('should extend end time of active timer', () {
        service.start(const Duration(minutes: 15), () {});
        final originalEndTime = service.endTime!;

        service.extend(const Duration(minutes: 10));

        expect(service.endTime!.isAfter(originalEndTime), isTrue);
      });

      test('should update remaining time on extend', () {
        service.start(const Duration(minutes: 15), () {});

        service.extend(const Duration(minutes: 10));

        expect(service.remainingTime!.inMinutes, greaterThan(14));
      });

      test('should not extend inactive timer', () {
        final originalEndTime = service.endTime;

        service.extend(const Duration(minutes: 10));

        expect(service.endTime, originalEndTime);
      });

      test('should notify listeners on extend', () {
        service.start(const Duration(minutes: 15), () {});
        bool notified = false;
        service.addListener(() => notified = true);

        service.extend(const Duration(minutes: 10));

        expect(notified, isTrue);
      });
    });

    group('timer completion', () {
      test('should call callback on completion', () async {
        bool callbackCalled = false;
        service.start(const Duration(seconds: 1), () {
          callbackCalled = true;
        });

        await Future<void>.delayed(const Duration(seconds: 2));

        expect(callbackCalled, isTrue);
      });

      test('should deactivate timer after completion', () async {
        service.start(const Duration(seconds: 1), () {});

        await Future<void>.delayed(const Duration(seconds: 2));

        expect(service.isActive, isFalse);
      });

      test('should clear remaining time after completion', () async {
        service.start(const Duration(seconds: 1), () {});

        await Future<void>.delayed(const Duration(seconds: 2));

        expect(service.remainingTime, isNull);
      });
    });

    group('dispose', () {
      test('should cancel timer on dispose', () {
        final disposeService = SleepTimerService();
        disposeService.start(const Duration(minutes: 15), () {});
        expect(disposeService.isActive, isTrue);

        disposeService.dispose();

        expect(disposeService.isActive, isFalse);
      });
    });
  });
}
