import 'package:flutter_test/flutter_test.dart';
import 'package:hai_music/models/play_mode.dart';

void main() {
  group('PlayMode', () {
    test('should have correct labels', () {
      expect(PlayMode.sequence.label, '顺序播放');
      expect(PlayMode.single.label, '单曲循环');
      expect(PlayMode.shuffle.label, '随机播放');
    });

    test('should have correct icon names', () {
      expect(PlayMode.sequence.iconName, 'Icons.repeat');
      expect(PlayMode.single.iconName, 'Icons.repeat_one');
      expect(PlayMode.shuffle.iconName, 'Icons.shuffle');
    });

    test('should cycle through modes correctly', () {
      expect(PlayMode.sequence.next, PlayMode.single);
      expect(PlayMode.single.next, PlayMode.shuffle);
      expect(PlayMode.shuffle.next, PlayMode.sequence);
    });

    test('should form a complete cycle', () {
      PlayMode current = PlayMode.sequence;
      current = current.next;
      current = current.next;
      current = current.next;
      expect(current, PlayMode.sequence);
    });
  });
}
