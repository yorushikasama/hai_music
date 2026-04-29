import '../models/song.dart';
import '../services/cache/data_cache_service.dart';
import '../services/lyrics/lyrics_loading_service.dart';
import '../services/network/music_api_service.dart';
import '../services/network/network.dart';
import '../services/network/playlist_scraper_service.dart';
import '../utils/result.dart';

/// 音乐数据仓库，统一管理 API 请求与缓存策略
///
/// 作为数据层的统一入口，封装 API 调用、缓存读写和数据转换逻辑，
/// 屏蔽底层数据源细节，供 ViewModel/Provider 层直接调用。
class MusicRepository {
  final MusicApiService _apiService;
  final DataCacheService _cacheService;
  final PlaylistScraperService _scraperService;

  MusicRepository({
    MusicApiService? apiService,
    DataCacheService? cacheService,
    PlaylistScraperService? scraperService,
  }) : _apiService = apiService ?? MusicApiService(),
       _cacheService = cacheService ?? DataCacheService(),
       _scraperService = scraperService ?? PlaylistScraperService();

  /// 搜索歌曲
  Future<Result<List<Song>>> searchSongs({
    required String keyword,
    int limit = 30,
    int page = 1,
  }) async {
    return _apiService.searchSongs(keyword: keyword, limit: limit, page: page);
  }

  /// 获取歌单歌曲（带缓存）
  Future<Map<String, dynamic>> getPlaylistSongs({required String playlistId}) async {
    final cached = await _cacheService.getPlaylistDetail(playlistId);
    if (cached != null) {
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

  /// 获取歌单歌曲（分页加载，不使用缓存）
  Future<Map<String, dynamic>> fetchPlaylistSongs({
    required String playlistId,
    int page = 1,
    int num = 60,
    String? uin,
  }) async {
    return _apiService.getPlaylistSongs(
      playlistId: playlistId,
      page: page,
      num: num,
      uin: uin,
    );
  }

  // ── 每日推荐 ──

  /// 获取缓存的每日推荐歌曲
  Future<List<Song>?> getDailySongs({int cacheHours = 24}) async {
    return _cacheService.getDailySongs(cacheHours: cacheHours);
  }

  /// 保存每日推荐歌曲到缓存
  Future<bool> saveDailySongs(List<Song> songs) async {
    return _cacheService.saveDailySongs(songs);
  }

  // ── 推荐歌单 ──

  /// 获取缓存的推荐歌单
  Future<List<RecommendedPlaylist>?> getRecommendedPlaylists({int cacheHours = 24}) async {
    return _cacheService.getRecommendedPlaylists(cacheHours: cacheHours);
  }

  /// 保存推荐歌单到缓存
  Future<bool> saveRecommendedPlaylists(List<RecommendedPlaylist> playlists) async {
    return _cacheService.saveRecommendedPlaylists(playlists);
  }

  /// 清除推荐歌单缓存
  Future<bool> clearRecommendedPlaylists() async {
    return _cacheService.clearRecommendedPlaylists();
  }

  /// 从网络获取推荐歌单
  Future<List<RecommendedPlaylist>> fetchRecommendedPlaylists() async {
    return _scraperService.fetchRecommendedPlaylists();
  }

  /// 获取用户歌单（从API获取，用于刷新）
  Future<List<Map<String, dynamic>>> fetchUserPlaylists(String qqNumber) async {
    return _apiService.getUserPlaylists(qqNumber: qqNumber);
  }

  // ── 用户歌单 ──

  /// 获取缓存的用户歌单（按 QQ 号）
  Future<List<Map<String, dynamic>>?> getUserPlaylists(String qqNumber, {int cacheHours = 24}) async {
    return _cacheService.getUserPlaylists(qqNumber, cacheHours: cacheHours);
  }

  /// 保存用户歌单到缓存
  Future<bool> saveUserPlaylists(String qqNumber, List<Map<String, dynamic>> playlists) async {
    return _cacheService.saveUserPlaylists(qqNumber, playlists);
  }

  // ── 歌单详情 ──

  /// 获取缓存的歌单详情
  Future<Map<String, dynamic>?> getPlaylistDetail(String playlistId, {int cacheHours = 24}) async {
    return _cacheService.getPlaylistDetail(playlistId, cacheHours: cacheHours);
  }

  /// 保存歌单详情到缓存
  Future<bool> savePlaylistDetail(String playlistId, List<Song> songs, int totalCount) async {
    return _cacheService.savePlaylistDetail(playlistId, songs, totalCount);
  }

  // ── 歌词 ──

  /// 获取歌词原文
  Future<String?> getLyrics({String? songId, String? songMid}) async {
    return _apiService.getLyrics(songId: songId, songMid: songMid);
  }

  /// 获取歌词原文及翻译
  Future<Map<String, String?>?> getLyricsWithTranslation({String? songId, String? songMid}) async {
    return _apiService.getLyricsWithTranslation(songId: songId, songMid: songMid);
  }

  /// 加载歌词（多源获取，包含本地优先）
  Future<LyricsResult?> loadLyrics(Song song) async {
    return LyricsLoadingService().loadLyrics(song);
  }
}
