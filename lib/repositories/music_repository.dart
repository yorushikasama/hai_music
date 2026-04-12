import '../models/song.dart';
import '../services/data_cache_service.dart';
import '../services/music_api_service.dart';
import '../utils/logger.dart';
import '../utils/result.dart';

class MusicRepository {
  final MusicApiService _apiService;
  final DataCacheService _cacheService;

  MusicRepository({
    MusicApiService? apiService,
    DataCacheService? cacheService,
  }) : _apiService = apiService ?? MusicApiService(),
       _cacheService = cacheService ?? DataCacheService();

  Future<Result<List<Song>>> searchSongs({
    required String keyword,
    int limit = 30,
    int page = 1,
  }) async {
    return _apiService.searchSongs(keyword: keyword, limit: limit, page: page);
  }

  Future<Map<String, dynamic>> getPlaylistSongs({required String playlistId}) async {
    final cached = await _cacheService.getPlaylistDetail(playlistId);
    if (cached != null) {
      Logger.debug('使用缓存的歌单详情: $playlistId', 'MusicRepository');
      return cached;
    }

    final result = await _apiService.getPlaylistSongs(playlistId: playlistId);

    if (result['songs'] != null) {
      await _cacheService.savePlaylistDetail(
        playlistId,
        result['songs'] as List<Song>,
        result['total'] as int? ?? 0,
      );
    }

    return result;
  }

  Future<List<Song>?> getDailySongs() async {
    final cached = await _cacheService.getDailySongs();
    if (cached != null) {
      return cached;
    }

    return null;
  }

  Future<bool> saveDailySongs(List<Song> songs) async {
    return _cacheService.saveDailySongs(songs);
  }

  Future<String?> getLyrics({String? songId, String? songMid}) async {
    return _apiService.getLyrics(songId: songId, songMid: songMid);
  }

  Future<Map<String, String?>?> getLyricsWithTranslation({String? songId, String? songMid}) async {
    return _apiService.getLyricsWithTranslation(songId: songId, songMid: songMid);
  }
}
