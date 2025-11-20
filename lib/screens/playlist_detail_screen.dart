import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/logger.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../providers/music_provider.dart';
import '../theme/app_styles.dart';
import '../providers/theme_provider.dart';
import '../services/music_api_service.dart';
import '../services/data_cache_service.dart';
import '../services/download_manager.dart';
import '../widgets/mini_player.dart';
import 'download_progress_screen.dart';
import 'playlist/playlist_songs_section.dart';
import 'playlist/playlist_header.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final Playlist playlist;
  final int totalCount;
  final String qqNumber;

  const PlaylistDetailScreen({
    super.key,
    required this.playlist,
    required this.totalCount,
    required this.qqNumber,
  });

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  final _apiService = MusicApiService();
  final _cacheService = DataCacheService();
  final int _pageSize = 60; // API限制：每页最多60首
  int _currentPage = 1;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  int _totalCount = 0;
  List<Song> _allSongs = [];
  List<Song> _filteredSongs = []; // 搜索过滤后的歌曲
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  // 自动加载相关
  Timer? _autoLoadTimer;
  // 🔧 优化:将不会改变的字段标记为 final
  final int _autoLoadInterval = 3; // 每3秒自动加载一次

  // 搜索防抖
  Timer? _searchDebounceTimer;

  @override
  void initState() {
    super.initState();
    _initPlaylist();
  }

  /// 初始化歌单
  Future<void> _initPlaylist() async {
    await _cacheService.init();

    // 尝试从缓存加载
    final cachedData = await _cacheService.getPlaylistDetail(widget.playlist.id);
    if (cachedData != null) {
      final cachedSongs = cachedData['songs'] as List<Song>;
      final cachedTotal = cachedData['totalCount'] as int;

      if (mounted) {
        setState(() {
          _allSongs = cachedSongs;
          _filteredSongs = List.from(_allSongs);
          _totalCount = cachedTotal;
          // 🔧 修复:根据已加载的歌曲数量计算当前页码
          _currentPage = (_allSongs.length / _pageSize).ceil();
        });
      }

      Logger.debug('✅ [PlaylistDetail] 从缓存加载 ${cachedSongs.length} 首歌曲，当前页码: $_currentPage');
    } else {
      // 使用传入的初始数据
      _allSongs = List.from(widget.playlist.songs);
      _filteredSongs = List.from(_allSongs);
      _totalCount = widget.totalCount;
      // 🔧 修复:根据已加载的歌曲数量计算当前页码
      _currentPage = (_allSongs.length / _pageSize).ceil();
      Logger.debug('✅ [PlaylistDetail] 使用初始数据 ${_allSongs.length} 首歌曲，总数: $_totalCount，当前页码: $_currentPage');
    }

    _scrollController.addListener(_onScroll);

    // 检查是否还有更多数据
    if (_allSongs.length >= _totalCount) {
      _hasMoreData = false;
    } else {
      // 启动自动加载
      _startAutoLoad();
    }

    _searchController.addListener(_onSearchChanged);
  }
  
  void _startAutoLoad() {
    if (!_hasMoreData) return;
    
    _autoLoadTimer = Timer.periodic(Duration(seconds: _autoLoadInterval), (timer) {
      if (!mounted || !_hasMoreData || _isLoadingMore) {
        timer.cancel();
        return;
      }
      _loadMoreSongs();
    });
  }
  
  void _stopAutoLoad() {
    _autoLoadTimer?.cancel();
    _autoLoadTimer = null;
  }

  /// 搜索变化处理 (带防抖)
  void _onSearchChanged() {
    // 取消之前的定时器
    _searchDebounceTimer?.cancel();

    // 设置新的防抖定时器 (300ms)
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      final query = _searchController.text.toLowerCase();
      if (mounted) {
        setState(() {
          if (query.isEmpty) {
            _filteredSongs = List.from(_allSongs);
            _isSearching = false;
          } else {
            _isSearching = true;
            // 🔧 优化:移除不必要的 ?. 操作符
            _filteredSongs = _allSongs.where((song) {
              return song.title.toLowerCase().contains(query) ||
                     song.artist.toLowerCase().contains(query) ||
                     (song.album.toLowerCase().contains(query));
            }).toList();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _stopAutoLoad(); // 停止自动加载
    _searchDebounceTimer?.cancel(); // 取消搜索防抖定时器
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMoreData) {
        _loadMoreSongs();
      }
    }
  }

  void _loadMoreSongs() async {
    if (_isLoadingMore || !_hasMoreData) return;

    // 🔧 修复:检查是否已经加载完所有歌曲
    if (_allSongs.length >= _totalCount) {
      setState(() {
        _hasMoreData = false;
      });
      _stopAutoLoad();
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    try {
      // 从 API 加载下一页
      final result = await _apiService.getPlaylistSongs(
        playlistId: widget.playlist.id,
        page: _currentPage + 1,
        num: _pageSize,
        uin: widget.qqNumber,
      );

      final List<Song> newSongs = result['songs'] as List<Song>;
      final int totalCount = result['totalCount'] as int;

      if (mounted) {
        setState(() {
          _currentPage++;

          // 🔧 修复:只添加不重复的歌曲，并确保不超过总数
          final existingIds = _allSongs.map((s) => s.id).toSet();
          final uniqueNewSongs = newSongs.where((s) => !existingIds.contains(s.id)).toList();

          // 🔧 修复:确保不超过总数
          final remainingCount = totalCount - _allSongs.length;
          final songsToAdd = uniqueNewSongs.take(remainingCount).toList();

          _allSongs.addAll(songsToAdd);
          _totalCount = totalCount;
          _isLoadingMore = false;

          Logger.debug('✅ [PlaylistDetail] 加载第 $_currentPage 页，新增 ${songsToAdd.length} 首歌曲，总计 ${_allSongs.length}/$_totalCount');

          // 更新过滤列表
          if (_isSearching) {
            _onSearchChanged();
          } else {
            _filteredSongs = List.from(_allSongs);
          }

          // 检查是否还有更多数据
          if (_allSongs.length >= _totalCount || newSongs.isEmpty) {
            _hasMoreData = false;
            _stopAutoLoad(); // 停止自动加载
            Logger.debug('✅ [PlaylistDetail] 已加载全部歌曲: ${_allSongs.length}/$_totalCount');
          }
        });

        // 保存到缓存 (每次加载后更新)
        _cacheService.savePlaylistDetail(widget.playlist.id, _allSongs, _totalCount);
        
        // 🔧 修复播放列表同步问题：如果当前正在播放这个歌单的歌曲，更新播放列表
        _updatePlaylistIfPlaying();
      }
    } catch (e) {
      Logger.debug('❌ [PlaylistDetail] 加载失败: $e');
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  List<Song> get _displayedSongs {
    return _filteredSongs;
  }
  
  /// 如果当前正在播放这个歌单的歌曲，更新播放列表
  void _updatePlaylistIfPlaying() {
    final musicProvider = Provider.of<MusicProvider>(context, listen: false);
    final currentSong = musicProvider.currentSong;
    
    // 检查当前播放的歌曲是否在这个歌单中
    if (currentSong != null && _allSongs.any((song) => song.id == currentSong.id)) {
      Logger.debug('🔄 [PlaylistDetail] 更新播放列表: ${_allSongs.length} 首歌曲', 'PlaylistDetail');
      // 更新播放列表，但保持当前播放的歌曲不变
      musicProvider.updatePlaylist(_allSongs);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;
    final musicProvider = Provider.of<MusicProvider>(context);
    final hasCurrentSong = musicProvider.currentSong != null;
    
    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  controller: _scrollController,
                  slivers: [
          PlaylistDetailHeader(
            playlist: widget.playlist,
            totalCount: _totalCount,
          ),
          // 歌曲列表标题
          SliverToBoxAdapter(
            child: Container(
              color: colors.background,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Row(
                children: [
                  Icon(
                    _isSelectionMode ? Icons.checklist_rounded : Icons.music_note,
                    color: _isSelectionMode ? colors.accent : colors.textPrimary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isSelectionMode ? '选择歌曲' : '歌曲列表',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                        if (_isSelectionMode && _selectedIds.isNotEmpty)
                          Text(
                            '已选择 ${_selectedIds.length} 首',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.accent,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        else if (!_isSelectionMode)
                          Text(
                            '已加载 ${_allSongs.length}/$_totalCount',
                            style: TextStyle(
                              fontSize: 14,
                              color: colors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_allSongs.isNotEmpty && !_isSelectionMode)
                    IconButton(
                      icon: Icon(Icons.checklist_rounded, color: colors.textSecondary, size: 22),
                      onPressed: () {
                        setState(() {
                          _isSelectionMode = true;
                        });
                      },
                      tooltip: '多选',
                    ),
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
                            value: 'favorite',
                            child: Row(
                              children: [
                                Icon(Icons.favorite_border, color: colors.accent, size: 20),
                                const SizedBox(width: 12),
                                Text('批量喜欢', style: TextStyle(color: colors.textPrimary)),
                              ],
                            ),
                          ),
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
                        ],
                        onSelected: (value) {
                          if (value == 'favorite') {
                            _batchAddToFavorites();
                          } else if (value == 'download') {
                            _batchDownload();
                          }
                        },
                      ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          if (_selectedIds.length == _filteredSongs.length) {
                            _selectedIds.clear();
                          } else {
                            _selectedIds.addAll(_filteredSongs.map((s) => s.id));
                          }
                        });
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        _selectedIds.length == _filteredSongs.length ? '全选' : '全选',
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
                  ],
                ],
              ),
            ),
          ),
          // 搜索框
          SliverToBoxAdapter(
            child: Container(
              color: colors.background,
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: colors.textPrimary),
                decoration: InputDecoration(
                  hintText: '搜索歌曲、歌手、专辑...',
                  hintStyle: TextStyle(color: colors.textSecondary),
                  prefixIcon: Icon(Icons.search, color: colors.textSecondary),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: colors.textSecondary),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: colors.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),
          // 加载状态提示
          if (_autoLoadTimer != null && _hasMoreData)
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(colors.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '正在自动加载更多歌曲... (${_allSongs.length}/$_totalCount)',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          PlaylistSongsSection(
            songs: _displayedSongs,
            isSelectionMode: _isSelectionMode,
            selectedIds: _selectedIds,
            isLoadingMore: _isLoadingMore,
            hasMoreData: _hasMoreData,
            totalCount: _totalCount,
            onSongTap: (song) {
              Provider.of<MusicProvider>(context, listen: false)
                  .playSong(song, playlist: _allSongs);
            },
            onSelectionChanged: (song, selected) {
              setState(() {
                if (selected) {
                  _selectedIds.add(song.id);
                } else {
                  _selectedIds.remove(song.id);
                }
              });
            },
            onMenuAction: (ctx, action, song) => _handleMenuAction(ctx, action, song),
          ),
              ],
            ),
          ),
          if (hasCurrentSong) const MiniPlayer(),
            ],
          ),
          // 固定的返回按钮
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: _buildBackButton(context, colors),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackButton(BuildContext context, ThemeColors colors) {
    return Container(
      margin: const EdgeInsets.all(8),
      width: 48,
      height: 48,
      // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        shape: BoxShape.circle,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.pop(context),
          borderRadius: BorderRadius.circular(24),
          child: const Center(
            child: Icon(
              Icons.arrow_back,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  /// 批量添加到喜欢
  Future<void> _batchAddToFavorites() async {
    final selectedSongs = _filteredSongs
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
    final selectedSongs = _filteredSongs
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

  /// 处理单曲菜单操作
  Future<void> _handleMenuAction(BuildContext context, String action, Song song) async {
    final musicProvider = Provider.of<MusicProvider>(context, listen: false);
    
    switch (action) {
      case 'favorite':
        await musicProvider.toggleFavorite(song.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  musicProvider.isFavorite(song.id) ? Icons.favorite : Icons.favorite_border,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    musicProvider.isFavorite(song.id)
                        ? '已添加到我喜欢'
                        : '已从我喜欢中移除',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: musicProvider.isFavorite(song.id)
                ? Colors.red.shade700
                : Colors.grey.shade700,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
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
              content: Row(
                children: [
                  const Icon(Icons.download, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '已添加到下载队列：${song.title}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.blue.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
              action: SnackBarAction(
                label: '查看',
                textColor: Colors.white,
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
              content: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '《${song.title}》已在下载列表中',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.orange.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
        break;
        
      case 'play':
        musicProvider.playSong(song, playlist: _allSongs);
        break;
    }
  }
}
