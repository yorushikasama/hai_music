import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/favorite_song.dart';
import '../models/song.dart';
import '../providers/music_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_styles.dart';

/// 我喜欢的歌曲列表页面
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<FavoriteSong> _favorites = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);
    
    final musicProvider = Provider.of<MusicProvider>(context, listen: false);
    
    print('📥 开始加载收藏列表...');
    print('云同步状态: ${musicProvider.favoriteManager.isSyncEnabled}');
    
    final favorites = await musicProvider.favoriteManager.getFavorites();
    
    print('📥 加载完成，共 ${favorites.length} 首歌曲');
    
    if (mounted) {
      setState(() {
        _favorites = favorites;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;
    final musicProvider = Provider.of<MusicProvider>(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: Column(
        children: [
          // 自定义顶部导航栏
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              bottom: 16,
            ),
            decoration: BoxDecoration(
              color: colors.surface.withOpacity(0.95),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // 返回按钮
                IconButton(
                  icon: Icon(Icons.arrow_back_ios_new, color: colors.textPrimary, size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.all(8),
                ),
                SizedBox(width: 8),
                // 标题
                Icon(Icons.favorite, color: Colors.red, size: 26),
                SizedBox(width: 12),
                Text(
                  '我喜欢',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                Spacer(),
                // 播放全部按钮
                if (_favorites.isNotEmpty)
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colors.accent, colors.accent.withOpacity(0.8)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: colors.accent.withOpacity(0.3),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          final songs = _favorites.map((f) => Song(
                            id: f.id,
                            title: f.title,
                            artist: f.artist,
                            album: f.album,
                            coverUrl: f.coverUrl,
                            audioUrl: f.r2AudioUrl ?? '',
                            duration: Duration(seconds: f.duration),
                            platform: f.platform,
                          )).toList();
                          
                          if (songs.isNotEmpty) {
                            musicProvider.playSong(songs.first, playlist: songs);
                          }
                        },
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                              SizedBox(width: 4),
                              Text(
                                '播放全部',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                SizedBox(width: 12),
                // 刷新按钮
                IconButton(
                  icon: Icon(Icons.refresh_rounded, color: colors.textSecondary, size: 22),
                  onPressed: _loadFavorites,
                  tooltip: '刷新',
                  padding: EdgeInsets.all(8),
                ),
              ],
            ),
          ),
          // 内容区域
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: colors.accent),
                  )
                : _favorites.isEmpty
                    ? _buildEmptyState(colors)
                    : _buildFavoritesList(colors, musicProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeColors colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_border,
            size: 80,
            color: colors.textSecondary.withOpacity(0.5),
          ),
          SizedBox(height: AppStyles.spacingL),
          Text(
            '还没有收藏的歌曲',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          SizedBox(height: AppStyles.spacingS),
          Text(
            '点击歌曲的爱心按钮收藏喜欢的音乐',
            style: TextStyle(
              fontSize: 14,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesList(ThemeColors colors, MusicProvider musicProvider) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: _favorites.length,
      itemBuilder: (context, index) {
        final favorite = _favorites[index];
        final isPlaying = musicProvider.currentSong?.id == favorite.id;
        
        return Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: _buildSongItem(favorite, isPlaying, colors, musicProvider),
        );
      },
    );
  }

  Widget _buildSongItem(
    FavoriteSong favorite,
    bool isPlaying,
    ThemeColors colors,
    MusicProvider musicProvider,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isPlaying 
            ? colors.accent.withOpacity(0.08)
            : colors.surface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPlaying 
              ? colors.accent.withOpacity(0.3)
              : colors.border.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            final song = Song(
              id: favorite.id,
              title: favorite.title,
              artist: favorite.artist,
              album: favorite.album,
              coverUrl: favorite.coverUrl,
              audioUrl: favorite.r2AudioUrl ?? '',
              duration: Duration(seconds: favorite.duration),
              platform: favorite.platform,
            );
            
            final allSongs = _favorites.map((f) => Song(
              id: f.id,
              title: f.title,
              artist: f.artist,
              album: f.album,
              coverUrl: f.coverUrl,
              audioUrl: f.r2AudioUrl ?? '',
              duration: Duration(seconds: f.duration),
              platform: f.platform,
            )).toList();
            
            musicProvider.playSong(song, playlist: allSongs);
          },
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              children: [
                // 封面图
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: favorite.coverUrl,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: 60,
                          height: 60,
                          color: colors.card.withOpacity(0.3),
                          child: Icon(Icons.music_note, color: colors.textSecondary.withOpacity(0.3)),
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: 60,
                          height: 60,
                          color: colors.card.withOpacity(0.3),
                          child: Icon(Icons.music_note, color: colors.textSecondary),
                        ),
                      ),
                    ),
                    if (isPlaying)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            musicProvider.isPlaying ? Icons.equalizer_rounded : Icons.pause_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(width: 14),
                // 歌曲信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        favorite.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isPlaying ? colors.accent : colors.textPrimary,
                          height: 1.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Text(
                        favorite.artist,
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.textSecondary.withOpacity(0.8),
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12),
                // 时长
                Text(
                  _formatDuration(Duration(seconds: favorite.duration)),
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.textSecondary.withOpacity(0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(width: 8),
                // 收藏按钮
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.withOpacity(0.1),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.favorite_rounded, color: Colors.red, size: 20),
                    onPressed: () {
                      final songTitle = favorite.title;
                      final songId = favorite.id;
                      
                      setState(() {
                        _favorites.removeWhere((f) => f.id == songId);
                      });
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('已取消收藏：$songTitle'),
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                      
                      musicProvider.toggleFavorite(songId);
                      musicProvider.favoriteManager.removeFavorite(songId).then((_) {
                        print('✅ 收藏删除完成: $songTitle');
                      }).catchError((e) {
                        print('❌ 删除收藏失败: $e');
                        _loadFavorites();
                      });
                    },
                    padding: EdgeInsets.all(8),
                    constraints: BoxConstraints(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
