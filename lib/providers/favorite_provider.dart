import 'package:flutter/foundation.dart';

import '../models/favorite_song.dart';
import '../models/song.dart';
import '../service_locator.dart';
import '../services/favorite/favorite_manager_service.dart';
import '../services/core/preferences_service.dart';
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

  Future<void> _loadFavorites() async {
    final favorites = await _prefs.getFavorites();
    _favoriteSongIds.clear();
    _favoriteSongIds.addAll(favorites);
    notifyListeners();
  }

  Future<void> refreshFavorites() async {
    await _loadFavorites();
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

    if (wasFavorite) {
      _favoriteSongIds.remove(songId);
    } else {
      _favoriteSongIds.add(songId);
    }

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
    }

    notifyListeners();
    return success;
  }

  /// 批量移除收藏，返回成功/失败统计
  Future<BatchFavoriteResult> removeFavorites(List<String> songIds) async {
    // 乐观更新：先从本地集合中移除
    final wasFavorites = <String, bool>{};
    for (final id in songIds) {
      wasFavorites[id] = _favoriteSongIds.contains(id);
      _favoriteSongIds.remove(id);
    }
    _favoriteSongs.removeWhere((f) => songIds.contains(f.id));
    notifyListeners();

    final result = await _favoriteManager.removeFavorites(songIds);

    // 如果有失败的，回滚
    if (!result.allSuccess) {
      for (final id in result.failedIds) {
        if (wasFavorites[id] == true) {
          _favoriteSongIds.add(id);
        }
      }
      // 重新加载完整列表以保证一致性
      await loadFavoriteSongs(forceRefresh: true);
    }

    return result;
  }

  @override
  void dispose() {
    super.dispose();
  }
}
