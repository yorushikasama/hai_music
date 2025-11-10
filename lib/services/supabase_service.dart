import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/favorite_song.dart';
import '../models/storage_config.dart';
import '../utils/error_handler.dart';
import '../utils/logger.dart';

/// Supabase 数据库服务
class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  SupabaseClient? _client;
  bool _initialized = false;

  factory SupabaseService() => _instance;

  SupabaseService._internal();

  /// 初始化 Supabase
  Future<bool> initialize(StorageConfig config) async {
    if (!config.isValid) {
      Logger.warning('Supabase 配置无效', 'Supabase');
      return false;
    }

    try {
      await Supabase.initialize(
        url: config.supabaseUrl,
        anonKey: config.supabaseAnonKey,
      );
      _client = Supabase.instance.client;
      _initialized = true;
      
      // 确保表存在
      await _ensureTableExists();
      
      return true;
    } catch (e, stackTrace) {
      ErrorHandler.logError('初始化 Supabase', e, stackTrace);
      _initialized = false;
      return false;
    }
  }

  /// 确保收藏表存在（如果不存在则创建）
  Future<void> _ensureTableExists() async {
    if (_client == null) return;

    try {
      // 尝试查询表，如果失败说明表不存在
      await _client!.from('favorite_songs').select().limit(1);
    } catch (e) {
      Logger.warning('收藏表可能不存在，请在 Supabase 中手动创建表', 'Supabase');
      Logger.info('建议的表结构：', 'Supabase');
      Logger.info('''
CREATE TABLE favorite_songs (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  artist TEXT NOT NULL,
  album TEXT,
  cover_url TEXT,
  local_audio_path TEXT,
  local_cover_path TEXT,
  r2_audio_url TEXT,
  r2_cover_url TEXT,
  duration INTEGER,
  platform TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  synced_at TIMESTAMP WITH TIME ZONE,
  user_id UUID REFERENCES auth.users(id)
);

-- 创建索引
CREATE INDEX idx_favorite_songs_user_id ON favorite_songs(user_id);
CREATE INDEX idx_favorite_songs_created_at ON favorite_songs(created_at DESC);
      ''', 'Supabase');
    }
  }

  /// 检查是否已初始化
  bool get isInitialized => _initialized && _client != null;

  /// 添加收藏歌曲
  Future<bool> addFavorite(FavoriteSong song) async {
    if (!isInitialized) {
      Logger.warning('Supabase 未初始化', 'Supabase');
      return false;
    }

    try {
      await _client!.from('favorite_songs').upsert(song.toJson());
      return true;
    } catch (e, stackTrace) {
      ErrorHandler.logError('添加收藏到 Supabase', e, stackTrace);
      return false;
    }
  }

  /// 删除收藏歌曲
  Future<bool> removeFavorite(String songId) async {
    if (!isInitialized) {
      Logger.warning('Supabase 未初始化', 'Supabase');
      return false;
    }

    try {
      await _client!.from('favorite_songs').delete().eq('id', songId);
      return true;
    } catch (e, stackTrace) {
      ErrorHandler.logError('删除收藏', e, stackTrace);
      return false;
    }
  }

  /// 获取所有收藏歌曲
  Future<List<FavoriteSong>> getFavorites() async {
    if (!isInitialized) {
      Logger.error('Supabase 未初始化', null, null, 'Supabase');
      return [];
    }

    try {
      Logger.database('正在从 Supabase 获取收藏列表...', 'Supabase');
      final response = await _client!
          .from('favorite_songs')
          .select()
          .order('created_at', ascending: false);

      final favorites = (response as List)
          .map((json) => FavoriteSong.fromJson(json))
          .toList();
      
      Logger.database('从 Supabase 获取到 ${favorites.length} 首歌曲', 'Supabase');
      return favorites;
    } catch (e, stackTrace) {
      ErrorHandler.logError('获取收藏列表', e, stackTrace);
      return [];
    }
  }

  /// 检查歌曲是否已收藏
  Future<bool> isFavorite(String songId) async {
    if (!isInitialized) {
      return false;
    }

    try {
      final response = await _client!
          .from('favorite_songs')
          .select()
          .eq('id', songId)
          .maybeSingle();

      return response != null;
    } catch (e, stackTrace) {
      ErrorHandler.logError('检查收藏状态', e, stackTrace);
      return false;
    }
  }

  /// 更新收藏歌曲信息
  Future<bool> updateFavorite(FavoriteSong song) async {
    if (!isInitialized) {
      Logger.warning('Supabase 未初始化', 'Supabase');
      return false;
    }

    try {
      await _client!
          .from('favorite_songs')
          .update(song.toJson())
          .eq('id', song.id);
      return true;
    } catch (e, stackTrace) {
      ErrorHandler.logError('更新收藏', e, stackTrace);
      return false;
    }
  }

  /// 批量同步收藏
  Future<bool> syncFavorites(List<FavoriteSong> songs) async {
    if (!isInitialized) {
      Logger.warning('Supabase 未初始化', 'Supabase');
      return false;
    }

    try {
      final jsonList = songs.map((s) => s.toJson()).toList();
      await _client!.from('favorite_songs').upsert(jsonList);
      return true;
    } catch (e, stackTrace) {
      ErrorHandler.logError('批量同步收藏', e, stackTrace);
      return false;
    }
  }

  /// 清除所有收藏
  Future<bool> clearAllFavorites() async {
    if (!isInitialized) {
      Logger.warning('Supabase 未初始化', 'Supabase');
      return false;
    }

    try {
      await _client!.from('favorite_songs').delete().neq('id', '');
      return true;
    } catch (e, stackTrace) {
      ErrorHandler.logError('清除所有收藏', e, stackTrace);
      return false;
    }
  }

  /// 关闭连接
  void dispose() {
    _client = null;
    _initialized = false;
  }
}
