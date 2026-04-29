import 'dart:async';

import 'package:bitsdojo_window/bitsdojo_window.dart' if (dart.library.html) '';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../extensions/favorite_song_extension.dart';
import '../models/favorite_song.dart';
import '../providers/favorite_provider.dart';
import '../providers/music_provider.dart';
import '../providers/theme_provider.dart';
import '../services/download/download_service.dart';
import '../theme/app_styles.dart';
import '../utils/snackbar_util.dart';
import '../widgets/confirm_delete_dialog.dart';
import '../widgets/mini_player.dart';
import 'download_progress_screen.dart';
import 'favorites/favorites_song_item.dart';

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
    unawaited(_initFavorites());
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
              _buildSliverAppBar(colors, favorites),
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

  Widget _buildSliverAppBar(ThemeColors colors, List<FavoriteSong> favorites) {
    return SliverAppBar(
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
                } catch (_) {}
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
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      if (!_isSelectionMode)
                        Text(
                          '${favorites.length} 首',
                          style: TextStyle(color: colors.textSecondary, fontSize: 12),
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
      actions: _buildAppBarActions(colors, favorites),
    );
  }

  List<Widget> _buildAppBarActions(ThemeColors colors, List<FavoriteSong> favorites) {
    if (_isSelectionMode) {
      return [
        if (_selectedIds.isNotEmpty)
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: colors.textSecondary, size: 22),
            color: colors.surface,
            shape: RoundedRectangleBorder(borderRadius: AppStyles.borderRadiusMedium),
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
      ];
    }

    return [
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
          onPressed: () => setState(() => _isSelectionMode = true),
          tooltip: '多选',
        ),
      if (!_isSearching)
        IconButton(
          icon: Icon(Icons.refresh_rounded, color: colors.textSecondary, size: 22),
          onPressed: _backgroundRefresh,
          tooltip: '刷新',
        ),
    ];
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
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppStyles.spacingS),
          Text(
            isSearchEmpty ? '试试其他关键词吧' : '点击歌曲的爱心按钮收藏喜欢的音乐',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (!isSearchEmpty) ...[
            const SizedBox(height: AppStyles.spacingL),
            TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.explore_outlined, color: colors.accent),
              label: Text('去发现音乐', style: TextStyle(color: colors.accent)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFavoritesListSliver(ThemeColors colors, MusicProvider musicProvider, FavoriteProvider favoriteProvider) {
    final bottomPadding = musicProvider.currentSong != null ? 96.0 : 16.0;

    return SliverPadding(
      padding: EdgeInsets.only(
        left: AppStyles.spacingXL,
        right: AppStyles.spacingXL,
        top: AppStyles.spacingL,
        bottom: bottomPadding,
      ),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final favorite = _filteredFavorites[index];
            final isPlaying = musicProvider.currentSong?.id == favorite.id;
            final isSelected = _selectedIds.contains(favorite.id);

            return Padding(
              padding: const EdgeInsets.only(bottom: AppStyles.spacingM),
              child: FavoriteSongItem(
                favorite: favorite,
                isPlaying: isPlaying,
                isSelectionMode: _isSelectionMode,
                isSelected: isSelected,
                colors: colors,
                musicProvider: musicProvider,
                favoriteProvider: favoriteProvider,
                onSelectionToggle: () {
                  setState(() {
                    if (isSelected) {
                      _selectedIds.remove(favorite.id);
                    } else {
                      _selectedIds.add(favorite.id);
                    }
                  });
                },
                onToggleFavorite: (success) {
                  if (!mounted) return;
                  setState(() {
                    _filteredFavorites = favoriteProvider.favoriteSongs;
                  });
                  AppSnackBar.showWithContext(
                    context,
                    success ? '已取消收藏：${favorite.title}' : '取消收藏失败，请重试',
                    type: success ? SnackBarType.info : SnackBarType.error,
                  );
                },
              ),
            );
          },
          childCount: _filteredFavorites.length,
        ),
      ),
    );
  }

  Future<void> _batchDownload() async {
    final selectedSongs = _filteredFavorites
        .where((f) => _selectedIds.contains(f.id))
        .toList();

    if (selectedSongs.isEmpty) return;

    final songs = selectedSongs.toSongList();
    final result = await DownloadService().batchAddDownloads(songs);

    if (!mounted) return;

    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });

    if (mounted) {
      final message = result.alreadyExists > 0
          ? '已添加 ${result.added} 首歌曲到下载队列，${result.alreadyExists} 首已存在'
          : '已添加 ${result.added} 首歌曲到下载队列';

      AppSnackBar.show(
        message,
        type: SnackBarType.success,
        actionLabel: '查看',
        onAction: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (context) => const DownloadProgressScreen(),
            ),
          );
        },
      );
    }
  }

  Future<void> _batchRemove() async {
    final selectedSongs = _filteredFavorites
        .where((f) => _selectedIds.contains(f.id))
        .toList();

    if (selectedSongs.isEmpty) return;

    final confirmed = await ConfirmDeleteDialog.show(
      context,
      type: ConfirmDeleteType.batch,
      title: '批量移除',
      message: '确定要从我喜欢中移除选中的歌曲吗？',
      itemCount: _selectedIds.length,
      confirmText: '移除',
    );

    if (confirmed != true) return;

    if (!mounted) return;

    final favoriteProvider = Provider.of<FavoriteProvider>(context, listen: false);
    final selectedIds = selectedSongs.map((f) => f.id).toList();
    final result = await favoriteProvider.removeFavorites(selectedIds);

    if (!mounted) return;

    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
      _filteredFavorites = favoriteProvider.favoriteSongs;
    });

    if (result.allSuccess) {
      AppSnackBar.showWithContext(
        context,
        '已移除 ${result.successIds.length} 首歌曲',
      );
    } else {
      AppSnackBar.showWithContext(
        context,
        '已移除 ${result.successIds.length}/${result.total} 首，${result.failedIds.length} 首失败',
        type: SnackBarType.error,
      );
    }
  }
}
