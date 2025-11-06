import 'dart:convert';
import '../models/song.dart';
import '../utils/cache_utils.dart';
import 'preferences_cache_service.dart';
import 'playlist_scraper_service.dart';

/// 数据缓存服务
/// 统一管理应用数据的缓存逻辑
class DataCacheService {
  static final DataCacheService _instance = DataCacheService._internal();
  
  factory DataCacheService() => _instance;
  
  DataCacheService._internal();

  final _prefsCache = PreferencesCacheService();

  // 缓存键常量
  static const String _playlistsCacheKey = 'cached_playlists';
  static const String _playlistsTimestampKey = 'playlists_timestamp';
  static const String _dailySongsCacheKey = 'cached_daily_songs';
  static const String _dailySongsTimestampKey = 'daily_songs_timestamp';
  static const String _playlistDetailPrefix = 'playlist_detail_';
  static const String _playlistDetailTimestampPrefix = 'playlist_detail_ts_';
  static const String _userPlaylistsPrefix = 'user_playlists_';
  static const String _userPlaylistsTimestampPrefix = 'user_playlists_ts_';

  /// 初始化
  Future<void> init() async {
    await _prefsCache.init();
  }

  // ========== 推荐歌单缓存 ==========

  /// 保存推荐歌单
  Future<bool> saveRecommendedPlaylists(List<RecommendedPlaylist> playlists) async {
    try {
      final jsonList = playlists.map((p) => {
        'id': p.id,
        'title': p.title,
        'coverUrl': p.coverUrl,
      }).toList();
      
      final jsonString = json.encode(jsonList);
      await _prefsCache.setString(_playlistsCacheKey, jsonString);
      await _prefsCache.setInt(_playlistsTimestampKey, CacheUtils.getCurrentTimestamp());
      
      print('✅ [DataCache] 已保存 ${playlists.length} 个推荐歌单');
      return true;
    } catch (e) {
      print('❌ [DataCache] 保存推荐歌单失败: $e');
      return false;
    }
  }

  /// 获取推荐歌单
  Future<List<RecommendedPlaylist>?> getRecommendedPlaylists({int cacheHours = 24}) async {
    try {
      final timestamp = await _prefsCache.getInt(_playlistsTimestampKey) ?? 0;
      
      // 检查缓存是否过期
      if (CacheUtils.isCacheExpired(timestamp, hours: cacheHours)) {
        print('⏰ [DataCache] 推荐歌单缓存已过期');
        return null;
      }
      
      final jsonString = await _prefsCache.getString(_playlistsCacheKey);
      if (jsonString == null || jsonString.isEmpty) {
        return null;
      }
      
      final List<dynamic> jsonList = json.decode(jsonString);
      final playlists = jsonList.map((json) => RecommendedPlaylist(
        id: json['id'] as String,
        title: json['title'] as String,
        coverUrl: json['coverUrl'] as String,
      )).toList();
      
      print('✅ [DataCache] 从缓存加载 ${playlists.length} 个推荐歌单');
      return playlists;
    } catch (e) {
      print('❌ [DataCache] 获取推荐歌单失败: $e');
      return null;
    }
  }

  /// 清除推荐歌单缓存
  Future<bool> clearRecommendedPlaylists() async {
    await _prefsCache.remove(_playlistsCacheKey);
    await _prefsCache.remove(_playlistsTimestampKey);
    return true;
  }

  // ========== 每日推荐歌曲缓存 ==========

  /// 保存每日推荐歌曲
  Future<bool> saveDailySongs(List<Song> songs) async {
    try {
      final jsonList = songs.map((s) => {
        'id': s.id,
        'title': s.title,
        'artist': s.artist,
        'album': s.album,
        'coverUrl': s.coverUrl,
        'audioUrl': s.audioUrl,
        'duration': s.duration,
        'platform': s.platform,
      }).toList();
      
      final jsonString = json.encode(jsonList);
      await _prefsCache.setString(_dailySongsCacheKey, jsonString);
      await _prefsCache.setInt(_dailySongsTimestampKey, CacheUtils.getCurrentTimestamp());
      
      print('✅ [DataCache] 已保存 ${songs.length} 首每日推荐');
      return true;
    } catch (e) {
      print('❌ [DataCache] 保存每日推荐失败: $e');
      return false;
    }
  }

  /// 获取每日推荐歌曲
  Future<List<Song>?> getDailySongs({int cacheHours = 24}) async {
    try {
      final timestamp = await _prefsCache.getInt(_dailySongsTimestampKey) ?? 0;
      
      // 检查缓存是否过期
      if (CacheUtils.isCacheExpired(timestamp, hours: cacheHours)) {
        print('⏰ [DataCache] 每日推荐缓存已过期');
        return null;
      }
      
      final jsonString = await _prefsCache.getString(_dailySongsCacheKey);
      if (jsonString == null || jsonString.isEmpty) {
        return null;
      }
      
      final List<dynamic> jsonList = json.decode(jsonString);
      final songs = jsonList.map((json) => Song(
        id: json['id'] as String,
        title: json['title'] as String,
        artist: json['artist'] as String,
        album: json['album'] as String,
        coverUrl: json['coverUrl'] as String,
        audioUrl: json['audioUrl'] as String? ?? '',
        duration: json['duration'] as int? ?? 180,
        platform: json['platform'] as String? ?? 'qq',
      )).toList();
      
      print('✅ [DataCache] 从缓存加载 ${songs.length} 首每日推荐');
      return songs;
    } catch (e) {
      print('❌ [DataCache] 获取每日推荐失败: $e');
      return null;
    }
  }

  /// 清除每日推荐缓存
  Future<bool> clearDailySongs() async {
    await _prefsCache.remove(_dailySongsCacheKey);
    await _prefsCache.remove(_dailySongsTimestampKey);
    return true;
  }

  // ========== 歌单详情缓存 ==========

  /// 保存歌单详情
  Future<bool> savePlaylistDetail(String playlistId, List<Song> songs, int totalCount) async {
    try {
      final data = {
        'songs': songs.map((s) => {
          'id': s.id,
          'title': s.title,
          'artist': s.artist,
          'album': s.album,
          'coverUrl': s.coverUrl,
          'audioUrl': s.audioUrl,
          'duration': s.duration,
          'platform': s.platform,
        }).toList(),
        'totalCount': totalCount,
      };
      
      final jsonString = json.encode(data);
      await _prefsCache.setString('$_playlistDetailPrefix$playlistId', jsonString);
      await _prefsCache.setInt('$_playlistDetailTimestampPrefix$playlistId', CacheUtils.getCurrentTimestamp());
      
      print('✅ [DataCache] 已保存歌单 $playlistId 的 ${songs.length} 首歌曲');
      return true;
    } catch (e) {
      print('❌ [DataCache] 保存歌单详情失败: $e');
      return false;
    }
  }

  /// 获取歌单详情
  Future<Map<String, dynamic>?> getPlaylistDetail(String playlistId, {int cacheHours = 24}) async {
    try {
      final timestamp = await _prefsCache.getInt('$_playlistDetailTimestampPrefix$playlistId') ?? 0;
      
      // 检查缓存是否过期
      if (CacheUtils.isCacheExpired(timestamp, hours: cacheHours)) {
        print('⏰ [DataCache] 歌单 $playlistId 缓存已过期');
        return null;
      }
      
      final jsonString = await _prefsCache.getString('$_playlistDetailPrefix$playlistId');
      if (jsonString == null || jsonString.isEmpty) {
        return null;
      }
      
      final Map<String, dynamic> data = json.decode(jsonString);
      final List<dynamic> songsJson = data['songs'] as List<dynamic>;
      
      final songs = songsJson.map((json) => Song(
        id: json['id'] as String,
        title: json['title'] as String,
        artist: json['artist'] as String,
        album: json['album'] as String,
        coverUrl: json['coverUrl'] as String,
        audioUrl: json['audioUrl'] as String? ?? '',
        duration: json['duration'] as int? ?? 180,
        platform: json['platform'] as String? ?? 'qq',
      )).toList();
      
      print('✅ [DataCache] 从缓存加载歌单 $playlistId 的 ${songs.length} 首歌曲');
      
      return {
        'songs': songs,
        'totalCount': data['totalCount'] as int,
      };
    } catch (e) {
      print('❌ [DataCache] 获取歌单详情失败: $e');
      return null;
    }
  }

  /// 清除歌单详情缓存
  Future<bool> clearPlaylistDetail(String playlistId) async {
    await _prefsCache.remove('$_playlistDetailPrefix$playlistId');
    await _prefsCache.remove('$_playlistDetailTimestampPrefix$playlistId');
    return true;
  }

  /// 清除所有歌单详情缓存
  Future<bool> clearAllPlaylistDetails() async {
    try {
      final keys = await _prefsCache.getKeys();
      for (final key in keys) {
        if (key.startsWith(_playlistDetailPrefix) || key.startsWith(_playlistDetailTimestampPrefix)) {
          await _prefsCache.remove(key);
        }
      }
      print('✅ [DataCache] 已清除所有歌单详情缓存');
      return true;
    } catch (e) {
      print('❌ [DataCache] 清除歌单详情缓存失败: $e');
      return false;
    }
  }

  // ========== 用户歌单列表缓存 ==========

  /// 保存用户歌单列表
  Future<bool> saveUserPlaylists(String qqNumber, List<Map<String, dynamic>> playlists) async {
    try {
      final jsonString = json.encode(playlists);
      await _prefsCache.setString('$_userPlaylistsPrefix$qqNumber', jsonString);
      await _prefsCache.setInt('$_userPlaylistsTimestampPrefix$qqNumber', CacheUtils.getCurrentTimestamp());

      print('✅ [DataCache] 已保存用户 $qqNumber 的 ${playlists.length} 个歌单');
      return true;
    } catch (e) {
      print('❌ [DataCache] 保存用户歌单列表失败: $e');
      return false;
    }
  }

  /// 获取用户歌单列表
  Future<List<Map<String, dynamic>>?> getUserPlaylists(String qqNumber, {int cacheHours = 24}) async {
    try {
      final timestamp = await _prefsCache.getInt('$_userPlaylistsTimestampPrefix$qqNumber') ?? 0;

      // 检查缓存是否过期
      if (CacheUtils.isCacheExpired(timestamp, hours: cacheHours)) {
        print('⏰ [DataCache] 用户 $qqNumber 的歌单列表缓存已过期');
        return null;
      }

      final jsonString = await _prefsCache.getString('$_userPlaylistsPrefix$qqNumber');
      if (jsonString == null || jsonString.isEmpty) {
        return null;
      }

      final List<dynamic> jsonList = json.decode(jsonString);
      final playlists = jsonList.map((item) => Map<String, dynamic>.from(item)).toList();

      print('✅ [DataCache] 从缓存加载用户 $qqNumber 的 ${playlists.length} 个歌单');
      return playlists;
    } catch (e) {
      print('❌ [DataCache] 获取用户歌单列表失败: $e');
      return null;
    }
  }

  /// 清除用户歌单列表缓存
  Future<bool> clearUserPlaylists(String qqNumber) async {
    await _prefsCache.remove('$_userPlaylistsPrefix$qqNumber');
    await _prefsCache.remove('$_userPlaylistsTimestampPrefix$qqNumber');
    return true;
  }

  /// 清除所有用户歌单列表缓存
  Future<bool> clearAllUserPlaylists() async {
    try {
      final keys = await _prefsCache.getKeys();
      for (final key in keys) {
        if (key.startsWith(_userPlaylistsPrefix) || key.startsWith(_userPlaylistsTimestampPrefix)) {
          await _prefsCache.remove(key);
        }
      }
      print('✅ [DataCache] 已清除所有用户歌单列表缓存');
      return true;
    } catch (e) {
      print('❌ [DataCache] 清除用户歌单列表缓存失败: $e');
      return false;
    }
  }

  /// 清除所有缓存
  Future<bool> clearAll() async {
    await clearRecommendedPlaylists();
    await clearDailySongs();
    await clearAllPlaylistDetails();
    await clearAllUserPlaylists();
    print('✅ [DataCache] 已清除所有数据缓存');
    return true;
  }
}

