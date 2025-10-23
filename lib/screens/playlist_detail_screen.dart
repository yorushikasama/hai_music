import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../providers/music_provider.dart';
import '../theme/app_styles.dart';
import '../providers/theme_provider.dart';
import '../services/music_api_service.dart';
import '../widgets/mini_player.dart';

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
  final int _pageSize = 60; // API限制：每页最多60首
  int _currentPage = 1;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  int _totalCount = 0;
  List<Song> _allSongs = [];

  @override
  void initState() {
    super.initState();
    _allSongs = List.from(widget.playlist.songs);
    _totalCount = widget.totalCount;
    _scrollController.addListener(_onScroll);
    // 检查是否还有更多数据
    if (_allSongs.length >= _totalCount) {
      _hasMoreData = false;
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
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
          _allSongs.addAll(newSongs);
          _totalCount = totalCount;
          _isLoadingMore = false;
          
          // 检查是否还有更多数据
          if (_allSongs.length >= _totalCount || newSongs.isEmpty) {
            _hasMoreData = false;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  List<Song> get _displayedSongs {
    return _allSongs;
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
            flexibleSpace: FlexibleSpaceBar(
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
                    child: Container(
                      color: colors.background.withOpacity(0.7),
                    ),
                  ),
                  // 渐变遮罩
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.3),
                          colors.background.withOpacity(0.5),
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
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
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
                                    const SizedBox(height: 20),
                                    // 播放全部按钮
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        if (_allSongs.isNotEmpty) {
                                          Provider.of<MusicProvider>(context, listen: false)
                                              .playSong(
                                            _allSongs.first,
                                            playlist: _allSongs,
                                          );
                                        }
                                      },
                                      icon: const Icon(Icons.play_arrow_rounded, size: 24),
                                      label: const Text(
                                        '播放全部',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: colors.accent,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 32,
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(AppStyles.radiusMedium),
                                        ),
                                        elevation: 4,
                                        shadowColor: colors.accent.withOpacity(0.4),
                                      ),
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
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final song = _displayedSongs[index];
                return Container(
                  decoration: BoxDecoration(
                    color: colors.background,
                    border: Border(
                      bottom: BorderSide(
                        color: colors.border.withOpacity(0.3),
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
                      hoverColor: colors.card.withOpacity(0.5),
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
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
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
