import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hai_music/models/audio_quality.dart';

void main() {
  group('AudioQuality', () {
    test('should have correct values', () {
      expect(AudioQuality.standard.value, 4);
      expect(AudioQuality.high.value, 8);
      expect(AudioQuality.highPlus.value, 9);
      expect(AudioQuality.lossless.value, 10);
      expect(AudioQuality.hiRes.value, 11);
      expect(AudioQuality.dolby.value, 12);
      expect(AudioQuality.master.value, 13);
      expect(AudioQuality.masterPlus.value, 14);
    });

    test('should have correct labels', () {
      expect(AudioQuality.standard.label, '标准');
      expect(AudioQuality.high.label, 'HQ');
      expect(AudioQuality.highPlus.label, 'HQ+');
      expect(AudioQuality.lossless.label, 'SQ');
      expect(AudioQuality.hiRes.label, 'Hi-Res');
      expect(AudioQuality.dolby.label, '杜比');
      expect(AudioQuality.master.label, '臻品');
      expect(AudioQuality.masterPlus.label, '母带');
    });

    test('should have correct descriptions', () {
      expect(AudioQuality.standard.description, '标准音质');
      expect(AudioQuality.high.description, 'HQ高音质');
      expect(AudioQuality.lossless.description, 'SQ无损音质');
      expect(AudioQuality.masterPlus.description, '臻品母带2.0');
    });

    test('should have bitrate info', () {
      expect(AudioQuality.standard.bitrate, '128kbps');
      expect(AudioQuality.high.bitrate, '320kbps');
      expect(AudioQuality.lossless.bitrate, 'FLAC');
      expect(AudioQuality.hiRes.bitrate, '24bit/96kHz');
      expect(AudioQuality.dolby.bitrate, 'Dolby Atmos');
      expect(AudioQuality.masterPlus.bitrate, '24bit/192kHz');
    });

    test('should have category info', () {
      expect(AudioQuality.standard.category, AudioQualityCategory.standard);
      expect(AudioQuality.high.category, AudioQualityCategory.highQuality);
      expect(AudioQuality.highPlus.category, AudioQualityCategory.highQuality);
      expect(AudioQuality.lossless.category, AudioQualityCategory.lossless);
      expect(AudioQuality.hiRes.category, AudioQualityCategory.lossless);
      expect(AudioQuality.dolby.category, AudioQualityCategory.lossless);
      expect(AudioQuality.master.category, AudioQualityCategory.lossless);
      expect(AudioQuality.masterPlus.category, AudioQualityCategory.lossless);
    });

    test('should have category labels', () {
      expect(AudioQuality.standard.categoryLabel, '标准');
      expect(AudioQuality.high.categoryLabel, '高品质');
      expect(AudioQuality.lossless.categoryLabel, '无损');
    });

    test('should have icons', () {
      for (final quality in AudioQuality.values) {
        expect(quality.icon, isA<IconData>());
      }
    });

    test('should have colors', () {
      for (final quality in AudioQuality.values) {
        expect(quality.color, isA<Color>());
      }
    });

    test('should have gradient colors', () {
      for (final quality in AudioQuality.values) {
        expect(quality.gradientColors, isA<List<Color>>());
        expect(quality.gradientColors.length, 2);
      }
    });

    test('should have semantic labels', () {
      for (final quality in AudioQuality.values) {
        expect(quality.semanticLabel, isA<String>());
        expect(quality.semanticLabel.isNotEmpty, isTrue);
      }
      expect(AudioQuality.standard.semanticLabel, contains('128kbps'));
      expect(AudioQuality.high.semanticLabel, contains('320kbps'));
      expect(AudioQuality.lossless.semanticLabel, contains('FLAC'));
      expect(AudioQuality.hiRes.semanticLabel, contains('24位'));
      expect(AudioQuality.masterPlus.semanticLabel, contains('192'));
    });

    test('should have increasing values', () {
      const qualities = AudioQuality.values;
      for (int i = 1; i < qualities.length; i++) {
        expect(qualities[i].value, greaterThan(qualities[i - 1].value));
      }
    });

    test('should have 8 quality levels (4-14)', () {
      expect(AudioQuality.values.length, 8);
    });

    test('recommended should include all quality levels', () {
      final recommended = AudioQuality.recommended;
      expect(recommended.length, 8);
      expect(recommended.contains(AudioQuality.standard), isTrue);
      expect(recommended.contains(AudioQuality.high), isTrue);
      expect(recommended.contains(AudioQuality.lossless), isTrue);
      expect(recommended.contains(AudioQuality.masterPlus), isTrue);
    });

    test('fromName should return correct quality', () {
      expect(AudioQuality.fromName('standard'), AudioQuality.standard);
      expect(AudioQuality.fromName('high'), AudioQuality.high);
      expect(AudioQuality.fromName('lossless'), AudioQuality.lossless);
      expect(AudioQuality.fromName('masterPlus'), AudioQuality.masterPlus);
    });

    test('fromName should return default for unknown name', () {
      expect(AudioQuality.fromName('unknown'), AudioQuality.high);
    });

    test('fromValue should return correct quality', () {
      expect(AudioQuality.fromValue(4), AudioQuality.standard);
      expect(AudioQuality.fromValue(8), AudioQuality.high);
      expect(AudioQuality.fromValue(10), AudioQuality.lossless);
      expect(AudioQuality.fromValue(14), AudioQuality.masterPlus);
    });

    test('fromValue should return default for unknown value', () {
      expect(AudioQuality.fromValue(999), AudioQuality.high);
    });

    test('parse should handle enum names', () {
      expect(AudioQuality.parse('standard'), AudioQuality.standard);
      expect(AudioQuality.parse('high'), AudioQuality.high);
      expect(AudioQuality.parse('lossless'), AudioQuality.lossless);
    });

    test('parse should handle numeric strings (backward compatibility)', () {
      expect(AudioQuality.parse('4'), AudioQuality.standard);
      expect(AudioQuality.parse('8'), AudioQuality.high);
      expect(AudioQuality.parse('10'), AudioQuality.lossless);
      expect(AudioQuality.parse('14'), AudioQuality.masterPlus);
    });

    test('parse should handle legacy codes 5-7 as standard', () {
      expect(AudioQuality.parse('5'), AudioQuality.standard);
      expect(AudioQuality.parse('6'), AudioQuality.standard);
      expect(AudioQuality.parse('7'), AudioQuality.standard);
    });

    test('parse should handle legacy string aliases', () {
      expect(AudioQuality.parse('std'), AudioQuality.standard);
      expect(AudioQuality.parse('hq'), AudioQuality.high);
      expect(AudioQuality.parse('flac'), AudioQuality.lossless);
    });

    test('parse should return default for unknown input', () {
      expect(AudioQuality.parse('unknown'), AudioQuality.high);
    });

    test('isHighQuality should be true for value >= 10', () {
      expect(AudioQuality.standard.isHighQuality, isFalse);
      expect(AudioQuality.high.isHighQuality, isFalse);
      expect(AudioQuality.highPlus.isHighQuality, isFalse);
      expect(AudioQuality.lossless.isHighQuality, isTrue);
      expect(AudioQuality.hiRes.isHighQuality, isTrue);
      expect(AudioQuality.dolby.isHighQuality, isTrue);
      expect(AudioQuality.master.isHighQuality, isTrue);
      expect(AudioQuality.masterPlus.isHighQuality, isTrue);
    });

    test('fileExtension should return correct extension', () {
      expect(AudioQuality.standard.fileExtension, '.mp3');
      expect(AudioQuality.high.fileExtension, '.mp3');
      expect(AudioQuality.highPlus.fileExtension, '.mp3');
      expect(AudioQuality.lossless.fileExtension, '.flac');
      expect(AudioQuality.hiRes.fileExtension, '.flac');
      expect(AudioQuality.dolby.fileExtension, '.ec3');
      expect(AudioQuality.master.fileExtension, '.flac');
      expect(AudioQuality.masterPlus.fileExtension, '.flac');
    });

    test('getDisplayNameForCode should return correct names', () {
      expect(AudioQuality.getDisplayNameForCode(4), '标准音质');
      expect(AudioQuality.getDisplayNameForCode(5), '标准音质');
      expect(AudioQuality.getDisplayNameForCode(8), 'HQ高音质');
      expect(AudioQuality.getDisplayNameForCode(10), 'SQ无损音质');
      expect(AudioQuality.getDisplayNameForCode(14), '臻品母带2.0');
      expect(AudioQuality.getDisplayNameForCode(999), 'HQ高音质');
    });

    test('AudioQualityCategory should have 3 categories', () {
      expect(AudioQualityCategory.values.length, 3);
      expect(AudioQualityCategory.values, contains(AudioQualityCategory.standard));
      expect(AudioQualityCategory.values, contains(AudioQualityCategory.highQuality));
      expect(AudioQualityCategory.values, contains(AudioQualityCategory.lossless));
    });
  });
}
