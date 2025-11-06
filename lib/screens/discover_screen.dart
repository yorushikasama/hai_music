import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/song.dart';
import '../models/playlist.dart';
import '../providers/music_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_styles.dart';
import '../utils/responsive.dart';
import '../utils/platform_utils.dart';
import '../widgets/theme_selector.dart';
import '../widgets/draggable_window_area.dart';
import '../services/music_api_service.dart';
import '../services/playlist_scraper_service.dart';
import '../services/data_cache_service.dart';
import 'playlist_detail_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final _apiService = MusicApiService();
  final _scraperService = PlaylistScraperService();
  final _cacheService = DataCacheService();
  final _playlistScrollController = ScrollController();
  final _dailyScrollController = ScrollController();
  List<Song> _dailyRecommendations = [];
  List<RecommendedPlaylist> _recommendedPlaylists = [];
  bool _isLoading = true;
  bool _isLoadingPlaylists = true;

  @override
  void initState() {
    super.initState();
    _initCache();
  }

  /// 初始化缓存服务
  Future<void> _initCache() async {
    await _cacheService.init();
    _loadRecommendedPlaylists();
  }

  @override
  void dispose() {
    _playlistScrollController.dispose();
    _dailyScrollController.dispose();
    super.dispose();
  }

  /// 从推荐歌单中随机选择歌曲作为每日推荐
  Future<void> _loadDailyRecommendations({bool forceRefresh = false}) async {
    if (_recommendedPlaylists.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 尝试从缓存加载
      if (!forceRefresh) {
        final cachedSongs = await _cacheService.getDailySongs();
        if (cachedSongs != null && cachedSongs.isNotEmpty) {
          if (mounted) {
            setState(() {
              _dailyRecommendations = cachedSongs;
              _isLoading = false;
            });
          }
          return;
        }
      }

      // 生成新的每日推荐
      await _generateDailyRecommendations();
    } catch (e) {
      print('❌ [Discover] 加载每日推荐失败: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  /// 生成新的每日推荐
  Future<void> _generateDailyRecommendations() async {
    try {
      final random = Random();
      final allSongs = <Song>[];

      // 随机选择2-3个歌单
      final playlistCount = min(3, _recommendedPlaylists.length);
      final selectedPlaylists = <RecommendedPlaylist>[];
      final playlistsCopy = List<RecommendedPlaylist>.from(_recommendedPlaylists);

      for (var i = 0; i < playlistCount; i++) {
        if (playlistsCopy.isEmpty) break;
        final index = random.nextInt(playlistsCopy.length);
        selectedPlaylists.add(playlistsCopy.removeAt(index));
      }

      // 并行获取所有歌单的歌曲（性能优化 + 超时控制）
      print('🚀 并行加载 ${selectedPlaylists.length} 个歌单...');
      final futures = selectedPlaylists.map((playlist) =>
        _apiService.getPlaylistSongs(
          playlistId: playlist.id,
          page: 1,
          num: 30,
        ).then((result) => result['songs'] as List<Song>)
         .timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            print('⏰ 加载歌单超时: ${playlist.title}');
            return <Song>[];
          },
        )
         .catchError((e) {
          print('⚠️ 加载歌单失败: ${playlist.title}');
          return <Song>[];
        })
      ).toList();

      // 添加总超时控制 (30秒)
      final songLists = await Future.wait(futures).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print('⏰ 并行加载总超时');
          return <List<Song>>[];
        },
      );

      for (final songs in songLists) {
        if (songs.isNotEmpty) {
          allSongs.addAll(songs);
        }
      }
      print('✅ 并行加载完成，共获取 ${allSongs.length} 首歌曲');

      // 从所有歌曲中随机选择20首
      if (allSongs.isNotEmpty) {
        allSongs.shuffle(random);
        final selectedSongs = allSongs.take(20).toList();

        // 保存到缓存
        await _cacheService.saveDailySongs(selectedSongs);

        if (mounted) {
          setState(() {
            _dailyRecommendations = selectedSongs;
            _isLoading = false;
          });
        }
      } else {
        // 生成失败,尝试使用旧缓存
        final cachedSongs = await _cacheService.getDailySongs(cacheHours: 720); // 30天内的旧缓存
        if (cachedSongs != null && cachedSongs.isNotEmpty) {
          if (mounted) {
            setState(() {
              _dailyRecommendations = cachedSongs;
              _isLoading = false;
            });
          }
        } else {
          if (mounted) {
            setState(() => _isLoading = false);
          }
        }
      }
    } catch (e) {
      print('❌ [Discover] 生成每日推荐失败: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// 加载推荐歌单
  Future<void> _loadRecommendedPlaylists() async {
    setState(() => _isLoadingPlaylists = true);

    try {
      // 尝试从缓存加载
      final cachedPlaylists = await _cacheService.getRecommendedPlaylists();
      if (cachedPlaylists != null && cachedPlaylists.isNotEmpty) {
        if (mounted) {
          setState(() {
            _recommendedPlaylists = cachedPlaylists;
            _isLoadingPlaylists = false;
          });
          // 加载每日推荐
          _loadDailyRecommendations();
        }
        return;
      }

      // 缓存不存在或已过期,爬取新数据
      final playlists = await _scraperService.fetchRecommendedPlaylists().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print('⏰ 爬取推荐歌单超时');
          return <RecommendedPlaylist>[];
        },
      );

      if (playlists.isNotEmpty) {
        // 保存到缓存
        await _cacheService.saveRecommendedPlaylists(playlists);

        if (mounted) {
          setState(() {
            _recommendedPlaylists = playlists;
            _isLoadingPlaylists = false;
          });
          // 加载每日推荐
          _loadDailyRecommendations();
        }
      } else {
        // 爬取失败,尝试使用旧缓存 (30天内)
        final oldCache = await _cacheService.getRecommendedPlaylists(cacheHours: 720);
        if (oldCache != null && oldCache.isNotEmpty) {
          if (mounted) {
            setState(() {
              _recommendedPlaylists = oldCache;
              _isLoadingPlaylists = false;
            });
            _loadDailyRecommendations();
          }
        } else {
          if (mounted) {
            setState(() => _isLoadingPlaylists = false);
          }
        }
      }
    } catch (e) {
      print('❌ [Discover] 加载推荐歌单失败: $e');
      if (mounted) {
        setState(() => _isLoadingPlaylists = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final playlists = Playlist.getMockData();

    final isWeb = PlatformUtils.isWeb;
    final isDesktop = Responsive.isDesktop(context);
    final padding = Responsive.getHorizontalPadding(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isWeb ? 1400 : double.infinity,
          ),
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                floating: true,
                pinned: false,
                expandedHeight: 100,
                backgroundColor: Colors.transparent,
                flexibleSpace: Stack(
                  children: [
                    FlexibleSpaceBar(
                      title: Text(
                        'Hai Music',
                        style: Theme.of(context).textTheme.headlineLarge!,
                      ),
                      titlePadding: EdgeInsets.only(left: padding.left, bottom: 16),
                    ),
                    // 桌面端拖动区域
                    if (PlatformUtils.isDesktop)
                      const Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 40,
                        child: DraggableWindowBar(),
                      ),
                  ],
                ),
                actions: !isDesktop ? [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: IconButton(
                      icon: Text(
                        themeProvider.getThemeIcon(themeProvider.currentTheme),
                        style: const TextStyle(fontSize: 24),
                      ),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          builder: (context) => const ThemeSelector(),
                        );
                      },
                    ),
                  ),
                ] : null,
              ),
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    _buildDailyRecommendations(context),
                    const SizedBox(height: 32),
                    _buildRecommendedPlaylists(context, playlists),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDailyRecommendations(BuildContext context) {
    final padding = Responsive.getHorizontalPadding(context);
    final colors = Provider.of<ThemeProvider>(context).colors;
    final today = DateTime.now();
    final dateStr = '${today.month}月${today.day}日';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: padding,
          child: Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 24,
                color: colors.accent,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '每日推荐',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$dateStr · 根据你的口味精选',
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (!_isLoading)
                IconButton(
                  icon: Icon(Icons.refresh, color: colors.accent),
                  onPressed: () => _loadDailyRecommendations(forceRefresh: true),
                  tooltip: '刷新推荐',
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (_isLoading)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: CircularProgressIndicator(color: colors.accent),
            ),
          )
        else if (_dailyRecommendations.isEmpty)
          Padding(
            padding: padding,
            child: Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(AppStyles.radiusLarge),
                border: Border.all(color: colors.border),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.cloud_off,
                      size: 48,
                      color: colors.textSecondary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '加载推荐失败',
                      style: TextStyle(
                        fontSize: 16,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Stack(
            children: [
              SizedBox(
                height: 280,
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    dragDevices: {
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                    },
                  ),
                  child: ListView.builder(
                    controller: _dailyScrollController,
                    scrollDirection: Axis.horizontal,
                    padding: padding,
                    itemCount: _dailyRecommendations.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: _buildLargeSongCard(
                          context,
                          _dailyRecommendations[index],
                          () {
                            Provider.of<MusicProvider>(context, listen: false)
                                .playSong(_dailyRecommendations[index], playlist: _dailyRecommendations);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
              // 左箭头按钮 (仅桌面端显示)
              if (Responsive.isDesktop(context))
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Container(
                      // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
                    margin: const EdgeInsets.only(left: 8),
                      decoration: BoxDecoration(
                        color: colors.card.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(Icons.chevron_left, color: colors.textPrimary),
                        onPressed: () {
                          _dailyScrollController.animateTo(
                            _dailyScrollController.offset - 400,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                      ),
                    ),
                  ),
                ),
              // 右箭头按钮 (仅桌面端显示)
              if (Responsive.isDesktop(context))
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Container(
                      // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
                    margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: colors.card.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(Icons.chevron_right, color: colors.textPrimary),
                        onPressed: () {
                          _dailyScrollController.animateTo(
                            _dailyScrollController.offset + 400,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                      ),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildRecommendedPlaylists(BuildContext context, List<Playlist> playlists) {
    final padding = Responsive.getHorizontalPadding(context);
    final colors = Provider.of<ThemeProvider>(context).colors;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: padding,
          child: Row(
            children: [
              Text(
                '推荐歌单',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const Spacer(),
              if (!_isLoadingPlaylists && _recommendedPlaylists.isNotEmpty)
                IconButton(
                  icon: Icon(Icons.refresh, color: colors.accent),
                  onPressed: () async {
                    await _cacheService.clearRecommendedPlaylists();
                    _loadRecommendedPlaylists();
                  },
                  tooltip: '刷新推荐',
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_isLoadingPlaylists)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: CircularProgressIndicator(color: colors.accent),
            ),
          )
        else if (_recommendedPlaylists.isEmpty)
          Padding(
            padding: padding,
            child: Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(AppStyles.radiusLarge),
                border: Border.all(color: colors.border),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.cloud_off,
                      size: 48,
                      color: colors.textSecondary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '加载推荐歌单失败',
                      style: TextStyle(
                        fontSize: 16,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Stack(
            children: [
              SizedBox(
                height: 280,
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    dragDevices: {
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                    },
                  ),
                  child: ListView.builder(
                    controller: _playlistScrollController,
                    scrollDirection: Axis.horizontal,
                    padding: padding,
                    itemCount: _recommendedPlaylists.length,
                    itemBuilder: (context, index) {
                      final playlist = _recommendedPlaylists[index];
                      return Padding(
                        padding: const EdgeInsets.only(right: 20),
                        child: _buildRecommendedPlaylistCard(
                          context,
                          playlist,
                        ),
                      );
                    },
                  ),
                ),
              ),
              // 左箭头按钮 (仅桌面端显示)
              if (Responsive.isDesktop(context))
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
                    child: Container(
                      margin: const EdgeInsets.only(left: 8),
                      decoration: BoxDecoration(
                        color: colors.card.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(Icons.chevron_left, color: colors.textPrimary),
                        onPressed: () {
                          _playlistScrollController.animateTo(
                            _playlistScrollController.offset - 400,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                      ),
                    ),
                  ),
                ),
              // 右箭头按钮 (仅桌面端显示)
              if (Responsive.isDesktop(context))
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: colors.card.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(Icons.chevron_right, color: colors.textPrimary),
                        onPressed: () {
                          _playlistScrollController.animateTo(
                            _playlistScrollController.offset + 400,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                      ),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
  
  Widget _buildRecommendedPlaylistCard(BuildContext context, RecommendedPlaylist playlist) {
    final colors = Provider.of<ThemeProvider>(context).colors;
    
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () async {
          // 显示加载对话框
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(AppStyles.radiusLarge),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: colors.accent),
                    const SizedBox(height: 16),
                    Text(
                      '加载中...',
                      style: TextStyle(color: colors.textPrimary),
                    ),
                  ],
                ),
              ),
            ),
          );

          try {
            // 使用dissid获取歌单歌曲列表（第一页，60首）
            final result = await _apiService.getPlaylistSongs(
              playlistId: playlist.id,
              page: 1,
              num: 60,
            );
            
            final List<Song> songs = result['songs'] as List<Song>;
            final int totalCount = result['totalCount'] as int;

            if (!mounted) return;

            Navigator.pop(context); // 关闭加载对话框

            // 创建包含歌曲的Playlist对象
            final playlistObj = Playlist(
              id: playlist.id,
              name: playlist.title,
              coverUrl: playlist.coverUrl,
              description: '',
              songs: songs,
            );

            if (!mounted) return;

            // 跳转到歌单详情页
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PlaylistDetailScreen(
                  playlist: playlistObj,
                  totalCount: totalCount,
                  qqNumber: '', // 推荐歌单不需要QQ号
                ),
              ),
            );
          } catch (e) {
            if (!mounted) return;

            Navigator.pop(context); // 关闭加载对话框

            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('加载歌单失败,请稍后重试'),
                backgroundColor: colors.card,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        child: Container(
          width: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppStyles.radiusLarge),
            // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
          boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 封面图片
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppStyles.radiusLarge),
                    child: AspectRatio(
                      aspectRatio: 1,
                      // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
                      child: CachedNetworkImage(
                        imageUrl: playlist.coverUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: colors.card.withValues(alpha: 0.5),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: colors.accent,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                colors.card,
                                colors.card.withValues(alpha: 0.7),
                              ],
                            ),
                          ),
                          child: Icon(
                            Icons.music_note_rounded,
                            size: 64,
                            color: colors.textSecondary.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // 悬停时显示播放按钮
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppStyles.radiusLarge),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: null, // 由外层GestureDetector处理
                          child: Container(
                            decoration: BoxDecoration(
                              // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
                            gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.3),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 标题
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  playlist.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildLargeSongCard(BuildContext context, Song song, VoidCallback onTap) {
    final colors = Provider.of<ThemeProvider>(context).colors;
    final coverOverlay = colors.isLight ? 0.0 : 0.5; // 浅色主题无遮罩
    
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 200,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppStyles.radiusLarge),
                child: BackdropFilter(
                  filter: AppStyles.backdropBlur,
                  child: Container(
                    decoration: AppStyles.glassDecoration(
                      color: colors.card,
                      opacity: 0.6,
                      borderColor: colors.border,
                      isLight: colors.isLight,
                      borderRadius: BorderRadius.circular(AppStyles.radiusLarge),
                    ),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppStyles.radiusLarge),
                            // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
                            child: CachedNetworkImage(
                              imageUrl: song.coverUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: colors.card.withValues(alpha: 0.5),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: colors.card,
                                child: Icon(
                                  Icons.music_note,
                                  size: 60,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                          // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
                          if (coverOverlay > 0)
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(AppStyles.radiusLarge),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: coverOverlay),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: AppStyles.spacingM),
              Text(
                song.title,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: AppStyles.spacingXS),
              Text(
                song.artist,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
