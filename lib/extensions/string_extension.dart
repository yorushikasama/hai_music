/// String 扩展方法
extension StringExtension on String {
  /// 是否为空或null
  bool get isNullOrEmpty => isEmpty;

  /// 是否不为空
  bool get isNotNullOrEmpty => isNotEmpty;

  /// 是否为有效的URL
  bool get isValidUrl {
    if (isEmpty) return false;
    return startsWith('http://') || startsWith('https://');
  }

  /// 是否为有效的歌曲ID
  bool get isValidSongId {
    if (isEmpty) return false;
    return length > 3 && !contains(' ');
  }

  /// 截断字符串到指定长度
  String truncate(int maxLength, {String suffix = '...'}) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength - suffix.length)}$suffix';
  }

  /// 移除所有空白字符
  String removeWhitespace() {
    return replaceAll(RegExp(r'\s+'), '');
  }

  /// 首字母大写
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  /// 每个单词首字母大写
  String capitalizeWords() {
    if (isEmpty) return this;
    return split(' ').map((word) => word.capitalize()).join(' ');
  }

  /// 转换为文件名安全的字符串
  String toSafeFileName() {
    return replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
  }

  /// 解析时长字符串（如 "3:45" -> Duration）
  Duration? toDuration() {
    try {
      final parts = split(':');
      if (parts.length == 2) {
        final minutes = int.parse(parts[0]);
        final seconds = int.parse(parts[1]);
        return Duration(minutes: minutes, seconds: seconds);
      } else if (parts.length == 3) {
        final hours = int.parse(parts[0]);
        final minutes = int.parse(parts[1]);
        final seconds = int.parse(parts[2]);
        return Duration(hours: hours, minutes: minutes, seconds: seconds);
      }
    } catch (_) {}
    return null;
  }

  /// 高亮搜索关键词
  String highlightKeyword(String keyword, {String startTag = '<mark>', String endTag = '</mark>'}) {
    if (keyword.isEmpty) return this;
    return replaceAllMapped(
      RegExp(keyword, caseSensitive: false),
      (match) => '$startTag${match.group(0)}$endTag',
    );
  }

  /// 移除HTML标签
  String removeHtmlTags() {
    return replaceAll(RegExp(r'<[^>]*>'), '');
  }

  /// 是否包含中文字符
  bool get containsChinese {
    return RegExp(r'[\u4e00-\u9fa5]').hasMatch(this);
  }

  /// 获取字符串的字节长度（中文算2个字节）
  int get byteLength {
    int length = 0;
    for (int i = 0; i < this.length; i++) {
      final code = codeUnitAt(i);
      if (code > 127) {
        length += 2;
      } else {
        length += 1;
      }
    }
    return length;
  }
}

/// 可空 String 扩展
extension NullableStringExtension on String? {
  /// 是否为空或null
  bool get isNullOrEmpty => this == null || this!.isEmpty;

  /// 是否不为空
  bool get isNotNullOrEmpty => this != null && this!.isNotEmpty;

  /// 获取值或默认值
  String orDefault(String defaultValue) => this ?? defaultValue;

  /// 获取值或空字符串
  String get orEmpty => this ?? '';
}
