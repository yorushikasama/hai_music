import 'dart:convert';

import '../models/song.dart';
import '../utils/cache_utils.dart';
import '../utils/logger.dart';
import 'playlist_scraper_service.dart';
import 'preferences_service.dart';

class DataCacheService {
  static final DataCacheService _instance = DataCacheService._internal();

  factory DataCacheService() => _instance;

  DataCacheService._internal();

  final _prefsCache = PreferencesService();

  static const String _playlistsCacheKey = 'cached_playlists';
  static const String _playlistsTimestampKey = 'playlists_timestamp';
  static const String _dailySongsCacheKey = 'cached_daily_songs';
  static const String _dailySongsTimestampKey = 'daily_songs_timestamp';
  static const String _playlistDetailPrefix = 'playlist_detail_';
  static const String _playlistDetailTimestampPrefix = 'playlist_detail_ts_';
  static const String _userPlaylistsPrefix = 'user_playlists_';
  static const String _userPlaylistsTimestampPrefix = 'user_playlists_ts_';

  Future<void> init() async {
    await _prefsCache.init();
  }

  Future<bool> _saveJson(String key, String timestampKey, Object data) async {
    try {
      final jsonString = json.encode(data);
      await _prefsCache.setString(key, jsonString);
      await _prefsCache.setInt(timestampKey, CacheUtils.getCurrentTimestamp());
      return true;
    } catch (e) {
      Logger.error('保存缓存失败: $key', e, null, 'DataCache');
      return false;
    }
  }

  Future<T?> _loadJson<T>(
    String key,
    String timestampKey,
    T? Function(Map<String, dynamic>) fromJson, {
    int cacheHours = 24,
  }) async {
    try {
      final timestamp = await _prefsCache.getInt(timestampKey) ?? 0;

      if (CacheUtils.isCacheExpired(timestamp, hours: cacheHours)) {
        return null;
      }

      final jsonString = await _prefsCache.getString(key);
      if (jsonString == null || jsonString.isEmpty) return null;

      final decoded = json.decode(jsonString);
      if (decoded is Map<String, dynamic>) {
        return fromJson(decoded);
      }
      return null;
    } catch (e) {
      Logger.error('加载缓存失败: $key', e, null, 'DataCache');
      return null;
    }
  }

  Future<bool> saveRecommendedPlaylists(List<RecommendedPlaylist> playlists) async {
    final jsonList = playlists
        .map((p) => {
              'id': p.id,
              'title': p.title,
              'coverUrl': p.coverUrl,
            })
        .toList();
    final result = await _saveJson(_playlistsCacheKey, _playlistsTimestampKey, jsonList);
    if (result) Logger.cache('已保存 ${playlists.length} 个推荐歌单', 'DataCache');
    return result;
  }

  Future<List<RecommendedPlaylist>?> getRecommendedPlaylists({int cacheHours = 24}) async {
    final result = await _loadJson<List<RecommendedPlaylist>>(
      _playlistsCacheKey,
      _playlistsTimestampKey,
      (data) {
        final List<dynamic> jsonList = data['items'] as List<dynamic>? ?? [];
        return jsonList
            .map((json) => RecommendedPlaylist(
                  id: json['id'] as String,
                  title: json['title'] as String,
                  coverUrl: json['coverUrl'] as String,
                ))
            .toList();
      },
      cacheHours: cacheHours,
    );

    if (result == null) {
      try {
        final timestamp = await _prefsCache.getInt(_playlistsTimestampKey) ?? 0;
        if (!CacheUtils.isCacheExpired(timestamp, hours: cacheHours)) {
          final jsonString = await _prefsCache.getString(_playlistsCacheKey);
          if (jsonString != null && jsonString.isNotEmpty) {
            final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
            final playlists = jsonList
                .map((json) => RecommendedPlaylist(
                      id: json['id'] as String,
                      title: json['title'] as String,
                      coverUrl: json['coverUrl'] as String,
                    ))
                .toList();
            Logger.cache('从缓存加载 ${playlists.length} 个推荐歌单', 'DataCache');
            return playlists;
          }
        }
      } catch (e) {
        Logger.debug('缓存回退读取失败', 'DataCache');
      }
      return null;
    }
    Logger.cache('从缓存加载 ${result.length} 个推荐歌单', 'DataCache');
    return result;
  }

  Future<bool> clearRecommendedPlaylists() async {
    await _prefsCache.remove(_playlistsCacheKey);
    await _prefsCache.remove(_playlistsTimestampKey);
    return true;
  }

  Future<bool> saveDailySongs(List<Song> songs) async {
    final jsonList = songs.map((s) => s.toJson()).toList();
    final result = await _saveJson(_dailySongsCacheKey, _dailySongsTimestampKey, jsonList);
    if (result) Logger.cache('已保存 ${songs.length} 首每日推荐', 'DataCache');
    return result;
  }

  Future<List<Song>?> getDailySongs({int cacheHours = 24}) async {
    try {
      final timestamp = await _prefsCache.getInt(_dailySongsTimestampKey) ?? 0;
      if (CacheUtils.isCacheExpired(timestamp, hours: cacheHours)) {
        Logger.cache('每日推荐缓存已过期', 'DataCache');
        return null;
      }

      final jsonString = await _prefsCache.getString(_dailySongsCacheKey);
      if (jsonString == null || jsonString.isEmpty) return null;

      final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
      final songs = jsonList.map((json) => Song.fromJson(json as Map<String, dynamic>)).toList();
      Logger.cache('从缓存加载 ${songs.length} 首每日推荐', 'DataCache');
      return songs;
    } catch (e) {
      Logger.error('获取每日推荐失败', e, null, 'DataCache');
      return null;
    }
  }

  Future<bool> savePlaylistDetail(String playlistId, List<Song> songs, int totalCount) async {
    final data = {
      'songs': songs.map((s) => s.toJson()).toList(),
      'totalCount': totalCount,
    };
    final result = await _saveJson(
      '$_playlistDetailPrefix$playlistId',
      '$_playlistDetailTimestampPrefix$playlistId',
      data,
    );
    if (result) Logger.cache('已保存歌单 $playlistId 的 ${songs.length} 首歌曲', 'DataCache');
    return result;
  }

  Future<Map<String, dynamic>?> getPlaylistDetail(String playlistId, {int cacheHours = 24}) async {
    try {
      final timestamp = await _prefsCache.getInt('$_playlistDetailTimestampPrefix$playlistId') ?? 0;
      if (CacheUtils.isCacheExpired(timestamp, hours: cacheHours)) {
        Logger.cache('歌单 $playlistId 缓存已过期', 'DataCache');
        return null;
      }

      final jsonString = await _prefsCache.getString('$_playlistDetailPrefix$playlistId');
      if (jsonString == null || jsonString.isEmpty) return null;

      final Map<String, dynamic> data = json.decode(jsonString) as Map<String, dynamic>;
      final List<dynamic> songsJson = data['songs'] as List<dynamic>;
      final songs = songsJson.map((json) => Song.fromJson(json as Map<String, dynamic>)).toList();

      Logger.cache('从缓存加载歌单 $playlistId 的 ${songs.length} 首歌曲', 'DataCache');
      return {'songs': songs, 'totalCount': data['totalCount'] as int};
    } catch (e) {
      Logger.error('获取歌单详情失败', e, null, 'DataCache');
      return null;
    }
  }

  Future<bool> saveUserPlaylists(String qqNumber, List<Map<String, dynamic>> playlists) async {
    final result = await _saveJson(
      '$_userPlaylistsPrefix$qqNumber',
      '$_userPlaylistsTimestampPrefix$qqNumber',
      playlists,
    );
    if (result) Logger.cache('已保存用户 $qqNumber 的 ${playlists.length} 个歌单', 'DataCache');
    return result;
  }

  Future<List<Map<String, dynamic>>?> getUserPlaylists(String qqNumber, {int cacheHours = 24}) async {
    try {
      final timestamp = await _prefsCache.getInt('$_userPlaylistsTimestampPrefix$qqNumber') ?? 0;
      if (CacheUtils.isCacheExpired(timestamp, hours: cacheHours)) {
        Logger.cache('用户 $qqNumber 的歌单列表缓存已过期', 'DataCache');
        return null;
      }

      final jsonString = await _prefsCache.getString('$_userPlaylistsPrefix$qqNumber');
      if (jsonString == null || jsonString.isEmpty) return null;

      final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
      final playlists = jsonList.map((item) => Map<String, dynamic>.from(item as Map<dynamic, dynamic>)).toList();
      Logger.cache('从缓存加载用户 $qqNumber 的 ${playlists.length} 个歌单', 'DataCache');
      return playlists;
    } catch (e) {
      Logger.error('获取用户歌单列表失败', e, null, 'DataCache');
      return null;
    }
  }

  Future<void> clearAllCache() async {
    try {
      await _prefsCache.init();
      final keys = await _prefsCache.getKeys();
      final cacheKeys = keys.where((k) =>
          k.startsWith('cached_') ||
          k.startsWith('playlist_detail_') ||
          k.startsWith('playlist_detail_ts_') ||
          k.startsWith('user_playlists_') ||
          k.startsWith('user_playlists_ts_') ||
          k.endsWith('_timestamp'));
      for (final key in cacheKeys) {
        await _prefsCache.remove(key);
      }
      Logger.cache('已清理所有数据缓存', 'DataCache');
    } catch (e) {
      Logger.error('清理缓存失败', e, null, 'DataCache');
    }
  }
}
