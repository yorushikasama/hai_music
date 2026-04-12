import 'package:flutter/foundation.dart';

import '../models/favorite_song.dart';
import '../models/song.dart';
import '../service_locator.dart';
import '../services/favorite_manager_service.dart';
import '../services/preferences_service.dart';
import '../utils/logger.dart';

class FavoriteProvider extends ChangeNotifier {
  final FavoriteManagerService _favoriteManager;
  final PreferencesService _prefs;

  final Set<String> _favoriteSongIds = <String>{};
  List<FavoriteSong> _favoriteSongs = [];
  bool _isFavoritesLoaded = false;

  FavoriteManagerService get favoriteManager => _favoriteManager;

  List<FavoriteSong> get favoriteSongs => List.unmodifiable(_favoriteSongs);

  bool get isFavoritesLoaded => _isFavoritesLoaded;

  FavoriteProvider({
    FavoriteManagerService? favoriteManager,
    PreferencesService? prefs,
  }) : _favoriteManager = favoriteManager ?? locator.favoriteManagerService,
       _prefs = prefs ?? locator.preferencesService {
    _loadFavorites();
  }

  void _loadFavorites() {
    final favorites = _prefs.getFavoriteSongs();
    _favoriteSongIds.clear();
    _favoriteSongIds.addAll(favorites);
    notifyListeners();
  }

  void refreshFavorites() {
    _loadFavorites();
  }

  bool isFavorite(String songId) {
    return _favoriteSongIds.contains(songId);
  }

  bool isFavoriteOperationInProgress(String songId) {
    return _favoriteManager.isOperationInProgress(songId);
  }

  Future<void> loadFavoriteSongs({bool forceRefresh = false}) async {
    if (_isFavoritesLoaded && !forceRefresh) return;

    try {
      final favorites = await _favoriteManager.getFavorites();
      _favoriteSongs = favorites;
      _isFavoritesLoaded = true;

      _favoriteSongIds.clear();
      _favoriteSongIds.addAll(favorites.map((f) => f.id));
      notifyListeners();
    } catch (e) {
      Logger.error('加载收藏歌曲列表失败', e, null, 'FavoriteProvider');
    }
  }

  Future<void> refreshFavoriteSongs() async {
    await loadFavoriteSongs(forceRefresh: true);
  }

  Future<bool> toggleFavorite(String songId, {Song? currentSong, List<Song>? playlist}) async {
    final wasFavorite = _favoriteSongIds.contains(songId);

    _favoriteSongIds.add(songId);
    if (wasFavorite) {
      _favoriteSongIds.remove(songId);
    }
    notifyListeners();

    final success = await _favoriteManager.toggleFavorite(
      songId,
      currentSong,
      playlist ?? [],
    );

    if (!success) {
      if (wasFavorite) {
        _favoriteSongIds.add(songId);
      } else {
        _favoriteSongIds.remove(songId);
      }
      notifyListeners();
    } else {
      if (wasFavorite) {
        _favoriteSongs.removeWhere((f) => f.id == songId);
      } else if (currentSong != null) {
        _favoriteSongs.insert(0, FavoriteSong(
          id: currentSong.id,
          title: currentSong.title,
          artist: currentSong.artist,
          album: currentSong.album,
          coverUrl: currentSong.coverUrl,
          duration: currentSong.duration,
          platform: currentSong.platform,
          lyricsLrc: currentSong.lyricsLrc,
        ));
      }
      notifyListeners();
    }

    return success;
  }

  @override
  void dispose() {
    super.dispose();
  }
}
