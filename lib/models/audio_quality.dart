import 'package:flutter/material.dart';

enum AudioQualityCategory { standard, highQuality, lossless }

enum AudioQuality {
  standard(
    4,
    '标准',
    '标准音质',
    bitrate: '128kbps',
    category: AudioQualityCategory.standard,
    icon: Icons.music_note,
    color: Color(0xFF9E9E9E),
    gradientColors: [Color(0xFF9E9E9E), Color(0xFF757575)],
    semanticLabel: '标准音质，128kbps MP3格式',
  ),
  high(
    8,
    'HQ',
    'HQ高音质',
    bitrate: '320kbps',
    category: AudioQualityCategory.highQuality,
    icon: Icons.graphic_eq,
    color: Color(0xFF4CAF50),
    gradientColors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
    semanticLabel: 'HQ高音质，320kbps MP3格式',
  ),
  highPlus(
    9,
    'HQ+',
    'HQ高音质（增强）',
    bitrate: '320kbps+',
    category: AudioQualityCategory.highQuality,
    icon: Icons.graphic_eq,
    color: Color(0xFF2196F3),
    gradientColors: [Color(0xFF2196F3), Color(0xFF1565C0)],
    semanticLabel: 'HQ增强音质，320kbps以上MP3格式',
  ),
  lossless(
    10,
    'SQ',
    'SQ无损音质',
    bitrate: 'FLAC',
    category: AudioQualityCategory.lossless,
    icon: Icons.workspace_premium,
    color: Color(0xFFFF9800),
    gradientColors: [Color(0xFFFF9800), Color(0xFFE65100)],
    semanticLabel: 'SQ无损音质，FLAC格式',
  ),
  hiRes(
    11,
    'Hi-Res',
    'Hi-Res音质',
    bitrate: '24bit/96kHz',
    category: AudioQualityCategory.lossless,
    icon: Icons.headphones,
    color: Color(0xFFE91E63),
    gradientColors: [Color(0xFFE91E63), Color(0xFFAD1457)],
    semanticLabel: 'Hi-Res高解析音质，24位96千赫兹',
  ),
  dolby(
    12,
    '杜比',
    '杜比全景声',
    bitrate: 'Dolby Atmos',
    category: AudioQualityCategory.lossless,
    icon: Icons.surround_sound,
    color: Color(0xFF9C27B0),
    gradientColors: [Color(0xFF9C27B0), Color(0xFF6A1B9A)],
    semanticLabel: '杜比全景声音质',
  ),
  master(
    13,
    '臻品',
    '臻品全景声',
    bitrate: '360 Reality Audio',
    category: AudioQualityCategory.lossless,
    icon: Icons.auto_awesome,
    color: Color(0xFF00BCD4),
    gradientColors: [Color(0xFF00BCD4), Color(0xFF00838F)],
    semanticLabel: '臻品全景声音质，360 Reality Audio',
  ),
  masterPlus(
    14,
    '母带',
    '臻品母带2.0',
    bitrate: '24bit/192kHz',
    category: AudioQualityCategory.lossless,
    icon: Icons.diamond,
    color: Color(0xFFFFD700),
    gradientColors: [Color(0xFFFFD700), Color(0xFFFF8F00)],
    semanticLabel: '臻品母带2.0音质，24位192千赫兹',
  );

  final int value;
  final String label;
  final String description;
  final String bitrate;
  final AudioQualityCategory category;
  final IconData icon;
  final Color color;
  final List<Color> gradientColors;
  final String semanticLabel;

  const AudioQuality(
    this.value,
    this.label,
    this.description, {
    required this.bitrate,
    required this.category,
    required this.icon,
    required this.color,
    required this.gradientColors,
    required this.semanticLabel,
  });

  static List<AudioQuality> get recommended => values;

  static AudioQuality fromName(String name) {
    return AudioQuality.values.firstWhere(
      (q) => q.name == name,
      orElse: () => AudioQuality.high,
    );
  }

  static AudioQuality fromValue(int value) {
    return AudioQuality.values.firstWhere(
      (q) => q.value == value,
      orElse: () => AudioQuality.high,
    );
  }

  static AudioQuality parse(String qualityString) {
    final trimmed = qualityString.trim();

    final byName = AudioQuality.values.firstWhere(
      (q) => q.name == trimmed,
      orElse: () => AudioQuality.high,
    );
    if (byName.name == trimmed) return byName;

    final value = int.tryParse(trimmed);
    if (value != null) {
      if (value >= 4 && value <= 7) return AudioQuality.standard;
      return fromValue(value);
    }

    switch (trimmed.toLowerCase()) {
      case 'std':
        return AudioQuality.standard;
      case 'hq':
        return AudioQuality.high;
      case 'flac':
        return AudioQuality.lossless;
    }

    return AudioQuality.high;
  }

  static String getDisplayNameForCode(int code) {
    if (code >= 4 && code <= 7) return AudioQuality.standard.description;
    return fromValue(code).description;
  }

  bool get isHighQuality => value >= 10;

  String get categoryLabel {
    switch (category) {
      case AudioQualityCategory.standard:
        return '标准';
      case AudioQualityCategory.highQuality:
        return '高品质';
      case AudioQualityCategory.lossless:
        return '无损';
    }
  }

  String get fileExtension {
    switch (this) {
      case AudioQuality.standard:
      case AudioQuality.high:
      case AudioQuality.highPlus:
        return '.mp3';
      case AudioQuality.lossless:
      case AudioQuality.hiRes:
      case AudioQuality.master:
      case AudioQuality.masterPlus:
        return '.flac';
      case AudioQuality.dolby:
        return '.ec3';
    }
  }
}
