import 'dart:async';
import 'package:bitsdojo_window/bitsdojo_window.dart' if (dart.library.html) '';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../extensions/duration_extension.dart';
import '../extensions/favorite_song_extension.dart';
import '../models/favorite_song.dart';
import '../providers/favorite_provider.dart';
import '../providers/music_provider.dart';
import '../providers/theme_provider.dart';
import '../services/download_manager.dart';
import '../theme/app_styles.dart';
import '../widgets/mini_player.dart';
import 'download_progress_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<FavoriteSong> _filteredFavorites = [];
  bool _isSearching = false;
  bool _isSelectionMode = false;
  bool _isBackgroundRefreshing = false;
  final Set<String> _selectedIds = {};
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initFavorites();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initFavorites() async {
    final favoriteProvider = Provider.of<FavoriteProvider>(context, listen: false);

    if (favoriteProvider.isFavoritesLoaded) {
      setState(() {
        _filteredFavorites = favoriteProvider.favoriteSongs;
      });
      unawaited(_backgroundRefresh());
    } else {
      await favoriteProvider.loadFavoriteSongs();
      if (mounted) {
        setState(() {
          _filteredFavorites = favoriteProvider.favoriteSongs;
        });
      }
    }
  }

  Future<void> _backgroundRefresh() async {
    if (_isBackgroundRefreshing) return;
    setState(() => _isBackgroundRefreshing = true);

    final favoriteProvider = Provider.of<FavoriteProvider>(context, listen: false);
    await favoriteProvider.refreshFavoriteSongs();

    if (mounted) {
      setState(() {
        _filteredFavorites = favoriteProvider.favoriteSongs;
        _isBackgroundRefreshing = false;
      });
    }
  }

  void _filterFavorites(String query) {
    final favoriteProvider = Provider.of<FavoriteProvider>(context, listen: false);
    if (mounted) {
      setState(() {
        if (query.isEmpty) {
          _filteredFavorites = favoriteProvider.favoriteSongs;
        } else {
          _filteredFavorites = favoriteProvider.favoriteSongs.where((song) {
            final titleMatch = song.title.toLowerCase().contains(query.toLowerCase());
            final artistMatch = song.artist.toLowerCase().contains(query.toLowerCase());
            final albumMatch = song.album.toLowerCase().contains(query.toLowerCase());
            return titleMatch || artistMatch || albumMatch;
          }).toList();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;
    final musicProvider = Provider.of<MusicProvider>(context);
    final favoriteProvider = Provider.of<FavoriteProvider>(context);

    final favorites = favoriteProvider.favoriteSongs;
    final isLoading = !favoriteProvider.isFavoritesLoaded;

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
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
                          } catch (_) {
                            // desktop-only API
                          }
                        } : null,
                        child: Row(
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Icon(
                                  _isSelectionMode ? Icons.checklist_rounded : Icons.favorite,
                                  color: _isSelectionMode ? colors.accent : colors.favorite,
                                  size: 26,
                                ),
                                if (_isBackgroundRefreshing)
                                  Positioned(
                                    right: -2,
                                    top: -2,
                                    child: SizedBox(
                                      width: 10,
                                      height: 10,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        color: colors.accent,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 12),
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
                                if (!_isSelectionMode)
                                  Text(
                                    '${favorites.length} 首',
                                    style: TextStyle(
                                      color: colors.textSecondary,
                                      fontSize: 12,
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
                                Icon(Icons.delete_outline, color: colors.error, size: 20),
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
                            _filteredFavorites = favorites;
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
                        onPressed: _backgroundRefresh,
                        tooltip: '刷新',
                      ),
                  ],
                ],
              ),
              isLoading
                  ? SliverFillRemaining(
                      child: Center(
                        child: CircularProgressIndicator(color: colors.accent),
                      ),
                    )
                  : _filteredFavorites.isEmpty
                      ? SliverFillRemaining(
                          child: _buildEmptyState(colors),
                        )
                      : _buildFavoritesListSliver(colors, musicProvider, favoriteProvider),
            ],
          ),
          if (musicProvider.currentSong != null)
            const Positioned(
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
            color: colors.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppStyles.spacingL),
          Text(
            isSearchEmpty ? '未找到相关歌曲' : '还没有收藏的歌曲',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: AppStyles.spacingS),
          Text(
            isSearchEmpty
                ? '试试其他关键词吧'
                : '点击歌曲的爱心按钮收藏喜欢的音乐',
            style: TextStyle(
              fontSize: 14,
              color: colors.textSecondary,
            ),
          ),
          if (!isSearchEmpty) ...[
            const SizedBox(height: AppStyles.spacingL),
            TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.explore_outlined, color: colors.accent),
              label: Text(
                '去发现音乐',
                style: TextStyle(color: colors.accent),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFavoritesListSliver(ThemeColors colors, MusicProvider musicProvider, FavoriteProvider favoriteProvider) {
    final bottomPadding = musicProvider.currentSong != null ? 96.0 : 16.0;

    return SliverPadding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: bottomPadding),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final favorite = _filteredFavorites[index];
            final isPlaying = musicProvider.currentSong?.id == favorite.id;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildSongItem(favorite, isPlaying, colors, musicProvider, favoriteProvider, _isSelectionMode),
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
    FavoriteProvider favoriteProvider,
    bool isSelectionMode,
  ) {
    final isSelected = _selectedIds.contains(favorite.id);
    final isToggling = favoriteProvider.isFavoriteOperationInProgress(favorite.id);

    return Container(
      decoration: BoxDecoration(
        color: isPlaying
            ? colors.accent.withValues(alpha: 0.08)
            : colors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPlaying
              ? colors.accent.withValues(alpha: 0.3)
              : colors.border.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
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
              final song = favorite.toSong();
              final allSongs = _filteredFavorites.toSongList();
              unawaited(musicProvider.playSong(song, playlist: allSongs));
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                if (isSelectionMode)
                  Checkbox(
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        if (value ?? false) {
                          _selectedIds.add(favorite.id);
                        } else {
                          _selectedIds.remove(favorite.id);
                        }
                      });
                    },
                    activeColor: colors.accent,
                  )
                else
                  const SizedBox(width: 0),
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
                const SizedBox(width: 14),
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
                      const SizedBox(height: 4),
                      Text(
                        favorite.artist,
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
                const SizedBox(width: 12),
                if (favorite.duration != null)
                  Text(
                    Duration(seconds: favorite.duration!).toMinutesSeconds(),
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.textSecondary.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                if (!isSelectionMode) ...[
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.favorite.withValues(alpha: 0.1),
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: isToggling
                          ? Padding(
                              padding: const EdgeInsets.all(10),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(colors.favorite),
                                ),
                              ),
                            )
                          : IconButton(
                              key: const ValueKey('favorite_btn'),
                              icon: Icon(
                                Icons.favorite_rounded,
                                color: colors.favorite,
                                size: 20,
                              ),
                              onPressed: () async {
                                final songId = favorite.id;
                                final songTitle = favorite.title;

                                final success = await favoriteProvider.toggleFavorite(
                                  songId,
                                  currentSong: musicProvider.currentSong,
                                  playlist: musicProvider.playlist,
                                );

                                if (mounted) {
                                  if (success) {
                                    setState(() {
                                      _filteredFavorites = favoriteProvider.favoriteSongs;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('已取消收藏：$songTitle'),
                                        duration: const Duration(seconds: 2),
                                        behavior: SnackBarBehavior.floating,
                                        backgroundColor: colors.warning,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text('取消收藏失败，请重试'),
                                        duration: const Duration(seconds: 2),
                                        behavior: SnackBarBehavior.floating,
                                        backgroundColor: colors.error,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    );
                                  }
                                }
                              },
                              padding: const EdgeInsets.all(8),
                              constraints: const BoxConstraints(),
                            ),
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

  Future<void> _batchDownload() async {
    final selectedSongs = _filteredFavorites
        .where((f) => _selectedIds.contains(f.id))
        .toList();

    if (selectedSongs.isEmpty) return;

    final manager = DownloadManager();
    await manager.init();

    final futures = selectedSongs.map((favorite) async {
      final song = favorite.toSong();
      return manager.addDownload(song);
    });

    final results = await Future.wait(futures);
    final successCount = results.where((r) => r).length;

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
              MaterialPageRoute<void>(
                builder: (context) => const DownloadProgressScreen(),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _batchRemove() async {
    final selectedSongs = _filteredFavorites
        .where((f) => _selectedIds.contains(f.id))
        .toList();

    if (selectedSongs.isEmpty) return;

    final colors = Provider.of<ThemeProvider>(context, listen: false).colors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final dialogColors = Provider.of<ThemeProvider>(context).colors;
        return AlertDialog(
          backgroundColor: dialogColors.surface,
          title: Text(
            '批量移除',
            style: TextStyle(color: dialogColors.textPrimary),
          ),
          content: Text(
            '确定要从我喜欢中移除 ${_selectedIds.length} 首歌曲吗？',
            style: TextStyle(color: dialogColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('取消', style: TextStyle(color: dialogColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: dialogColors.error,
                foregroundColor: Colors.white,
              ),
              child: const Text('移除'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    if (!mounted) return;

    final musicProvider = Provider.of<MusicProvider>(context, listen: false);
    final favoriteProvider = Provider.of<FavoriteProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);

    final futures = selectedSongs.map((favorite) {
      return favoriteProvider.toggleFavorite(
        favorite.id,
        currentSong: musicProvider.currentSong,
        playlist: musicProvider.playlist,
      );
    });

    final results = await Future.wait(futures);
    final successCount = results.where((r) => r).length;

    if (!mounted) return;

    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
      _filteredFavorites = favoriteProvider.favoriteSongs;
    });

    messenger.showSnackBar(
      SnackBar(
        content: Text('已移除 $successCount 首歌曲'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: colors.warning,
      ),
    );
  }
}
