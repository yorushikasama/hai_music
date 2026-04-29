import 'package:flutter_test/flutter_test.dart';
import 'package:hai_music/services/download/download_service.dart';

void main() {
  group('DeleteResult', () {
    test('allSuccess is true when no failedIds', () {
      const result = DeleteResult(
        totalSongs: 3,
        deletedIds: ['1', '2', '3'],
        failedIds: [],
      );

      expect(result.allSuccess, isTrue);
      expect(result.totalSongs, 3);
      expect(result.deletedIds.length, 3);
    });

    test('allSuccess is false when has failedIds', () {
      const result = DeleteResult(
        totalSongs: 3,
        deletedIds: ['1', '2'],
        failedIds: ['3'],
      );

      expect(result.allSuccess, isFalse);
      expect(result.deletedIds.length, 2);
      expect(result.failedIds.length, 1);
    });

    test('empty result has allSuccess true', () {
      const result = DeleteResult(
        totalSongs: 0,
        deletedIds: [],
        failedIds: [],
      );

      expect(result.allSuccess, isTrue);
      expect(result.totalSongs, 0);
    });
  });
}
