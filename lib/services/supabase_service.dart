import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/favorite_song.dart';
import '../models/storage_config.dart';
import '../utils/logger.dart';

/// Supabase 数据库服务
class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  SupabaseClient? _client;
  bool _initialized = false;
  bool _tableVerified = false;

  factory SupabaseService() => _instance;

  SupabaseService._internal();

  /// 初始化 Supabase
  Future<bool> initialize(StorageConfig config) async {
    if (!config.isValid) {
      Logger.warning('Supabase 配置无效: url=${config.supabaseUrl.isEmpty ? "空" : "已设置"}, key=${config.supabaseAnonKey.isEmpty ? "空" : "已设置"}', 'Supabase');
      return false;
    }

    try {
      // 如果已经初始化过，直接获取 client 实例
      try {
        _client = Supabase.instance.client;
        _initialized = true;
      } catch (_) {
        // Supabase 尚未初始化，执行初始化
        await Supabase.initialize(
          url: config.supabaseUrl,
          anonKey: config.supabaseAnonKey,
        );
        _client = Supabase.instance.client;
        _initialized = true;
        Logger.success('Supabase 初始化成功', 'Supabase');
      }

      // 确保表存在（只验证一次）
      await _ensureTableExists();

      return true;
    } catch (e, stackTrace) {
      Logger.error('初始化 Supabase', e, stackTrace, 'Supabase');
      _initialized = false;
      return false;
    }
  }

  /// 确保收藏表存在（仅验证一次）
  Future<void> _ensureTableExists() async {
    if (_client == null || _tableVerified) return;

    try {
      await _client!.from('favorite_songs').select().limit(1);
      _tableVerified = true;
    } catch (e) {
      Logger.warning('收藏表可能不存在，请在 Supabase 中手动创建表', 'Supabase');
      Logger.info('''
建议的表结构：
CREATE TABLE favorite_songs (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  artist TEXT NOT NULL,
  album TEXT,
  cover_url TEXT,
  original_cover_url TEXT,
  local_audio_path TEXT,
  local_cover_path TEXT,
  r2_audio_url TEXT,
  r2_cover_url TEXT,
  duration INTEGER,
  platform TEXT,
  lyrics_lrc TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  synced_at TIMESTAMP WITH TIME ZONE,
  user_id UUID REFERENCES auth.users(id)
);
CREATE INDEX idx_favorite_songs_user_id ON favorite_songs(user_id);
CREATE INDEX idx_favorite_songs_created_at ON favorite_songs(created_at DESC);
      ''', 'Supabase');
    }
  }

  /// 检查是否已初始化
  bool get isInitialized => _initialized && _client != null;

  /// 确保 Supabase 已初始化（懒初始化）
  Future<bool> _ensureInitialized() async {
    if (isInitialized) return true;

    // 尝试获取已有实例
    try {
      _client = Supabase.instance.client;
      _initialized = true;
      return true;
    } catch (_) {
      Logger.warning('Supabase 未初始化，请先调用 initialize()', 'Supabase');
      return false;
    }
  }

  /// 添加收藏歌曲
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

  /// 删除收藏歌曲
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

  /// 获取所有收藏歌曲
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

  /// 检查歌曲是否已收藏
  Future<bool> isFavorite(String songId) async {
    if (!await _ensureInitialized()) return false;

    try {
      final response = await _client!
          .from('favorite_songs')
          .select()
          .eq('id', songId)
          .maybeSingle();

      return response != null;
    } catch (e, stackTrace) {
      Logger.error('检查收藏状态', e, stackTrace, 'Supabase');
      return false;
    }
  }

  /// 清除所有收藏
  Future<bool> clearAllFavorites() async {
    if (!await _ensureInitialized()) return false;

    try {
      await _client!.from('favorite_songs').delete().neq('id', '');
      return true;
    } catch (e, stackTrace) {
      Logger.error('清除所有收藏', e, stackTrace, 'Supabase');
      return false;
    }
  }

  /// 关闭连接
  void dispose() {
    _client = null;
    _initialized = false;
    _tableVerified = false;
  }
}
