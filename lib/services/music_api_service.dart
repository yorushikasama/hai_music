import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song.dart';
import '../config/app_constants.dart';
import 'dio_client.dart';

/// 音乐API服务类
/// 支持多个音乐平台的搜索和播放功能
class MusicApiService {
  // API基础URL - 可以根据需要切换不同的API服务
  static const String _baseUrl = 'https://api.injahow.cn';
  final _dioClient = DioClient();
  
  /// 搜索歌曲（使用点歌API - 返回列表）
  /// 
  /// [keyword] 搜索关键词（歌曲名或歌手名）
  /// [limit] 返回结果数量限制，默认30，最大60
  /// [page] 页码，默认1
  Future<List<Song>> searchSongs({
    required String keyword,
    int limit = 30,
    int page = 1,
  }) async {
    try {
      // 使用点歌API搜索（返回列表）
      final response = await _dioClient.get(
        AppConstants.searchApiUrl,
        queryParameters: {
          'word': keyword,
          'num': limit.clamp(1, AppConstants.maxSearchResults),
          'page': page,
        },
      );
      
      if (response.statusCode == 200) {
        final data = response.data;
        if (data['code'] == 200 && data['data'] != null) {
          // 点歌API返回的是数组
          final List<dynamic> songList = data['data'] is List 
              ? data['data'] 
              : [data['data']];
          
          return songList.map((item) {
            return Song(
              id: item['id']?.toString() ?? '',
              title: item['song'] ?? '未知歌曲',
              artist: item['singer'] ?? '未知歌手',
              album: item['album'] ?? '未知专辑',
              coverUrl: item['cover'] ?? '',
              audioUrl: item['url'] ?? '', // 点歌API直接返回播放链接！
              duration: _parseDuration(item['interval']),
              platform: 'qq',
            );
          }).toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }
  
  /// 解析时长字符串（如 "3分30秒" -> Duration）
  Duration _parseDuration(String? interval) {
    if (interval == null || interval.isEmpty) return Duration.zero;
    
    try {
      // 匹配 "3分30秒" 格式
      final minuteMatch = RegExp(r'(\d+)分').firstMatch(interval);
      final secondMatch = RegExp(r'(\d+)秒').firstMatch(interval);
      
      final minutes = minuteMatch != null ? int.parse(minuteMatch.group(1)!) : 0;
      final seconds = secondMatch != null ? int.parse(secondMatch.group(1)!) : 0;
      
      return Duration(minutes: minutes, seconds: seconds);
    } catch (e) {
      return Duration.zero;
    }
  }
  
  /// 获取歌词(带缓存,7天过期)
  /// 
  /// [songId] 歌曲ID
  /// [songMid] 歌曲MID（id和mid二选一）
  Future<String?> getLyrics({
    String? songId,
    String? songMid,
  }) async {
    try {
      // 确定缓存key
      String cacheKey;
      String timestampKey;
      if (songId != null && songId.isNotEmpty) {
        cacheKey = 'lyric_$songId';
        timestampKey = 'lyric_time_$songId';
      } else if (songMid != null && songMid.isNotEmpty) {
        cacheKey = 'lyric_mid_$songMid';
        timestampKey = 'lyric_time_mid_$songMid';
      } else {
        return null;
      }
      
      // 检查缓存
      final prefs = await SharedPreferences.getInstance();
      final cachedLyric = prefs.getString(cacheKey);
      final cachedTimestamp = prefs.getInt(timestampKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // 检查缓存是否过期(7天)
      final cacheExpired = (now - cachedTimestamp) > 7 * 24 * 60 * 60 * 1000;
      
      if (cachedLyric != null && cachedLyric.isNotEmpty && !cacheExpired) {
        return cachedLyric;
      }
      
      // 缓存未命中,从API获取
      Map<String, dynamic> queryParams = {};
      
      if (songId != null && songId.isNotEmpty) {
        queryParams['id'] = songId;
      } else if (songMid != null && songMid.isNotEmpty) {
        queryParams['mid'] = songMid;
      }
      
      final response = await _dioClient.get(
        'https://api.vkeys.cn/v2/music/tencent/lyric',
        queryParameters: queryParams,
      );
      
      if (response.statusCode == 200) {
        final data = response.data;
        
        if (data['code'] == 200 && data['data'] != null) {
          final lyricData = data['data'];
          // 返回原始歌词（字段名是 lrc 不是 lyric）
          if (lyricData['lrc'] != null && lyricData['lrc'].isNotEmpty) {
            final lyric = lyricData['lrc'] as String;
            // 保存到缓存(7天过期)
            await prefs.setString(cacheKey, lyric);
            await prefs.setInt(timestampKey, now);
            return lyric;
          }
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
  
  /// 获取歌曲详情（包含播放链接）
  /// 
  /// [songId] 歌曲ID
  Future<Song?> getSongDetail({
    required String songId,
  }) async {
    const String platform = 'qq';
    try {
      final url = Uri.parse('$_baseUrl/meting/?type=song&id=$songId&source=$platform');
      
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          return Song.fromApiJson(data[0], platform);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
  
  /// 获取热门歌曲推荐
  /// 
  /// [limit] 返回结果数量
  Future<List<Song>> getHotSongs({
    int limit = 20,
  }) async {
    const String platform = 'qq';
    // QQ音乐巅峰榜ID
    const String playlistId = '4';
    
    try {
      final url = Uri.parse('$_baseUrl/meting/?type=playlist&id=$playlistId&source=$platform');
      
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final songs = data.map((item) => Song.fromApiJson(item, platform)).toList();
        return songs.take(limit).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }
  
  /// 获取每日推荐歌曲
  /// 
  /// 基于日期生成不同的推荐列表，每天推荐不同的歌曲
  /// [limit] 返回结果数量
  Future<List<Song>> getDailyRecommendations({
    int limit = 20,
  }) async {
    const String platform = 'qq';
    
    // QQ音乐热门歌单ID列表
    final playlistIds = [
      '4', // 巅峰榜·流行指数
      '6', // 巅峰榜·热歌
      '26', // 巅峰榜·新歌
      '52', // 巅峰榜·内地
      '5', // 巅峰榜·港台
      '3', // 巅峰榜·欧美
      '16', // 巅峰榜·韩国
      '17', // 巅峰榜·日本
    ];
    
    try {
      // 基于当前日期选择歌单
      final today = DateTime.now();
      final dayOfYear = today.difference(DateTime(today.year, 1, 1)).inDays;
      
      // 使用日期作为随机种子，确保每天推荐不同
      final playlistIndex = dayOfYear % playlistIds.length;
      final selectedPlaylistId = playlistIds[playlistIndex];
      
      final url = Uri.parse('$_baseUrl/meting/?type=playlist&id=$selectedPlaylistId&source=$platform');
      
      // 添加自定义请求头，避免 Content-Type 解析问题
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      );
      
      if (response.statusCode == 200) {
        // 直接解析响应体，忽略 Content-Type
        final responseBody = response.body;
        final List<dynamic> data = json.decode(responseBody);
        final allSongs = data.map((item) => Song.fromApiJson(item, platform)).toList();
        
        // 基于日期进行随机打乱，但每天结果一致
        final seed = today.year * 10000 + today.month * 100 + today.day;
        allSongs.shuffle(Random(seed));
        
        return allSongs.take(limit).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }
  
  /// 获取多个榜单的混合推荐
  /// 
  /// 从多个榜单中各取一些歌曲，提供更多样化的推荐
  /// [limit] 返回结果数量
  Future<List<Song>> getMixedRecommendations({
    int limit = 20,
  }) async {
    const String platform = 'qq';
    
    // 选择3个不同类型的榜单
    final playlistIds = ['4', '26', '5']; // 流行、新歌、港台
    final List<Song> mixedSongs = [];
    
    try {
      for (final playlistId in playlistIds) {
        final url = Uri.parse('$_baseUrl/meting/?type=playlist&id=$playlistId&source=$platform');
        
        final response = await http.get(
          url,
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          },
        );
        
        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          final songs = data.map((item) => Song.fromApiJson(item, platform)).toList();
          
          // 从每个榜单取前几首
          mixedSongs.addAll(songs.take(limit ~/ playlistIds.length));
        }
      }
      
      // 打乱顺序
      mixedSongs.shuffle();
      return mixedSongs.take(limit).toList();
    } catch (e) {
      return [];
    }
  }
  
  /// 获取 QQ 账号的歌单列表
  /// 
  /// [qqNumber] QQ 号码（uin）
  Future<List<Map<String, dynamic>>> getUserPlaylists({
    required String qqNumber,
  }) async {
    try {
      // 使用落月 API
      final url = Uri.parse('https://api.vkeys.cn/v2/music/tencent/info?uin=$qqNumber');
      
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 200 && data['data'] != null) {
          final List<Map<String, dynamic>> playlists = [];
          
          // 添加"我喜欢"歌单
          if (data['data']['likesong'] != null) {
            final likesong = data['data']['likesong'];
            playlists.add({
              'id': likesong['id'].toString(),
              'name': likesong['title'] ?? '我喜欢',
              'coverUrl': likesong['picurl'] ?? '',
              'songCount': _parseSongCount(likesong['song_num']),
              'description': '我喜欢的音乐',
            });
          }
          
          // 添加自建歌单
          if (data['data']['mydiss'] != null) {
            final List<dynamic> mydiss = data['data']['mydiss'];
            for (var item in mydiss) {
              playlists.add({
                'id': item['id'].toString(),
                'name': item['title'] ?? '未命名歌单',
                'coverUrl': item['picurl'] ?? '',
                'songCount': _parseSongCount(item['song_num']),
                'description': '自建歌单',
              });
            }
          }
          
          // 添加收藏的歌单
          if (data['data']['likediss'] != null) {
            final List<dynamic> likediss = data['data']['likediss'];
            for (var item in likediss) {
              playlists.add({
                'id': item['id'].toString(),
                'name': item['title'] ?? '未命名歌单',
                'coverUrl': item['picurl'] ?? '',
                'songCount': _parseSongCount(item['song_num']),
                'description': '收藏的歌单',
              });
            }
          }
          
          return playlists;
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }
  
  /// 解析歌曲数量字符串（如"432首歌曲"）
  int _parseSongCount(dynamic songNum) {
    if (songNum == null) return 0;
    final str = songNum.toString();
    final match = RegExp(r'(\d+)').firstMatch(str);
    return match != null ? int.parse(match.group(1)!) : 0;
  }
  
  /// 获取指定歌单的歌曲列表（使用歌单 ID）
  /// 
  /// [playlistId] 歌单 ID
  /// [page] 页数，默认为1
  /// [num] 每页显示数，默认为60（API限制：1-60）
  /// [uin] QQ账号，当歌单为我的收藏且无权限时可使用此参数绕过
  Future<Map<String, dynamic>> getPlaylistSongs({
    required String playlistId,
    int page = 1,
    int num = 60,
    String? uin,
  }) async {
    try {
      // 使用落月 API 获取歌单歌曲列表（支持分页）
      var urlStr = 'https://api.vkeys.cn/v2/music/tencent/dissinfo?id=$playlistId&page=$page&num=$num';
      if (uin != null && uin.isNotEmpty) {
        urlStr += '&uin=$uin';
      }
      final url = Uri.parse(urlStr);
      
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['code'] == 200 && data['data'] != null) {
          final List<dynamic> list = data['data']['list'] ?? [];
          
          final List<Song> songs = list.map((item) {
            // 解析落月API返回的歌曲数据
            return Song(
              id: item['id'].toString(),
              title: item['song'] ?? '未知歌曲',
              artist: item['singer'] ?? '未知歌手',
              album: item['album'] ?? '未知专辑',
              coverUrl: item['cover'] ?? '',
              audioUrl: '', // 播放时再获取
              duration: Duration.zero, // 歌单不显示时长，播放时会获取真实时长
              platform: 'qq',
            );
          }).toList();
          
          // 返回歌曲列表和总数
          return {
            'songs': songs,
            'totalCount': data['data']['info']?['songnum'] ?? songs.length,
          };
        }
      }
      return {'songs': <Song>[], 'totalCount': 0};
    } catch (e) {
      return {'songs': <Song>[], 'totalCount': 0};
    }
  }

  /// 获取歌曲播放链接
  /// 
  /// [songId] 歌曲ID
  /// [songMid] 歌曲MID（id和mid二选一）
  /// [quality] 音质，默认14（臻品母带2.0）
  Future<String?> getSongUrl({
    String? songId,
    String? songMid,
    int quality = 14,
  }) async {
    try {
      String urlStr = 'https://api.vkeys.cn/v2/music/tencent?quality=$quality';
      
      if (songId != null && songId.isNotEmpty) {
        urlStr += '&id=$songId';
      } else if (songMid != null && songMid.isNotEmpty) {
        urlStr += '&mid=$songMid';
      } else {
        return null;
      }
      
      final url = Uri.parse(urlStr);
      
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['code'] == 200 && data['data'] != null) {
          final songData = data['data'];
          final String? audioUrl = songData['url'];
          
          if (audioUrl != null && audioUrl.isNotEmpty) {
            return audioUrl;
          }
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
