import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/song.dart';
import '../models/playlist.dart';
import '../providers/music_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_styles.dart';
import '../utils/responsive.dart';
import '../widgets/playlist_card.dart';
import '../widgets/theme_selector.dart';
import '../services/music_api_service.dart';
import '../services/playlist_scraper_service.dart';
import 'playlist_detail_screen.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart' if (dart.library.html) '';
import 'package:shared_preferences/shared_preferences.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final _apiService = MusicApiService();
  final _scraperService = PlaylistScraperService();
  final _playlistScrollController = ScrollController();
  final _dailyScrollController = ScrollController();
  List<Song> _dailyRecommendations = [];
  List<RecommendedPlaylist> _recommendedPlaylists = [];
  bool _isLoading = true;
  bool _isLoadingPlaylists = true;
  
  static const String _playlistsCacheKey = 'cached_playlists';
  static const String _playlistsTimestampKey = 'playlists_timestamp';
  static const String _dailySongsCacheKey = 'cached_daily_songs';
  static const String _dailySongsTimestampKey = 'daily_songs_timestamp';

  @override
  void initState() {
    super.initState();
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
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getStringList(_dailySongsCacheKey);
      final cachedTimestamp = prefs.getInt(_dailySongsTimestampKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // 检查缓存是否过期(24小时)
      final cacheExpired = (now - cachedTimestamp) > 24 * 60 * 60 * 1000;
      
      if (forceRefresh || cacheExpired || cachedData == null || cachedData.isEmpty) {
        // 生成新的每日推荐
        await _generateDailyRecommendations(prefs, now);
      } else {
        // 使用缓存
        _loadDailySongsFromCache(prefs);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  /// 生成新的每日推荐
  Future<void> _generateDailyRecommendations(SharedPreferences prefs, int now) async {
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
      
      // 并行获取所有歌单的歌曲（性能优化）
      print('🚀 并行加载 ${selectedPlaylists.length} 个歌单...');
      final futures = selectedPlaylists.map((playlist) => 
        _apiService.getPlaylistSongs(
          playlistId: playlist.id,
          page: 1,
          num: 30,
        ).then((result) => result['songs'] as List<Song>)
         .catchError((e) {
          print('⚠️ 加载歌单失败: ${playlist.title}');
          return <Song>[];
        })
      ).toList();

      final songLists = await Future.wait(futures);
      
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
        final songsJson = selectedSongs.map((s) => 
          '${s.id}|||${s.title}|||${s.artist}|||${s.album}|||${s.coverUrl}'
        ).toList();
        await prefs.setStringList(_dailySongsCacheKey, songsJson);
        await prefs.setInt(_dailySongsTimestampKey, now);
        
        if (mounted) {
          setState(() {
            _dailyRecommendations = selectedSongs;
            _isLoading = false;
          });
        }
      } else {
        // 生成失败,尝试使用旧缓存
        final cachedData = prefs.getStringList(_dailySongsCacheKey);
        if (cachedData != null && cachedData.isNotEmpty) {
          _loadDailySongsFromCache(prefs);
        } else {
          if (mounted) {
            setState(() => _isLoading = false);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  /// 从缓存加载每日推荐
  void _loadDailySongsFromCache(SharedPreferences prefs) {
    final cachedSongs = prefs.getStringList(_dailySongsCacheKey) ?? [];
    
    final songs = cachedSongs.map((json) {
      final parts = json.split('|||');
      if (parts.length == 5) {
        return Song(
          id: parts[0],
          title: parts[1],
          artist: parts[2],
          album: parts[3],
          coverUrl: parts[4],
          audioUrl: '',
          duration: 180, // 3分钟
          platform: 'qq',
        );
      }
      return null;
    }).whereType<Song>().toList();
    
    if (mounted) {
      setState(() {
        _dailyRecommendations = songs;
        _isLoading = false;
      });
    }
  }

  /// 加载推荐歌单
  Future<void> _loadRecommendedPlaylists() async {
    setState(() => _isLoadingPlaylists = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getStringList(_playlistsCacheKey);
      final cachedTimestamp = prefs.getInt(_playlistsTimestampKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // 检查缓存是否过期(24小时)
      final cacheExpired = (now - cachedTimestamp) > 24 * 60 * 60 * 1000;
      
      if (cacheExpired || cachedData == null || cachedData.isEmpty) {
        // 爬取新数据
        final playlists = await _scraperService.fetchRecommendedPlaylists();
        
        if (playlists.isNotEmpty) {
          // 保存到缓存
          final playlistsJson = playlists.map((p) => '${p.id}|||${p.title}|||${p.coverUrl}').toList();
          await prefs.setStringList(_playlistsCacheKey, playlistsJson);
          await prefs.setInt(_playlistsTimestampKey, now);
          
          if (mounted) {
            setState(() {
              _recommendedPlaylists = playlists;
              _isLoadingPlaylists = false;
            });
            // 加载每日推荐
            _loadDailyRecommendations();
          }
        } else {
          // 爬取失败,尝试使用旧缓存
          if (cachedData != null && cachedData.isNotEmpty) {
            _loadPlaylistsFromCache(prefs);
          } else {
            if (mounted) {
              setState(() => _isLoadingPlaylists = false);
            }
          }
        }
      } else {
        // 使用缓存
        _loadPlaylistsFromCache(prefs);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingPlaylists = false);
      }
    }
  }
  
  /// 从缓存加载歌单
  void _loadPlaylistsFromCache(SharedPreferences prefs) {
    final cachedPlaylists = prefs.getStringList(_playlistsCacheKey) ?? [];
    
    final playlists = cachedPlaylists.map((json) {
      final parts = json.split('|||');
      if (parts.length == 3) {
        return RecommendedPlaylist(
          id: parts[0],
          title: parts[1],
          coverUrl: parts[2],
        );
      }
      return null;
    }).whereType<RecommendedPlaylist>().toList();
    
    if (mounted) {
      setState(() {
        _recommendedPlaylists = playlists;
        _isLoadingPlaylists = false;
      });
      // 加载每日推荐
      _loadDailyRecommendations();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final playlists = Playlist.getMockData();

    final isWeb = kIsWeb;
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
                    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux))
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 40,
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onPanStart: (_) {
                            try {
                              appWindow.startDragging();
                            } catch (e) {
                              // 忽略错误
                            }
                          },
                        ),
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
                      margin: const EdgeInsets.only(left: 8),
                      decoration: BoxDecoration(
                        color: colors.card.withOpacity(0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
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
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: colors.card.withOpacity(0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
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
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove(_playlistsTimestampKey);
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
                    child: Container(
                      margin: const EdgeInsets.only(left: 8),
                      decoration: BoxDecoration(
                        color: colors.card.withOpacity(0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
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
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: colors.card.withOpacity(0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
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

            if (mounted) {
              Navigator.pop(context); // 关闭加载对话框
              
              // 创建包含歌曲的Playlist对象
              final playlistObj = Playlist(
                id: playlist.id,
                name: playlist.title,
                coverUrl: playlist.coverUrl,
                description: '',
                songs: songs,
              );
              
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
            }
          } catch (e) {
            if (mounted) {
              Navigator.pop(context); // 关闭加载对话框
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('加载歌单失败,请稍后重试'),
                  backgroundColor: colors.card,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        },
        child: Container(
          width: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppStyles.radiusLarge),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
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
                      child: CachedNetworkImage(
                        imageUrl: playlist.coverUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: colors.card.withOpacity(0.5),
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
                                colors.card.withOpacity(0.7),
                              ],
                            ),
                          ),
                          child: Icon(
                            Icons.music_note_rounded,
                            size: 64,
                            color: colors.textSecondary.withOpacity(0.5),
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
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.3),
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
                            child: CachedNetworkImage(
                              imageUrl: song.coverUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: colors.card.withOpacity(0.5),
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
                          if (coverOverlay > 0)
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(AppStyles.radiusLarge),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(coverOverlay),
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
