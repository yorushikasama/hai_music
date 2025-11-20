import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/logger.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../models/song.dart';
import '../providers/music_provider.dart';
import '../theme/app_styles.dart';
import '../providers/theme_provider.dart';
import '../utils/platform_utils.dart';
import '../widgets/draggable_window_area.dart';
import '../services/music_api_service.dart';
import '../services/preferences_cache_service.dart';
import '../services/download_manager.dart';
import 'download_progress_screen.dart';
import 'search/search_header.dart';
import 'search/search_results.dart';

class SearchScreen extends StatefulWidget {
  final String? initialQuery;
  
  const SearchScreen({super.key, this.initialQuery});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final MusicApiService _apiService = MusicApiService();
  List<Song> _searchResults = [];
  List<String> _searchHistory = [];
  bool _isSearching = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String _currentQuery = '';
  Timer? _debounceTimer;
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};
  
  static const int _debounceMilliseconds = 300; // 防抖延迟
  static const String _historyKey = 'search_history';
  static const int _maxHistoryCount = 10; // 最多保存10条历史
  static const int _pageSize = 30; // 每页数量

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
    _scrollController.addListener(_onScroll);
    
    // 如果有初始搜索词，自动执行搜索
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      Logger.debug('📝 SearchScreen initState: ${widget.initialQuery}');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchController.text = widget.initialQuery!;
        _performSearch(widget.initialQuery!);
      });
    }
  }
  
  @override
  void didUpdateWidget(SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当 initialQuery 参数变化时，执行新的搜索
    if (widget.initialQuery != null && 
        widget.initialQuery!.isNotEmpty && 
        widget.initialQuery != oldWidget.initialQuery) {
      Logger.debug('📝 SearchScreen didUpdateWidget: ${widget.initialQuery}');
      _searchController.text = widget.initialQuery!;
      _performSearch(widget.initialQuery!);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  /// 监听滚动，加载更多
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    
    // 距离底部200px时触发加载
    if (currentScroll >= maxScroll - 200) {
      if (!_isLoadingMore && _hasMore && _currentQuery.isNotEmpty) {
        _loadMore();
      }
    }
  }
  
  /// 加载搜索历史
  Future<void> _loadSearchHistory() async {
    try {
      final prefsCache = PreferencesCacheService();
      await prefsCache.init();
      final history = await prefsCache.getStringList(_historyKey) ?? [];
      if (mounted) {
        setState(() {
          _searchHistory = history;
        });
      }
    } catch (e) {
      // 忽略错误
    }
  }
  
  /// 保存搜索历史
  Future<void> _saveSearchHistory(String query) async {
    if (query.trim().isEmpty) return;

    try {
      final prefsCache = PreferencesCacheService();
      await prefsCache.init();

      // 移除重复项
      _searchHistory.remove(query);
      // 添加到开头
      _searchHistory.insert(0, query);
      // 限制数量
      if (_searchHistory.length > _maxHistoryCount) {
        _searchHistory = _searchHistory.sublist(0, _maxHistoryCount);
      }

      await prefsCache.setStringList(_historyKey, _searchHistory);
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      // 忽略错误
    }
  }
  
  /// 清空搜索历史
  Future<void> _clearSearchHistory() async {
    try {
      final prefsCache = PreferencesCacheService();
      await prefsCache.init();
      await prefsCache.remove(_historyKey);
      if (mounted) {
        setState(() {
          _searchHistory = [];
        });
      }
    } catch (e) {
      // 忽略错误
    }
  }

  /// 带防抖的搜索
  void _onSearchChanged(String query) {
    // 取消之前的定时器
    _debounceTimer?.cancel();
    
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _currentQuery = '';
        _currentPage = 1;
        _hasMore = true;
      });
      return;
    }
    
    // 设置新的定时器
    _debounceTimer = Timer(Duration(milliseconds: _debounceMilliseconds), () {
      _performSearch(query);
    });
  }
  
  /// 执行搜索（第一页）
  void _performSearch(String query) async {
    if (query.trim().isEmpty) return;
    
    Logger.debug('🔎 执行搜索: $query');

    setState(() {
      _isSearching = true;
      _currentQuery = query.trim();
      _currentPage = 1;
      _hasMore = true;
      _searchResults = [];
    });

    try {
      final results = await _apiService.searchSongs(
        keyword: _currentQuery,
        limit: _pageSize,
        page: 1,
      );

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
          // 如果结果数量等于pageSize，可能还有更多
          // 如果少于pageSize，说明已经是全部结果
          _hasMore = results.length >= _pageSize;
        });
        
        // 保存搜索历史
        _saveSearchHistory(_currentQuery);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
          _hasMore = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('搜索失败: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
  
  /// 加载更多
  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) {
      return;
    }
    
    setState(() {
      _isLoadingMore = true;
    });
    
    try {
      final nextPage = _currentPage + 1;
      final results = await _apiService.searchSongs(
        keyword: _currentQuery,
        limit: _pageSize,
        page: nextPage,
      );
      
      if (mounted) {
        setState(() {
          _searchResults.addAll(results);
          _currentPage = nextPage;
          _hasMore = results.length >= _pageSize;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载更多失败: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // 桌面端拖动区域
          if (PlatformUtils.isDesktop)
            const DraggableWindowBar(),
          Expanded(
            child: SafeArea(
              child: Column(
                children: [
                  SearchHeader(
                    isSelectionMode: _isSelectionMode,
                    selectedCount: _selectedIds.length,
                    totalCount: _searchResults.length,
                    hasSearchResults: _searchResults.isNotEmpty,
                    searchController: _searchController,
                    onSearchChanged: _onSearchChanged,
                    onSearchSubmitted: _performSearch,
                    onEnterSelectionMode: () {
                      setState(() {
                        _isSelectionMode = true;
                      });
                    },
                    onCancelSelectionMode: () {
                      setState(() {
                        _isSelectionMode = false;
                        _selectedIds.clear();
                      });
                    },
                    onToggleSelectAll: () {
                      setState(() {
                        if (_selectedIds.length == _searchResults.length) {
                          _selectedIds.clear();
                        } else {
                          _selectedIds.addAll(_searchResults.map((s) => s.id));
                        }
                      });
                    },
                    onBatchAddFavorites: _batchAddToFavorites,
                    onBatchDownload: _batchDownload,
                  ),
                  Expanded(
                    child: _buildContent(colors),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeColors colors) {
    if (_isSearching) {
      return _buildLoadingSkeleton(colors);
    }

    if (_searchController.text.isEmpty) {
      return _buildSearchSuggestions(colors);
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: colors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              '未找到相关结果',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
      );
    }
    return SearchResultsList(
      songs: _searchResults,
      isSelectionMode: _isSelectionMode,
      selectedIds: _selectedIds,
      isLoadingMore: _isLoadingMore,
      hasMore: _hasMore,
      scrollController: _scrollController,
      onSelectionChanged: (song, selected) {
        setState(() {
          if (selected) {
            _selectedIds.add(song.id);
          } else {
            _selectedIds.remove(song.id);
          }
        });
      },
      onSongTap: (song) {
        Provider.of<MusicProvider>(context, listen: false)
            .playSong(song, playlist: _searchResults);
      },
      onLoadMore: _loadMore,
      onMenuAction: (ctx, action, song) => _handleMenuAction(ctx, action, song),
    );
  }

  Widget _buildSearchSuggestions(ThemeColors colors) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        // 搜索历史
        if (_searchHistory.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '搜索历史',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              TextButton(
                onPressed: _clearSearchHistory,
                child: Text(
                  '清空',
                  style: TextStyle(color: colors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _searchHistory.map((history) {
              return ActionChip(
                label: Text(
                  history,
                  style: TextStyle(color: colors.textPrimary),
                ),
                backgroundColor: colors.card,
                avatar: Icon(
                  Icons.history,
                  size: 18,
                  color: colors.textSecondary,
                ),
                onPressed: () {
                  _searchController.text = history;
                  _performSearch(history);
                },
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
  
  /// 骨架屏加载效果
  Widget _buildLoadingSkeleton(ThemeColors colors) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: 10,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Shimmer.fromColors(
            baseColor: colors.card,
            highlightColor: colors.surface,
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 16,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: colors.card,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 14,
                        width: 150,
                        decoration: BoxDecoration(
                          color: colors.card,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 处理菜单操作
  Future<void> _handleMenuAction(BuildContext context, String action, Song song) async {
    final musicProvider = Provider.of<MusicProvider>(context, listen: false);
    
    switch (action) {
      case 'favorite':
        await musicProvider.toggleFavorite(song.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              musicProvider.isFavorite(song.id)
                  ? '已添加到我喜欢'
                  : '已从我喜欢中移除',
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
        break;
        
      case 'download':
        final manager = DownloadManager();
        await manager.init();
        final success = await manager.addDownload(song);
        
        if (!mounted) return;
        
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已添加到下载队列：${song.title}'),
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
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('《${song.title}》已在下载列表中'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        break;
        
      case 'play':
        musicProvider.playSong(song, playlist: _searchResults);
        break;
    }
  }

  /// 批量添加到喜欢
  Future<void> _batchAddToFavorites() async {
    final selectedSongs = _searchResults
        .where((s) => _selectedIds.contains(s.id))
        .toList();

    if (selectedSongs.isEmpty) return;

    final musicProvider = Provider.of<MusicProvider>(context, listen: false);
    int successCount = 0;

    for (final song in selectedSongs) {
      final isFavorite = musicProvider.isFavorite(song.id);
      if (!isFavorite) {
        final success = await musicProvider.toggleFavorite(song.id);
        if (success) successCount++;
      }
    }

    if (!mounted) return;

    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已添加 $successCount 首歌曲到我喜欢'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// 批量下载
  Future<void> _batchDownload() async {
    final selectedSongs = _searchResults
        .where((s) => _selectedIds.contains(s.id))
        .toList();

    if (selectedSongs.isEmpty) return;

    final manager = DownloadManager();
    await manager.init();

    int successCount = 0;
    for (final song in selectedSongs) {
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
}
