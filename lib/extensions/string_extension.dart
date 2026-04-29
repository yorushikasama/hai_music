extension StringExtension on String {
  String toSafeFileName() {
    return replaceAll(RegExp(r'[<>:"/\\|?*]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String toTruncated({int maxLength = 200}) {
    if (length <= maxLength) return this;
    return substring(0, maxLength);
  }
}

extension NullableStringExtension on String? {
  bool get isNullOrEmpty => this == null || this!.isEmpty;
  bool get isNotNullOrEmpty => this != null && this!.isNotEmpty;
}
