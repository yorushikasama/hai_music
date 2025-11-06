import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../providers/music_provider.dart';
import '../theme/app_styles.dart';
import '../providers/theme_provider.dart';
import '../services/music_api_service.dart';
import '../services/data_cache_service.dart';
import '../widgets/mini_player.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart' if (dart.library.html) '';

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

      print('✅ [PlaylistDetail] 从缓存加载 ${cachedSongs.length} 首歌曲，当前页码: $_currentPage');
    } else {
      // 使用传入的初始数据
      _allSongs = List.from(widget.playlist.songs);
      _filteredSongs = List.from(_allSongs);
      _totalCount = widget.totalCount;
      // 🔧 修复:根据已加载的歌曲数量计算当前页码
      _currentPage = (_allSongs.length / _pageSize).ceil();
      print('✅ [PlaylistDetail] 使用初始数据 ${_allSongs.length} 首歌曲，当前页码: $_currentPage');
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

          print('✅ [PlaylistDetail] 加载第 $_currentPage 页，新增 ${songsToAdd.length} 首歌曲，总计 ${_allSongs.length}/$_totalCount');

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
            print('✅ [PlaylistDetail] 已加载全部歌曲: ${_allSongs.length}/$_totalCount');
          }
        });

        // 保存到缓存 (每次加载后更新)
        _cacheService.savePlaylistDetail(widget.playlist.id, _allSongs, _totalCount);
      }
    } catch (e) {
      print('❌ [PlaylistDetail] 加载失败: $e');
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
          SliverAppBar(
            expandedHeight: 360,
            pinned: true,
            backgroundColor: colors.background,
            automaticallyImplyLeading: false,
            flexibleSpace: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: !kIsWeb ? (_) {
                try {
                  appWindow.startDragging();
                } catch (e) {
                  // 桌面平台支持窗口拖动
                }
              } : null,
              child: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                  // 背景模糊封面
                  CachedNetworkImage(
                    imageUrl: widget.playlist.coverUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: colors.card,
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: colors.card,
                    ),
                  ),
                  // 毛玻璃效果
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                    // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
                    child: Container(
                      color: colors.background.withValues(alpha: 0.7),
                    ),
                  ),
                  // 渐变遮罩
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
                        colors: [
                          Colors.black.withValues(alpha: 0.3),
                          colors.background.withValues(alpha: 0.5),
                          colors.background,
                        ],
                      ),
                    ),
                  ),
                  // 内容区域
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Spacer(),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 封面图
                              Container(
                                width: 160,
                                height: 160,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(AppStyles.radiusLarge),
                                  // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.3),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(AppStyles.radiusLarge),
                                  child: CachedNetworkImage(
                                    imageUrl: widget.playlist.coverUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      color: colors.card,
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          color: colors.accent,
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) => Container(
                                      color: colors.card,
                                      child: Icon(
                                        Icons.music_note_rounded,
                                        size: 64,
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 24),
                              // 歌单信息
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      widget.playlist.name,
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: colors.textPrimary,
                                        height: 1.2,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.music_note,
                                          size: 16,
                                          color: colors.textSecondary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$_totalCount 首歌曲',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: colors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ),
          ),
          // 歌曲列表标题
          SliverToBoxAdapter(
            child: Container(
              color: colors.background,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Row(
                children: [
                  Text(
                    '歌曲列表',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
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
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final song = _displayedSongs[index];
                return Container(
                  decoration: BoxDecoration(
                    color: colors.background,
                    // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
                    border: Border(
                      bottom: BorderSide(
                        color: colors.border.withValues(alpha: 0.3),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Provider.of<MusicProvider>(context, listen: false)
                            .playSong(song, playlist: _allSongs);
                      },
                      // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
                      hoverColor: colors.card.withValues(alpha: 0.5),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            // 序号
                            SizedBox(
                              width: 40,
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: colors.textSecondary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(width: 16),
                            // 歌曲信息
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    song.title,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: colors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    song.artist,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: colors.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            // 更多按钮
                            IconButton(
                              icon: Icon(
                                Icons.more_vert,
                                color: colors.textSecondary,
                                size: 20,
                              ),
                              onPressed: () {},
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
              childCount: _displayedSongs.length,
            ),
          ),
          if (_isLoadingMore)
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(20),
                color: colors.background,
                child: Center(
                  child: CircularProgressIndicator(color: colors.accent),
                ),
              ),
            )
          else if (!_hasMoreData && _displayedSongs.isNotEmpty)
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(20),
                color: colors.background,
                child: Center(
                  child: Text(
                    '已加载全部 $_totalCount 首歌曲',
                    style: TextStyle(
                      fontSize: 14,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ),
            )
          else
            SliverToBoxAdapter(
              child: Container(
                height: 100,
                color: colors.background,
              ),
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
}
