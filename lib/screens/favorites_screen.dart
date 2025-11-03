import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/favorite_song.dart';
import '../models/song.dart';
import '../providers/music_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_styles.dart';
import '../extensions/favorite_song_extension.dart';
import '../widgets/mini_player.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart' if (dart.library.html) '';

/// 我喜欢的歌曲列表页面
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<FavoriteSong> _favorites = [];
  List<FavoriteSong> _filteredFavorites = [];
  bool _isLoading = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterFavorites(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredFavorites = _favorites;
      } else {
        _filteredFavorites = _favorites.where((song) {
          final titleMatch = song.title.toLowerCase().contains(query.toLowerCase());
          final artistMatch = song.artist.toLowerCase().contains(query.toLowerCase());
          final albumMatch = song.album.toLowerCase().contains(query.toLowerCase());
          return titleMatch || artistMatch || albumMatch;
        }).toList();
      }
    });
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
        _filteredFavorites = favorites;
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
      body: Stack(
        children: [
          CustomScrollView(
            physics: AlwaysScrollableScrollPhysics(), // 强制启用滚动
            slivers: [
              // 顶部导航栏
              SliverAppBar(
                pinned: true,
                backgroundColor: colors.surface.withOpacity(0.95),
                elevation: 0,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back_ios_new, color: colors.textPrimary, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                title: _isSearching
                    ? TextField(
                        controller: _searchController,
                        autofocus: true,
                        style: TextStyle(color: colors.textPrimary),
                        decoration: InputDecoration(
                          hintText: '搜索歌曲、歌手、专辑...',
                          hintStyle: TextStyle(color: colors.textSecondary),
                          border: InputBorder.none,
                        ),
                        onChanged: _filterFavorites,
                      )
                    : GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onPanStart: !kIsWeb ? (_) {
                          try {
                            appWindow.startDragging();
                          } catch (e) {
                            // 桌面平台支持窗口拖动
                          }
                        } : null,
                        child: Row(
                          children: [
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
                          ],
                        ),
                      ),
                actions: [
                  IconButton(
                    icon: Icon(
                      _isSearching ? Icons.close : Icons.search,
                      color: colors.textSecondary,
                      size: 22,
                    ),
                    onPressed: () {
                      setState(() {
                        _isSearching = !_isSearching;
                        if (!_isSearching) {
                          _searchController.clear();
                          _filteredFavorites = _favorites;
                        }
                      });
                    },
                    tooltip: _isSearching ? '关闭搜索' : '搜索',
                  ),
                  if (!_isSearching)
                    IconButton(
                      icon: Icon(Icons.refresh_rounded, color: colors.textSecondary, size: 22),
                      onPressed: _loadFavorites,
                      tooltip: '刷新',
                    ),
                ],
              ),
              // 内容区域
              _isLoading
                  ? SliverFillRemaining(
                      child: Center(
                        child: CircularProgressIndicator(color: colors.accent),
                      ),
                    )
                  : _filteredFavorites.isEmpty
                      ? SliverFillRemaining(
                          child: _buildEmptyState(colors),
                        )
                      : _buildFavoritesListSliver(colors, musicProvider),
            ],
          ),
          // Mini 播放器
          if (musicProvider.currentSong != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: MiniPlayer(),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeColors colors) {
    final isSearchEmpty = _isSearching && _searchController.text.isNotEmpty;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSearchEmpty ? Icons.search_off : Icons.favorite_border,
            size: 80,
            color: colors.textSecondary.withOpacity(0.5),
          ),
          SizedBox(height: AppStyles.spacingL),
          Text(
            isSearchEmpty ? '未找到相关歌曲' : '还没有收藏的歌曲',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          SizedBox(height: AppStyles.spacingS),
          Text(
            isSearchEmpty 
                ? '试试其他关键词吧' 
                : '点击歌曲的爱心按钮收藏喜欢的音乐',
            style: TextStyle(
              fontSize: 14,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesListSliver(ThemeColors colors, MusicProvider musicProvider) {
    // 如果有正在播放的歌曲，底部留出空间给 mini 播放器
    final bottomPadding = musicProvider.currentSong != null ? 80.0 : 16.0;

    return SliverPadding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: bottomPadding),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final favorite = _filteredFavorites[index];
            final isPlaying = musicProvider.currentSong?.id == favorite.id;
            
            return Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: _buildSongItem(favorite, isPlaying, colors, musicProvider),
            );
          },
          childCount: _filteredFavorites.length,
        ),
      ),
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
            // 使用扩展方法转换
            final song = favorite.toSong();
            final allSongs = _favorites.toSongList();
            
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
                  _formatDuration(favorite.duration),
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
                    icon: musicProvider.isFavoriteOperationInProgress(favorite.id)
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                            ),
                          )
                        : Icon(Icons.favorite_rounded, color: Colors.red, size: 20),
                    onPressed: musicProvider.isFavoriteOperationInProgress(favorite.id)
                        ? null // 禁用按钮
                        : () async {
                      final songId = favorite.id;
                      final songTitle = favorite.title;
                      
                      // 调用 toggleFavorite 并等待结果
                      final success = await musicProvider.toggleFavorite(songId);
                      
                      if (mounted) {
                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('已取消收藏：$songTitle'),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: Colors.orange.shade700,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                          _loadFavorites(); // 刷新列表
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('取消收藏失败，请重试'),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: Colors.red.shade700,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        }
                      }
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

  String _formatDuration(int? durationSeconds) {
    if (durationSeconds == null) return '00:00';
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits((durationSeconds ~/ 60) % 60);
    final seconds = twoDigits(durationSeconds % 60);
    return '$minutes:$seconds';
  }
}
