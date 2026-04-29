import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hai_music/models/audio_quality.dart';
import 'package:hai_music/services/download/audio_download_service.dart';

void main() {
  group('AudioDownloadService', () {
    group('singleton', () {
      test('should be a singleton', () {
        final instance1 = AudioDownloadService();
        final instance2 = AudioDownloadService();
        expect(identical(instance1, instance2), isTrue);
      });
    });

    group('AudioDownloadResult', () {
      test('should hold file, size, url and quality', () {
        final result = AudioDownloadResult(
          sizeBytes: 1024,
          audioUrl: 'https://example.com/audio.mp3',
          quality: AudioQuality.standard,
          file: File('test.mp3'),
        );

        expect(result.sizeBytes, 1024);
        expect(result.audioUrl, 'https://example.com/audio.mp3');
        expect(result.quality, AudioQuality.standard);
      });
    });
  });
}
