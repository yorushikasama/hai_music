import 'package:flutter/material.dart';

enum PlaybackSpeed {
  x0_5(0.5, '0.5x', Icons.speed),
  x0_75(0.75, '0.75x', Icons.speed),
  x1_0(1.0, '1.0x', Icons.speed),
  x1_25(1.25, '1.25x', Icons.speed),
  x1_5(1.5, '1.5x', Icons.speed),
  x1_75(1.75, '1.75x', Icons.speed),
  x2_0(2.0, '2.0x', Icons.speed),
  x3_0(3.0, '3.0x', Icons.speed);

  final double value;
  final String label;
  final IconData icon;

  const PlaybackSpeed(this.value, this.label, this.icon);

  static PlaybackSpeed fromValue(double value) {
    return PlaybackSpeed.values.firstWhere(
      (speed) => (speed.value - value).abs() < 0.01,
      orElse: () => PlaybackSpeed.x1_0,
    );
  }

  static List<double> get presetValues =>
      PlaybackSpeed.values.map((s) => s.value).toList();

  bool get isNormal => value == 1.0;

  String get displayLabel => isNormal ? '倍速' : label;

  String get semanticLabel => isNormal ? '正常速度' : '$label 倍速';
}
