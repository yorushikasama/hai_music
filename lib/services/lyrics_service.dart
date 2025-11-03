import 'package:supabase_flutter/supabase_flutter.dart';

/// 歌词存储服务：读/写 Supabase 数据库中的 song_lyrics 表
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
          .from('song_lyrics')
          .select('lyrics')
          .eq('song_id', songId)
          .maybeSingle();
      return data != null ? (data['lyrics'] as String?) : null;
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
  }) async {
    final client = _clientOrNull;
    if (client == null) return;
    try {
      await client.from('song_lyrics').upsert({
        'song_id': songId,
        'lyrics': lyrics,
        if (title != null) 'title': title,
        if (artist != null) 'artist': artist,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // 忽略写入异常
    }
  }
}
