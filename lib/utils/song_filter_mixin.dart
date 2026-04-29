mixin SongFilterMixin {
  bool matchesQuery({
    required String title,
    required String artist,
    required String album,
    required String query,
  }) {
    if (query.isEmpty) return true;
    final lowerQuery = query.toLowerCase();
    return title.toLowerCase().contains(lowerQuery) ||
        artist.toLowerCase().contains(lowerQuery) ||
        album.toLowerCase().contains(lowerQuery);
  }
}
