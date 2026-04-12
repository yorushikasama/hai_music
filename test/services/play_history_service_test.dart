import 'package:flutter_test/flutter_test.dart';
import 'package:hai_music/services/play_history_service.dart';

void main() {
  group('PlayHistoryService', () {
    test('should be a singleton', () {
      final instance1 = PlayHistoryService();
      final instance2 = PlayHistoryService();

      expect(identical(instance1, instance2), isTrue,
          reason: 'PlayHistoryService should be a singleton');
    });
  });
}
