import 'package:flutter_test/flutter_test.dart';
import 'package:hai_music/models/playback_speed.dart';

void main() {
  group('PlaybackSpeed', () {
    test('should have 8 preset speeds', () {
      expect(PlaybackSpeed.values.length, 8);
    });

    test('should have correct values', () {
      expect(PlaybackSpeed.x0_5.value, 0.5);
      expect(PlaybackSpeed.x0_75.value, 0.75);
      expect(PlaybackSpeed.x1_0.value, 1.0);
      expect(PlaybackSpeed.x1_25.value, 1.25);
      expect(PlaybackSpeed.x1_5.value, 1.5);
      expect(PlaybackSpeed.x1_75.value, 1.75);
      expect(PlaybackSpeed.x2_0.value, 2.0);
      expect(PlaybackSpeed.x3_0.value, 3.0);
    });

    test('should have correct labels', () {
      expect(PlaybackSpeed.x0_5.label, '0.5x');
      expect(PlaybackSpeed.x0_75.label, '0.75x');
      expect(PlaybackSpeed.x1_0.label, '1.0x');
      expect(PlaybackSpeed.x1_25.label, '1.25x');
      expect(PlaybackSpeed.x1_5.label, '1.5x');
      expect(PlaybackSpeed.x1_75.label, '1.75x');
      expect(PlaybackSpeed.x2_0.label, '2.0x');
      expect(PlaybackSpeed.x3_0.label, '3.0x');
    });

    test('should have increasing values', () {
      const speeds = PlaybackSpeed.values;
      for (int i = 1; i < speeds.length; i++) {
        expect(speeds[i].value, greaterThan(speeds[i - 1].value));
      }
    });

    test('isNormal should be true only for 1.0x', () {
      expect(PlaybackSpeed.x1_0.isNormal, isTrue);
      for (final speed in PlaybackSpeed.values) {
        if (speed != PlaybackSpeed.x1_0) {
          expect(speed.isNormal, isFalse);
        }
      }
    });

    test('displayLabel should show "倍速" for normal speed', () {
      expect(PlaybackSpeed.x1_0.displayLabel, '倍速');
    });

    test('displayLabel should show speed label for non-normal speeds', () {
      expect(PlaybackSpeed.x1_5.displayLabel, '1.5x');
      expect(PlaybackSpeed.x2_0.displayLabel, '2.0x');
    });

    test('fromValue should return correct speed', () {
      expect(PlaybackSpeed.fromValue(0.5), PlaybackSpeed.x0_5);
      expect(PlaybackSpeed.fromValue(1.0), PlaybackSpeed.x1_0);
      expect(PlaybackSpeed.fromValue(1.5), PlaybackSpeed.x1_5);
      expect(PlaybackSpeed.fromValue(2.0), PlaybackSpeed.x2_0);
      expect(PlaybackSpeed.fromValue(3.0), PlaybackSpeed.x3_0);
    });

    test('fromValue should return default for unknown value', () {
      expect(PlaybackSpeed.fromValue(1.1), PlaybackSpeed.x1_0);
      expect(PlaybackSpeed.fromValue(0.0), PlaybackSpeed.x1_0);
      expect(PlaybackSpeed.fromValue(5.0), PlaybackSpeed.x1_0);
    });

    test('fromValue should handle floating point precision', () {
      expect(PlaybackSpeed.fromValue(0.75001), PlaybackSpeed.x0_75);
      expect(PlaybackSpeed.fromValue(1.24999), PlaybackSpeed.x1_25);
    });

    test('presetValues should return all speed values', () {
      final values = PlaybackSpeed.presetValues;
      expect(values.length, 8);
      expect(values.first, 0.5);
      expect(values.last, 3.0);
    });

    test('semanticLabel should be descriptive', () {
      expect(PlaybackSpeed.x1_0.semanticLabel, contains('正常'));
      expect(PlaybackSpeed.x1_5.semanticLabel, contains('1.5x'));
      expect(PlaybackSpeed.x2_0.semanticLabel, contains('倍速'));
    });
  });
}
