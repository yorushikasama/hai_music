import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../models/song.dart';
import '../repositories/music_repository.dart';
import '../services/network/playlist_scraper_service.dart';
import '../theme/app_styles.dart';
import '../utils/logger.dart';
import '../utils/platform_utils.dart';
import 'discover/daily_recommendations_section.dart';
import 'discover/discover_header.dart';
import 'discover/recommended_playlists_section.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  static final _repository = MusicRepository();
  final _playlistScrollController = ScrollController();
  final _dailyScrollController = ScrollController();
  List<Song> _dailyRecommendations = [];
  List<RecommendedPlaylist> _recommendedPlaylists = [];
  bool _isLoading = true;
  bool _isLoadingPlaylists = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadRecommendedPlaylists());
  }

  @override
  void dispose() {
    _playlistScrollController.dispose();
    _dailyScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadDailyRecommendations({bool forceRefresh = false}) async {
    if (_recommendedPlaylists.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (!forceRefresh) {
        final cachedSongs = await _repository.getDailySongs();
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

      await _generateDailyRecommendations();
    } catch (e) {
      Logger.error('加载每日推荐失败', e, null, 'DiscoverScreen');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _generateDailyRecommendations() async {
    try {
      final random = Random();
      final allSongs = <Song>[];

      final playlistCount = min(3, _recommendedPlaylists.length);
      final selectedPlaylists = <RecommendedPlaylist>[];
      final playlistsCopy = List<RecommendedPlaylist>.from(_recommendedPlaylists);

      for (var i = 0; i < playlistCount; i++) {
        if (playlistsCopy.isEmpty) break;
        final index = random.nextInt(playlistsCopy.length);
        selectedPlaylists.add(playlistsCopy.removeAt(index));
      }

      Logger.success('成功加载 ${selectedPlaylists.length} 个推荐歌单', 'DiscoverScreen');
      final futures = selectedPlaylists.map((playlist) =>
        _repository.getPlaylistSongs(
          playlistId: playlist.id,
        ).then((result) => result['songs'] as List<Song>)
         .timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            Logger.network('从API加载推荐歌单', 'DiscoverScreen');
            return <Song>[];
          },
        )
         .catchError((Object e) {
          Logger.error('从API加载推荐歌单失败', e, null, 'DiscoverScreen');
          return <Song>[];
        })
      ).toList();

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

      if (allSongs.isNotEmpty) {
        allSongs.shuffle(random);
        final selectedSongs = allSongs.take(20).toList();

        await _repository.saveDailySongs(selectedSongs);

        if (mounted) {
          setState(() {
            _dailyRecommendations = selectedSongs;
            _isLoading = false;
          });
        }
      } else {
        final cachedSongs = await _repository.getDailySongs(cacheHours: 720);
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

  Future<void> _loadRecommendedPlaylists() async {
    setState(() => _isLoadingPlaylists = true);

    try {
      final cachedPlaylists = await _repository.getRecommendedPlaylists();
      if (cachedPlaylists != null && cachedPlaylists.isNotEmpty) {
        if (mounted) {
          setState(() {
            _recommendedPlaylists = cachedPlaylists;
            _isLoadingPlaylists = false;
          });
          unawaited(_loadDailyRecommendations());
        }
        return;
      }

      final playlists = await _repository.fetchRecommendedPlaylists().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          Logger.info('开始加载推荐歌单...', 'DiscoverScreen');
          return <RecommendedPlaylist>[];
        },
      );

      if (playlists.isNotEmpty) {
        await _repository.saveRecommendedPlaylists(playlists);

        if (mounted) {
          setState(() {
            _recommendedPlaylists = playlists;
            _isLoadingPlaylists = false;
          });
          unawaited(_loadDailyRecommendations());
        }
      } else {
        final oldCache = await _repository.getRecommendedPlaylists(cacheHours: 720);
        if (oldCache != null && oldCache.isNotEmpty) {
          if (mounted) {
            setState(() {
              _recommendedPlaylists = oldCache;
              _isLoadingPlaylists = false;
            });
            unawaited(_loadDailyRecommendations());
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
                    const SizedBox(height: AppStyles.spacingL),
                    DailyRecommendationsSection(
                      dailyRecommendations: _dailyRecommendations,
                      isLoading: _isLoading,
                      scrollController: _dailyScrollController,
                      onRefresh: () => _loadDailyRecommendations(forceRefresh: true),
                    ),
                    const SizedBox(height: AppStyles.spacingXXXL),
                    RecommendedPlaylistsSection(
                      playlists: _recommendedPlaylists,
                      isLoading: _isLoadingPlaylists,
                      scrollController: _playlistScrollController,
                      onRefresh: () async {
                        await _repository.clearRecommendedPlaylists();
                        unawaited(_loadRecommendedPlaylists());
                      },
                    ),
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
}
