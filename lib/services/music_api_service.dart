import '../models/song.dart';
import '../config/app_constants.dart';
import 'dio_client.dart';
import 'preferences_cache_service.dart';
import '../utils/logger.dart';

/// 音乐API服务类
/// 支持多个音乐平台的搜索和播放功能
class MusicApiService {
  // API基础URL - 使用配置文件中的常量
  static const String _baseUrl = AppConstants.apiBaseUrl;
  final _dioClient = DioClient();
  final _prefsCache = PreferencesCacheService();
  
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
      Logger.error('搜索歌曲失败', e, null, 'MusicApiService');
      return [];
    }
  }
  
  /// 解析时长字符串（如 "3分30秒" -> 秒数）
  int? _parseDuration(String? interval) {
    if (interval == null || interval.isEmpty) return null;
    
    try {
      // 匹配 "3分30秒" 格式
      final minuteMatch = RegExp(r'(\d+)分').firstMatch(interval);
      final secondMatch = RegExp(r'(\d+)秒').firstMatch(interval);
      
      final minutes = minuteMatch != null ? int.parse(minuteMatch.group(1)!) : 0;
      final seconds = secondMatch != null ? int.parse(secondMatch.group(1)!) : 0;
      
      return minutes * 60 + seconds;
    } catch (e) {
      return null;
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

      // 🔧 优化:使用 PreferencesCacheService 单例
      // 检查缓存
      await _prefsCache.init();
      final cachedLyric = await _prefsCache.getString(cacheKey);
      final cachedTimestamp = await _prefsCache.getInt(timestampKey) ?? 0;
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
            await _prefsCache.setString(cacheKey, lyric);
            await _prefsCache.setInt(timestampKey, now);
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
      final response = await _dioClient.get(
        '$_baseUrl/meting/',
        queryParameters: {
          'type': 'song',
          'id': songId,
          'source': platform,
        },
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        if (data.isNotEmpty) {
          return Song.fromApiJson(data[0], platform);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
  
  /// 获取 QQ 账号的歌单列表
  /// 
  /// [qqNumber] QQ 号码（uin）
  Future<List<Map<String, dynamic>>> getUserPlaylists({
    required String qqNumber,
  }) async {
    try {
      final response = await _dioClient.get(
        'https://api.vkeys.cn/v2/music/tencent/info',
        queryParameters: {'uin': qqNumber},
      );
      
      if (response.statusCode == 200) {
        final data = response.data;
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
      final queryParams = {
        'id': playlistId,
        'page': page.toString(),
        'num': num.toString(),
      };
      
      if (uin != null && uin.isNotEmpty) {
        queryParams['uin'] = uin;
      }
      
      Logger.debug('🌐 请求歌单API: $playlistId, 页码: $page, 数量: $num, UIN: $uin', 'MusicApiService');
      
      final response = await _dioClient.get(
        'https://api.vkeys.cn/v2/music/tencent/dissinfo',
        queryParameters: queryParams,
      );
      
      Logger.debug('📡 API响应状态: ${response.statusCode}', 'MusicApiService');
      
      if (response.statusCode == 200) {
        final data = response.data;
        
        Logger.debug('📋 API响应数据结构: code=${data['code']}, data存在=${data['data'] != null}', 'MusicApiService');
        
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
              duration: null, // 歌单不显示时长，播放时会获取真实时长
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

  /// 获取完整歌单（自动分页加载所有歌曲）
  /// 
  /// [playlistId] 歌单 ID
  /// [uin] QQ账号，当歌单为我的收藏且无权限时可使用此参数绕过
  /// [maxSongs] 最大歌曲数量限制，默认无限制
  Future<Map<String, dynamic>> getCompletePlaylist({
    required String playlistId,
    String? uin,
    int? maxSongs,
  }) async {
    Logger.info('🎵 开始获取完整歌单: $playlistId (UIN: $uin, 最大: $maxSongs)', 'MusicApiService');
    
    final List<Song> allSongs = [];
    int currentPage = 1;
    int totalCount = 0;
    const int pageSize = 60;
    
    try {
      while (maxSongs == null || allSongs.length < maxSongs) {
        Logger.debug('📄 加载第 $currentPage 页，每页 $pageSize 首', 'MusicApiService');
        
        final result = await getPlaylistSongs(
          playlistId: playlistId,
          page: currentPage,
          num: pageSize,
          uin: uin,
        );
        
        Logger.debug('📊 第 $currentPage 页API返回: ${result.keys.toList()}', 'MusicApiService');
        
        final List<Song> pageSongs = result['songs'] as List<Song>;
        totalCount = result['totalCount'] as int;
        
        Logger.debug('✅ 第 $currentPage 页加载完成: ${pageSongs.length} 首歌曲，总数: $totalCount', 'MusicApiService');
        
        if (pageSongs.isEmpty) {
          Logger.warning('⚠️ 第 $currentPage 页返回空结果，停止加载', 'MusicApiService');
          break; // 没有更多歌曲了
        }
        
        // 添加新歌曲，避免重复
        final existingIds = allSongs.map((s) => s.id).toSet();
        final uniqueSongs = pageSongs.where((s) => !existingIds.contains(s.id)).toList();
        allSongs.addAll(uniqueSongs);
        
        Logger.debug('📈 累计加载: ${allSongs.length}/${totalCount} 首歌曲', 'MusicApiService');
        
        // 如果已经获取了所有歌曲，或者这一页的歌曲数量少于页面大小，说明没有更多了
        if (allSongs.length >= totalCount || pageSongs.length < pageSize) {
          Logger.info('🏁 歌单加载完成，原因: ${allSongs.length >= totalCount ? "已达到总数" : "页面数据不足"}', 'MusicApiService');
          break;
        }
        
        currentPage++;
        
        // 添加小延迟避免请求过快
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      Logger.success('✅ 完整歌单加载成功: ${allSongs.length}/$totalCount 首歌曲', 'MusicApiService');
      
      return {
        'songs': allSongs,
        'totalCount': totalCount,
        'loadedCount': allSongs.length,
      };
    } catch (e) {
      Logger.error('❌ 完整歌单加载失败: $playlistId', e, null, 'MusicApiService');
      return {
        'songs': allSongs, // 返回已加载的歌曲
        'totalCount': totalCount,
        'loadedCount': allSongs.length,
        'error': e.toString(),
      };
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
      final queryParams = {'quality': quality.toString()};
      
      if (songId != null && songId.isNotEmpty) {
        queryParams['id'] = songId;
      } else if (songMid != null && songMid.isNotEmpty) {
        queryParams['mid'] = songMid;
      } else {
        return null;
      }
      
      final response = await _dioClient.get(
        'https://api.vkeys.cn/v2/music/tencent',
        queryParameters: queryParams,
      );
      
      if (response.statusCode == 200) {
        final data = response.data;
        
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
