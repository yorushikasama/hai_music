import 'package:flutter/material.dart';
import '../utils/logger.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/favorite_song.dart';
import '../providers/music_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_styles.dart';
import '../extensions/favorite_song_extension.dart';
import '../widgets/mini_player.dart';
import '../services/download_manager.dart';
import 'download_progress_screen.dart';
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
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};
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
    
    Logger.debug('📥 开始加载收藏列表...');
    Logger.debug('云同步状态: ${musicProvider.favoriteManager.isSyncEnabled}');
    
    final favorites = await musicProvider.favoriteManager.getFavorites();
    
    Logger.debug('📥 加载完成，共 ${favorites.length} 首歌曲');
    
    // 🔧 修复：刷新 MusicProvider 的收藏状态，确保 mini 播放器显示正确
    musicProvider.refreshFavorites();
    
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
              // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
            SliverAppBar(
                pinned: true,
                backgroundColor: colors.surface.withValues(alpha: 0.95),
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
                            Icon(
                              _isSelectionMode ? Icons.checklist_rounded : Icons.favorite,
                              color: _isSelectionMode ? colors.accent : Colors.red,
                              size: 26,
                            ),
                            SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _isSelectionMode ? '选择歌曲' : '我喜欢',
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                if (_isSelectionMode && _selectedIds.isNotEmpty)
                                  Text(
                                    '已选择 ${_selectedIds.length} 首',
                                    style: TextStyle(
                                      color: colors.accent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                actions: [
                  if (_isSelectionMode) ...[
                    // 批量操作菜单按钮
                    if (_selectedIds.isNotEmpty)
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, color: colors.textSecondary, size: 22),
                        color: colors.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        offset: const Offset(0, 50),
                        itemBuilder: (context) => [
                          PopupMenuItem<String>(
                            value: 'download',
                            child: Row(
                              children: [
                                Icon(Icons.download_outlined, color: colors.accent, size: 20),
                                const SizedBox(width: 12),
                                Text('批量下载', style: TextStyle(color: colors.textPrimary)),
                              ],
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'remove',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                const SizedBox(width: 12),
                                Text('批量移除', style: TextStyle(color: colors.textPrimary)),
                              ],
                            ),
                          ),
                        ],
                        onSelected: (value) {
                          if (value == 'download') {
                            _batchDownload();
                          } else if (value == 'remove') {
                            _batchRemove();
                          }
                        },
                      ),
                    // 全选/取消全选
                    TextButton(
                      onPressed: () {
                        setState(() {
                          if (_selectedIds.length == _filteredFavorites.length) {
                            _selectedIds.clear();
                          } else {
                            _selectedIds.addAll(_filteredFavorites.map((f) => f.id));
                          }
                        });
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        _selectedIds.length == _filteredFavorites.length ? '全选' : '全选',
                        style: TextStyle(color: colors.accent, fontSize: 13),
                      ),
                    ),
                    // 取消选择模式
                    IconButton(
                      icon: Icon(Icons.close, color: colors.textSecondary, size: 22),
                      onPressed: () {
                        setState(() {
                          _isSelectionMode = false;
                          _selectedIds.clear();
                        });
                      },
                      tooltip: '取消',
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    ),
                  ] else ...[
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
                        icon: Icon(Icons.checklist_rounded, color: colors.textSecondary, size: 22),
                        onPressed: () {
                          setState(() {
                            _isSelectionMode = true;
                          });
                        },
                        tooltip: '多选',
                      ),
                    if (!_isSearching)
                      IconButton(
                        icon: Icon(Icons.refresh_rounded, color: colors.textSecondary, size: 22),
                        onPressed: _loadFavorites,
                        tooltip: '刷新',
                      ),
                  ],
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
          // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
          Icon(
            isSearchEmpty ? Icons.search_off : Icons.favorite_border,
            size: 80,
            color: colors.textSecondary.withValues(alpha: 0.5),
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
    // 计算底部padding：mini播放器(80) + 额外间距(16)
    final bottomPadding = musicProvider.currentSong != null ? 96.0 : 16.0;

    return SliverPadding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: bottomPadding),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final favorite = _filteredFavorites[index];
            final isPlaying = musicProvider.currentSong?.id == favorite.id;
            
            return Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: _buildSongItem(favorite, isPlaying, colors, musicProvider, _isSelectionMode),
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
    bool isSelectionMode,
  ) {
    final isSelected = _selectedIds.contains(favorite.id);
    return Container(
      // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
    decoration: BoxDecoration(
        color: isPlaying
            ? colors.accent.withValues(alpha: 0.08)
            : colors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPlaying
              ? colors.accent.withValues(alpha: 0.3)
              : colors.border.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
            if (isSelectionMode) {
              setState(() {
                if (isSelected) {
                  _selectedIds.remove(favorite.id);
                } else {
                  _selectedIds.add(favorite.id);
                }
              });
            } else {
              // 使用扩展方法转换
              final song = favorite.toSong();
              // 🔧 修复：使用 _filteredFavorites 而不是 _favorites，确保索引匹配
              final allSongs = _filteredFavorites.toSongList();
              
              musicProvider.playSong(song, playlist: allSongs);
            }
          },
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              children: [
                // 选择框或封面图
                if (isSelectionMode)
                  Checkbox(
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedIds.add(favorite.id);
                        } else {
                          _selectedIds.remove(favorite.id);
                        }
                      });
                    },
                    activeColor: colors.accent,
                  )
                else
                  SizedBox(width: 0),
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
                        // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
                        placeholder: (context, url) => Container(
                          width: 60,
                          height: 60,
                          color: colors.card.withValues(alpha: 0.3),
                          child: Icon(Icons.music_note, color: colors.textSecondary.withValues(alpha: 0.3)),
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: 60,
                          height: 60,
                          color: colors.card.withValues(alpha: 0.3),
                          child: Icon(Icons.music_note, color: colors.textSecondary),
                        ),
                      ),
                    ),
                    if (isPlaying)
                      Positioned.fill(
                        // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
                      child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
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
                        // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
                      style: TextStyle(
                          fontSize: 13,
                          color: colors.textSecondary.withValues(alpha: 0.8),
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
                  // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
                style: TextStyle(
                    fontSize: 13,
                    color: colors.textSecondary.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (!isSelectionMode) ...[
                  SizedBox(width: 8),
                  // 收藏按钮
                  Container(
                  // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.withValues(alpha: 0.1),
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

  /// 批量下载
  Future<void> _batchDownload() async {
    final selectedSongs = _filteredFavorites
        .where((f) => _selectedIds.contains(f.id))
        .toList();

    if (selectedSongs.isEmpty) return;

    final manager = DownloadManager();
    await manager.init();

    int successCount = 0;
    for (final favorite in selectedSongs) {
      final song = favorite.toSong();
      final success = await manager.addDownload(song);
      if (success) successCount++;
    }

    if (!mounted) return;

    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已添加 $successCount 首歌曲到下载队列'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: '查看',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const DownloadProgressScreen(),
              ),
            );
          },
        ),
      ),
    );
  }

  /// 批量移除
  Future<void> _batchRemove() async {
    final selectedSongs = _filteredFavorites
        .where((f) => _selectedIds.contains(f.id))
        .toList();

    if (selectedSongs.isEmpty) return;

    // 确认对话框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final colors = Provider.of<ThemeProvider>(context).colors;
        return AlertDialog(
          backgroundColor: colors.surface,
          title: Text(
            '批量移除',
            style: TextStyle(color: colors.textPrimary),
          ),
          content: Text(
            '确定要从我喜欢中移除 ${_selectedIds.length} 首歌曲吗？',
            style: TextStyle(color: colors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('取消', style: TextStyle(color: colors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('移除'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final musicProvider = Provider.of<MusicProvider>(context, listen: false);
    int successCount = 0;

    for (final favorite in selectedSongs) {
      final success = await musicProvider.toggleFavorite(favorite.id);
      if (success) successCount++;
    }

    if (!mounted) return;

    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });

    // 刷新列表
    await _loadFavorites();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已移除 $successCount 首歌曲'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.orange.shade700,
      ),
    );
  }
}
