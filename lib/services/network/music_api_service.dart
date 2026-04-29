import '../../config/app_constants.dart';
import '../../models/song.dart';
import '../../utils/logger.dart';
import '../../utils/result.dart';
import '../core/core.dart';
import '../lyrics/lyrics.dart';

/// 音乐 API 服务
///
/// 封装所有音乐平台 API 调用的核心服务，提供搜索歌曲、获取歌词(含翻译)、
/// 获取歌曲URL(含音质降级)、获取歌单列表/歌曲等能力。
/// 返回值统一使用 [Result<T>] 类型，调用方可通过 [Result.when] 处理成功/失败。
/// 被 SongUrlService/LyricsLoadingService/FavoriteManagerService/MusicRepository 等依赖。
class MusicApiService {
  static final _dioClient = DioClient();
  static final _prefsCache = PreferencesService();
  static final _lyricsCache = LyricsCacheService();

  Future<Result<List<Song>>> searchSongs({
    required String keyword,
    int limit = 30,
    int page = 1,
  }) async {
    try {
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
          final List<dynamic> songList = data['data'] is List
              ? data['data'] as List<dynamic>
              : [data['data']];

          final songs = songList.map((item) {
            return Song(
              id: (item['id'] ?? '').toString(),
              title: (item['song'] ?? '未知歌曲').toString(),
              artist: (item['singer'] ?? '未知歌手').toString(),
              album: (item['album'] ?? '未知专辑').toString(),
              coverUrl: (item['cover'] ?? '').toString(),
              audioUrl: (item['url'] ?? '').toString(),
              duration: _parseDuration(item['interval']?.toString()),
              platform: 'qq',
            );
          }).toList();

          return Success(songs);
        }
        return Failure('API返回错误: ${data['code']}');
      }
      return Failure('HTTP错误: ${response.statusCode}');
    } catch (e) {
      Logger.error('搜索歌曲失败', e, null, 'MusicApiService');
      return Failure('搜索歌曲失败', error: e);
    }
  }

  int? _parseDuration(String? interval) {
    if (interval == null || interval.isEmpty) return null;

    try {
      final trimmed = interval.trim();
      final pureNumber = int.tryParse(trimmed);
      if (pureNumber != null && pureNumber > 0) {
        return pureNumber;
      }

      final minuteMatch = RegExp(r'(\d+)分').firstMatch(trimmed);
      final secondMatch = RegExp(r'(\d+)秒').firstMatch(trimmed);

      if (minuteMatch == null && secondMatch == null) return null;

      final minutes = minuteMatch != null ? int.parse(minuteMatch.group(1)!) : 0;
      final seconds = secondMatch != null ? int.parse(secondMatch.group(1)!) : 0;

      return minutes * 60 + seconds;
    } catch (e) {
      return null;
    }
  }

  Future<String?> getLyrics({
    String? songId,
    String? songMid,
  }) async {
    final result = await getLyricsWithTranslationResult(songId: songId, songMid: songMid);
    return result.when(
      success: (data) => data?['lrc'],
      failure: (_, __) => null,
    );
  }

  Future<Map<String, String?>?> getLyricsWithTranslation({
    String? songId,
    String? songMid,
  }) async {
    final result = await getLyricsWithTranslationResult(songId: songId, songMid: songMid);
    return result.when(
      success: (data) => data,
      failure: (_, __) => null,
    );
  }

  Future<Result<Map<String, String?>?>> getLyricsWithTranslationResult({
    String? songId,
    String? songMid,
  }) async {
    try {
      final cacheKeys = _buildLyricCacheKeys(songId: songId, songMid: songMid);
      if (cacheKeys == null) return const Success(null);

      await _prefsCache.init();

      final cached = await _lyricsCache.get(cacheKeys);
      if (cached != null) return Success(cached);

      final queryParams = _buildLyricQueryParams(songId: songId, songMid: songMid);

      final response = await _dioClient.get(
        AppConstants.lyricApiUrl,
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['code'] == 200 && data['data'] != null) {
          final lyricData = data['data'];
          final lrc = (lyricData['lrc'] as String?)?.trim();
          final trans = (lyricData['trans'] as String?)?.trim();

          if (lrc != null && lrc.isNotEmpty) {
            await _lyricsCache.put(cacheKeys, lrc, trans);
            return Success({'lrc': lrc, 'trans': trans});
          }
        }
      }
      return const Success(null);
    } catch (e) {
      Logger.error('获取歌词失败', e, null, 'MusicApiService');
      return Failure('获取歌词失败', error: e, code: ErrorCode.network);
    }
  }

  ({String cacheKey, String cacheKeyTrans, String timestampKey})? _buildLyricCacheKeys({
    String? songId,
    String? songMid,
  }) {
    if (songId != null && songId.isNotEmpty) {
      return (
        cacheKey: 'lyric_$songId',
        cacheKeyTrans: 'lyric_trans_$songId',
        timestampKey: 'lyric_time_$songId',
      );
    } else if (songMid != null && songMid.isNotEmpty) {
      return (
        cacheKey: 'lyric_mid_$songMid',
        cacheKeyTrans: 'lyric_trans_mid_$songMid',
        timestampKey: 'lyric_time_mid_$songMid',
      );
    }
    return null;
  }

  Map<String, dynamic> _buildLyricQueryParams({
    String? songId,
    String? songMid,
  }) {
    final queryParams = <String, dynamic>{};
    if (songId != null && songId.isNotEmpty) {
      queryParams['id'] = songId;
    } else if (songMid != null && songMid.isNotEmpty) {
      queryParams['mid'] = songMid;
    }
    return queryParams;
  }

  Future<List<Map<String, dynamic>>> getUserPlaylists({
    required String qqNumber,
  }) async {
    try {
      final response = await _dioClient.get(
        AppConstants.songInfoApiUrl,
        queryParameters: {'uin': qqNumber},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['code'] == 200 && data['data'] != null) {
          final List<Map<String, dynamic>> playlists = [];

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

          if (data['data']['mydiss'] != null) {
            final List<dynamic> mydiss = data['data']['mydiss'] as List<dynamic>;
            for (final item in mydiss) {
              playlists.add({
                'id': item['id'].toString(),
                'name': item['title'] ?? '未命名歌单',
                'coverUrl': item['picurl'] ?? '',
                'songCount': _parseSongCount(item['song_num']),
                'description': '自建歌单',
              });
            }
          }

          if (data['data']['likediss'] != null) {
            final List<dynamic> likediss = data['data']['likediss'] as List<dynamic>;
            for (final item in likediss) {
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
      Logger.error('获取歌单列表失败', e, null, 'MusicApiService');
      return [];
    }
  }

  int _parseSongCount(dynamic songNum) {
    if (songNum == null) return 0;
    final str = songNum.toString();
    final match = RegExp(r'(\d+)').firstMatch(str);
    return match != null ? int.parse(match.group(1)!) : 0;
  }

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
      final response = await _dioClient.get(
        AppConstants.playlistInfoApiUrl,
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final data = response.data;

        if (data['code'] == 200 && data['data'] != null) {
          final list = (data['data']['list'] ?? <dynamic>[]) as List<dynamic>;

          final List<Song> songs = list.map((item) {
            return Song(
              id: (item['id'] as dynamic).toString(),
              title: (item['song'] ?? '未知歌曲') as String,
              artist: (item['singer'] ?? '未知歌手') as String,
              album: (item['album'] ?? '未知专辑') as String,
              coverUrl: (item['cover'] ?? '') as String,
              platform: 'qq',
            );
          }).toList();

          return {
            'songs': songs,
            'totalCount': data['data']['info']?['songnum'] ?? songs.length,
          };
        }
      }
      return {'songs': <Song>[], 'totalCount': 0};
    } catch (e) {
      Logger.error('获取歌单歌曲失败', e, null, 'MusicApiService');
      return {'songs': <Song>[], 'totalCount': 0};
    }
  }

  Future<Result<String>> getSongUrlResult({
    String? songId,
    String? songMid,
    int? quality,
  }) async {
    final qualityCode = quality ?? await AudioQualityService.instance.getCurrentQualityCode();
    final qualitiesToTry = <int>[qualityCode];
    if (qualityCode != 8) qualitiesToTry.add(8);
    if (qualityCode != 16) qualitiesToTry.add(16);
    if (qualityCode != 32) qualitiesToTry.add(32);

    for (final q in qualitiesToTry) {
      try {
        final queryParams = {'quality': q.toString()};

        if (songId != null && songId.isNotEmpty) {
          queryParams['id'] = songId;
        } else if (songMid != null && songMid.isNotEmpty) {
          queryParams['mid'] = songMid;
        } else {
          return Failure('缺少歌曲ID', code: ErrorCode.notFound);
        }

        final response = await _dioClient.get(
          AppConstants.searchApiUrl,
          queryParameters: queryParams,
        );

        if (response.statusCode == 200) {
          final data = response.data;

          if (data['code'] == 200 && data['data'] != null) {
            final songData = data['data'];
            if (songData is Map) {
              final String? audioUrl = songData['url'] as String?;
              if (audioUrl != null && audioUrl.isNotEmpty) {
                if (q != qualityCode) {
                  Logger.info('音质 $qualityCode 不可用，降级到音质 $q', 'MusicApiService');
                }
                return Success(audioUrl);
              }
            }
          } else if (data['code'] != 200) {
            final message = data['message']?.toString() ?? '';
            if (message.contains('付费') || message.contains('VIP') || message.contains('版权')) {
              Logger.warning('歌曲为付费/版权受限: $message', 'MusicApiService');
              return Failure('付费/版权受限歌曲', code: ErrorCode.paymentRequired);
            }
          }
        }
      } catch (e) {
        Logger.error('获取歌曲URL失败(音质$q)', e, null, 'MusicApiService');
      }
    }

    return Failure('无法获取歌曲链接', code: ErrorCode.notFound);
  }

  Future<String?> getSongUrl({
    String? songId,
    String? songMid,
    int? quality,
  }) async {
    final result = await getSongUrlResult(
      songId: songId,
      songMid: songMid,
      quality: quality,
    );
    return result.when(
      success: (url) => url,
      failure: (_, __) => null,
    );
  }
}
