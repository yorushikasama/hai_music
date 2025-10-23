enum AudioQuality {
  preview(0, '试听', '音乐试听'),
  low(1, '流畅', '有损音质'),
  standard(4, '标准', '标准音质'),
  high(8, 'HQ', 'HQ高音质'),
  highPlus(9, 'HQ+', 'HQ高音质（增强）'),
  lossless(10, 'SQ', 'SQ无损音质'),
  hiRes(11, 'Hi-Res', 'Hi-Res音质'),
  dolby(12, '杜比', '杜比全景声'),
  master(13, '臻品', '臻品全景声'),
  masterPlus(14, '母带', '臻品母带2.0'),
  ai(15, 'AI伴唱', 'AI伴唱模式'),
  ai51(16, 'AI5.1', 'AI5.1音质');

  final int value;
  final String label;
  final String description;

  const AudioQuality(this.value, this.label, this.description);

  static AudioQuality fromValue(int value) {
    return AudioQuality.values.firstWhere(
      (quality) => quality.value == value,
      orElse: () => AudioQuality.high,
    );
  }

  // 推荐的音质列表（排除试听和AI模式）
  static List<AudioQuality> get recommended => [
    standard,
    high,
    highPlus,
    lossless,
    hiRes,
    dolby,
    master,
    masterPlus,
  ];
}
