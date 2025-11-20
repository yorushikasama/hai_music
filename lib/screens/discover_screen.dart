import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/song.dart';
import '../models/playlist.dart';
import '../providers/theme_provider.dart';
import '../theme/app_styles.dart';
import '../utils/responsive.dart';
import '../utils/platform_utils.dart';
import '../services/music_api_service.dart';
import '../services/playlist_scraper_service.dart';
import '../services/data_cache_service.dart';
import '../utils/logger.dart';
import 'playlist_detail_screen.dart';
import 'discover/discover_header.dart';
import 'discover/daily_recommendations_section.dart';

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
      Logger.error('加载每日推荐失败', e, null, 'DiscoverScreen');
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
      Logger.success('成功加载 ${selectedPlaylists.length} 个推荐歌单', 'DiscoverScreen');
      final futures = selectedPlaylists.map((playlist) =>
        _apiService.getPlaylistSongs(
          playlistId: playlist.id,
          page: 1,
          num: 30,
        ).then((result) => result['songs'] as List<Song>)
         .timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            Logger.network('从API加载推荐歌单', 'DiscoverScreen');
            return <Song>[];
          },
        )
         .catchError((e) {
          Logger.error('从API加载推荐歌单失败', e, null, 'DiscoverScreen');
          return <Song>[];
        })
      ).toList();

      // 添加总超时控制 (30秒)
      final songLists = await Future.wait(futures).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          Logger.network('从API加载推荐歌单', 'DiscoverScreen');
          return <List<Song>>[];
        },
      );

      for (final songs in songLists) {
        if (songs.isNotEmpty) {
          allSongs.addAll(songs);
        }
      }
      Logger.success('成功获取 ${allSongs.length} 首歌曲', 'DiscoverScreen');

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
      Logger.error('生成每日推荐失败', e, null, 'DiscoverScreen');
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
          Logger.info('开始加载推荐歌单...', 'DiscoverScreen');
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
      Logger.error('加载推荐歌单失败', e, null, 'DiscoverScreen');
      if (mounted) {
        setState(() => _isLoadingPlaylists = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final playlists = Playlist.getMockData();

    final isWeb = PlatformUtils.isWeb;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isWeb ? 1400 : double.infinity,
          ),
          child: CustomScrollView(
            slivers: [
              const DiscoverHeader(),
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    DailyRecommendationsSection(
                      dailyRecommendations: _dailyRecommendations,
                      isLoading: _isLoading,
                      scrollController: _dailyScrollController,
                      onRefresh: () => _loadDailyRecommendations(forceRefresh: true),
                    ),
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
            Logger.info('🎵 开始加载歌单: ${playlist.title} (ID: ${playlist.id})', 'DiscoverScreen');
            
            // 直接获取歌单歌曲（第一页）
            final result = await _apiService.getPlaylistSongs(
              playlistId: playlist.id,
              page: 1,
              num: 60,
            );
            
            Logger.debug('📊 歌单API返回结果: ${result.keys.toList()}', 'DiscoverScreen');
            
            final List<Song> songs = result['songs'] as List<Song>;
            final int totalCount = result['totalCount'] as int;
            
            Logger.info('✅ 歌单加载完成: ${songs.length} 首歌曲，总数: $totalCount', 'DiscoverScreen');

            if (!mounted) return;

            // 创建 Playlist 对象
            final playlistObj = Playlist(
              id: playlist.id,
              name: playlist.title,
              coverUrl: playlist.coverUrl,
              songs: songs,
            );

            if (!mounted) return;

            Navigator.pop(context); // 关闭加载对话框

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
            Logger.error('❌ 歌单加载失败: ${playlist.title} (ID: ${playlist.id})', e, null, 'DiscoverScreen');
            
            if (!mounted) return;

            Navigator.pop(context); // 关闭加载对话框

            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('加载歌单失败: $e'),
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
}
