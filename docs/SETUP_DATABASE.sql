-- ============================================
-- 海音乐 - Supabase 数据库完整初始化脚本
-- ============================================
-- 执行前请确保：
-- 1. 已在 Supabase 创建项目
-- 2. 在 SQL Editor 中执行此脚本
-- 3. 如果表已存在，先删除旧表
-- ============================================

-- 清理旧表（如果存在）
DROP TABLE IF EXISTS sync_logs CASCADE;
DROP TABLE IF EXISTS playlist_songs CASCADE;
DROP TABLE IF EXISTS playlists CASCADE;
DROP TABLE IF EXISTS favorite_songs CASCADE;

-- ============================================
-- 1. 收藏歌曲主表
-- ============================================
CREATE TABLE favorite_songs (
  -- 基本信息
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  artist TEXT NOT NULL,
  album TEXT,
  duration INTEGER NOT NULL,
  platform TEXT,
  
  -- 原始URL（来自音乐平台）
  original_audio_url TEXT,
  original_cover_url TEXT,
  
  -- 本地存储路径
  local_audio_path TEXT,
  local_cover_path TEXT,
  
  -- R2云端存储URL
  r2_audio_url TEXT,
  r2_cover_url TEXT,
  r2_audio_key TEXT,
  r2_cover_key TEXT,
  
  -- 文件信息
  audio_file_size BIGINT,
  cover_file_size BIGINT,
  audio_format TEXT,
  audio_bitrate INTEGER,
  
  -- 状态标记
  sync_status TEXT DEFAULT 'pending',
  download_status TEXT DEFAULT 'pending',
  
  -- 时间戳
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  synced_at TIMESTAMP WITH TIME ZONE,
  last_played_at TIMESTAMP WITH TIME ZONE,
  
  -- 用户关联
  user_id UUID REFERENCES auth.users(id),
  
  -- 额外信息
  play_count INTEGER DEFAULT 0,
  tags TEXT[],
  notes TEXT,
  
  -- 歌词信息
  lyrics_lrc TEXT,                -- LRC 格式歌词（带时间轴）
  lyrics_translation TEXT,        -- 歌词翻译
  lyrics_source TEXT              -- 歌词来源（netease/qq/kugou等）
);

-- ============================================
-- 2. 同步日志表
-- ============================================
CREATE TABLE sync_logs (
  id SERIAL PRIMARY KEY,
  song_id TEXT REFERENCES favorite_songs(id) ON DELETE CASCADE,
  
  -- 操作信息
  operation TEXT NOT NULL,
  file_type TEXT NOT NULL,
  status TEXT NOT NULL,
  
  -- 详细信息
  error_message TEXT,
  file_size BIGINT,
  duration_ms INTEGER,
  
  -- 时间戳
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- 3. 播放列表表
-- ============================================
CREATE TABLE playlists (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id),
  
  name TEXT NOT NULL,
  description TEXT,
  cover_url TEXT,
  
  is_public BOOLEAN DEFAULT false,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- 4. 播放列表歌曲关联表
-- ============================================
CREATE TABLE playlist_songs (
  id SERIAL PRIMARY KEY,
  playlist_id UUID REFERENCES playlists(id) ON DELETE CASCADE,
  song_id TEXT REFERENCES favorite_songs(id) ON DELETE CASCADE,
  
  position INTEGER NOT NULL,
  
  added_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  UNIQUE(playlist_id, song_id)
);

-- ============================================
-- 创建索引
-- ============================================

-- favorite_songs 索引
CREATE INDEX idx_favorite_songs_user_id ON favorite_songs(user_id);
CREATE INDEX idx_favorite_songs_created_at ON favorite_songs(created_at DESC);
CREATE INDEX idx_favorite_songs_platform ON favorite_songs(platform);
CREATE INDEX idx_favorite_songs_sync_status ON favorite_songs(sync_status);
CREATE INDEX idx_favorite_songs_last_played ON favorite_songs(last_played_at DESC);

-- sync_logs 索引
CREATE INDEX idx_sync_logs_song_id ON sync_logs(song_id);
CREATE INDEX idx_sync_logs_created_at ON sync_logs(created_at DESC);

-- playlists 索引
CREATE INDEX idx_playlists_user_id ON playlists(user_id);

-- playlist_songs 索引
CREATE INDEX idx_playlist_songs_playlist_id ON playlist_songs(playlist_id);
CREATE INDEX idx_playlist_songs_song_id ON playlist_songs(song_id);

-- ============================================
-- 启用行级安全策略（RLS）
-- ============================================
-- 注意：如果是单用户应用，可以禁用RLS以简化配置
-- 如果需要多用户支持，请取消下面的注释并配置认证

-- ALTER TABLE favorite_songs ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE sync_logs ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE playlists ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE playlist_songs ENABLE ROW LEVEL SECURITY;

-- ============================================
-- 创建安全策略
-- ============================================
-- 如果启用了RLS，取消下面的注释来创建策略

/*
-- favorite_songs 策略
CREATE POLICY "Users can view their own favorites"
  ON favorite_songs FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own favorites"
  ON favorite_songs FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own favorites"
  ON favorite_songs FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own favorites"
  ON favorite_songs FOR DELETE
  USING (auth.uid() = user_id);

-- 其他表的策略...
*/

-- ============================================
-- 创建触发器
-- ============================================

-- 自动更新时间戳函数
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 应用触发器
CREATE TRIGGER update_playlists_updated_at 
  BEFORE UPDATE ON playlists
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- 创建视图
-- ============================================

-- 完整歌曲信息视图（已包含歌词字段，无需JOIN）
-- 注意：favorite_songs 表已包含 lyrics, lyrics_lrc, lyrics_translation 字段

-- 播放列表详情视图
CREATE VIEW v_playlist_details AS
SELECT 
  p.id as playlist_id,
  p.name as playlist_name,
  p.description,
  p.cover_url as playlist_cover,
  p.is_public,
  fs.*,
  ps.position,
  ps.added_at
FROM playlists p
JOIN playlist_songs ps ON p.id = ps.playlist_id
JOIN favorite_songs fs ON ps.song_id = fs.id
ORDER BY ps.position;

-- ============================================
-- 完成！
-- ============================================
-- 数据库初始化完成
-- 现在可以在应用中配置 Supabase 连接信息
-- ============================================
