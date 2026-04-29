import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/favorite_song.dart';
import '../../models/storage_config.dart';
import '../../utils/logger.dart';

/// Supabase 数据库服务
///
/// 封装 Supabase 客户端的全局单例服务，负责收藏数据的云端 CRUD。
/// 包含表结构验证和自动初始化逻辑，被 FavoriteManagerService 直接依赖。
class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  SupabaseClient? _client;
  bool _initialized = false;
  bool _tableVerified = false;

  factory SupabaseService() => _instance;

  SupabaseService._internal();

  Future<bool> initialize(StorageConfig config) async {
    if (!config.isValid) {
      Logger.warning('Supabase 配置无效: url=${config.supabaseUrl.isEmpty ? "空" : "已设置"}, key=${config.supabaseAnonKey.isEmpty ? "空" : "已设置"}', 'Supabase');
      return false;
    }

    try {
      try {
        _client = Supabase.instance.client;
        _initialized = true;
      } catch (_) {
        await Supabase.initialize(
          url: config.supabaseUrl,
          anonKey: config.supabaseAnonKey,
        );
        _client = Supabase.instance.client;
        _initialized = true;
        Logger.success('Supabase 初始化成功', 'Supabase');
      }

      await _ensureTableExists();

      return true;
    } catch (e, stackTrace) {
      Logger.error('初始化 Supabase', e, stackTrace, 'Supabase');
      _initialized = false;
      return false;
    }
  }

  Future<void> _ensureTableExists() async {
    if (_client == null || _tableVerified) return;

    try {
      await _client!.from('favorite_songs').select().limit(1);
      _tableVerified = true;
    } catch (e) {
      Logger.warning('收藏表可能不存在，请在 Supabase 中手动创建表', 'Supabase');
      Logger.info('''
建议的表结构（请参考 docs/SETUP_DATABASE.sql）：
CREATE TABLE favorite_songs (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  artist TEXT NOT NULL,
  album TEXT,
  duration INTEGER NOT NULL,
  platform TEXT,
  original_audio_url TEXT,
  original_cover_url TEXT,
  local_audio_path TEXT,
  local_cover_path TEXT,
  r2_audio_url TEXT,
  r2_cover_url TEXT,
  r2_audio_key TEXT,
  r2_cover_key TEXT,
  audio_file_size BIGINT,
  cover_file_size BIGINT,
  audio_format TEXT,
  audio_bitrate INTEGER,
  sync_status TEXT DEFAULT 'pending',
  download_status TEXT DEFAULT 'pending',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  synced_at TIMESTAMP WITH TIME ZONE,
  last_played_at TIMESTAMP WITH TIME ZONE,
  user_id UUID REFERENCES auth.users(id),
  play_count INTEGER DEFAULT 0,
  tags TEXT[],
  notes TEXT,
  lyrics_lrc TEXT,
  lyrics_translation TEXT,
  lyrics_source TEXT
);
CREATE INDEX idx_favorite_songs_user_id ON favorite_songs(user_id);
CREATE INDEX idx_favorite_songs_created_at ON favorite_songs(created_at DESC);
      ''', 'Supabase');
    }
  }

  bool get isInitialized => _initialized && _client != null;

  Future<bool> _ensureInitialized() async {
    if (isInitialized) return true;

    try {
      _client = Supabase.instance.client;
      _initialized = true;
      return true;
    } catch (_) {
      Logger.warning('Supabase 未初始化，请先调用 initialize()', 'Supabase');
      return false;
    }
  }

  Future<bool> addFavorite(FavoriteSong song) async {
    if (!await _ensureInitialized()) return false;

    try {
      await _client!.from('favorite_songs').upsert(song.toJson());
      return true;
    } catch (e, stackTrace) {
      Logger.error('添加收藏到 Supabase', e, stackTrace, 'Supabase');
      return false;
    }
  }

  Future<bool> removeFavorite(String songId) async {
    if (!await _ensureInitialized()) return false;

    try {
      await _client!.from('favorite_songs').delete().eq('id', songId);
      return true;
    } catch (e, stackTrace) {
      Logger.error('删除收藏', e, stackTrace, 'Supabase');
      return false;
    }
  }

  Future<List<FavoriteSong>> getFavorites() async {
    if (!await _ensureInitialized()) return [];

    try {
      final response = await _client!
          .from('favorite_songs')
          .select()
          .order('created_at', ascending: false);

      if (response.isEmpty) {
        Logger.database('Supabase 收藏列表为空', 'Supabase');
        return [];
      }

      final favorites = <FavoriteSong>[];
      for (int i = 0; i < response.length; i++) {
        try {
          favorites.add(FavoriteSong.fromJson(response[i]));
        } catch (e, stackTrace) {
          Logger.error('解析第 $i 条收藏数据失败', e, stackTrace, 'Supabase');
        }
      }

      Logger.database('从 Supabase 获取 ${favorites.length} 首收藏', 'Supabase');
      return favorites;
    } catch (e, stackTrace) {
      Logger.error('获取收藏列表', e, stackTrace, 'Supabase');
      return [];
    }
  }

  void dispose() {
    _client = null;
    _initialized = false;
    _tableVerified = false;
  }
}
