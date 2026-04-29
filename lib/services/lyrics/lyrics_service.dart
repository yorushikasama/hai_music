import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/logger.dart';

/// 歌词存储服务：读/写 Supabase 数据库中的 favorite_songs 表
class LyricsService {
  static final LyricsService _instance = LyricsService._internal();
  factory LyricsService() => _instance;
  LyricsService._internal();

  SupabaseClient? get _clientOrNull {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  bool get isReady => _clientOrNull != null;

  /// 从数据库获取歌词
  Future<String?> getLyrics(String songId) async {
    final client = _clientOrNull;
    if (client == null) return null;
    try {
      final data = await client
          .from('favorite_songs')
          .select('lyrics_lrc')
          .eq('id', songId)
          .maybeSingle();
      return data != null ? (data['lyrics_lrc'] as String?) : null;
    } catch (e) {
      // 读取失败不抛出，返回空以便上层回退到API
      return null;
    }
  }

  /// 从数据库获取翻译
  Future<String?> getTranslation(String songId) async {
    final client = _clientOrNull;
    if (client == null) return null;
    try {
      final data = await client
          .from('favorite_songs')
          .select('lyrics_translation')
          .eq('id', songId)
          .maybeSingle();
      return data != null ? (data['lyrics_translation'] as String?) : null;
    } catch (e) {
      // 读取失败不抛出，返回空以便上层回退到API
      return null;
    }
  }

  /// 从数据库获取歌词和翻译
  Future<Map<String, String?>?> getLyricsWithTranslation(String songId) async {
    final client = _clientOrNull;
    if (client == null) return null;
    try {
      final data = await client
          .from('favorite_songs')
          .select('lyrics_lrc, lyrics_translation')
          .eq('id', songId)
          .maybeSingle();
      if (data != null) {
        return {
          'lrc': data['lyrics_lrc'] as String?,
          'trans': data['lyrics_translation'] as String?,
        };
      }
      return null;
    } catch (e) {
      // 读取失败不抛出，返回空以便上层回退到API
      return null;
    }
  }

  /// 将歌词写入数据库（存在则更新）
  Future<void> saveLyrics({
    required String songId,
    required String lyrics,
    String? title,
    String? artist,
    String? translation,
  }) async {
    final client = _clientOrNull;
    if (client == null) return;
    try {
      final data = <String, dynamic>{
        'lyrics_lrc': lyrics,
      };
      if (translation != null && translation.isNotEmpty) {
        data['lyrics_translation'] = translation;
      }
      if (title != null) {
        data['title'] = title;
      }
      if (artist != null) {
        data['artist'] = artist;
      }
      // 使用 id 字段作为 songId 的匹配条件
      await client.from('favorite_songs').upsert({...data, 'id': songId});
    } catch (e) {
      Logger.warning('保存歌词到数据库失败', 'LyricsService');
    }
  }
}
