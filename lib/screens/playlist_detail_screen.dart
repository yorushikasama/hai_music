import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/playlist.dart';
import '../models/song.dart';
import '../providers/favorite_provider.dart';
import '../providers/music_provider.dart';
import '../providers/theme_provider.dart';
import '../repositories/music_repository.dart';
import '../services/download/download_service.dart';
import '../utils/download_utils.dart';
import '../utils/snackbar_util.dart';
import '../theme/app_styles.dart';
import '../widgets/mini_player.dart';
import 'download_progress_screen.dart';
import 'playlist/playlist_header.dart';
import 'playlist/playlist_songs_section.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final Playlist playlist;
  final int totalCount;
  final String qqNumber;

  const PlaylistDetailScreen({
    required this.playlist,
    required this.totalCount,
    required this.qqNumber,
    super.key,
  });

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  final _repository = MusicRepository();
  final int _pageSize = 60;
  int _currentPage = 1;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  int _totalCount = 0;
  List<Song> _allSongs = [];
  List<Song> _filteredSongs = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  Timer? _autoLoadTimer;
  final int _autoLoadInterval = 3;
  Timer? _searchDebounceTimer;

  @override
  void initState() {
    super.initState();
    _initPlaylist();
  }

  Future<void> _initPlaylist() async {
    final cachedData = await _repository.getPlaylistDetail(widget.playlist.id);
    if (cachedData != null) {
      final cachedSongs = (cachedData['songs'] as List<dynamic>?)?.cast<Song>().toList() ?? [];
      final cachedTotal = cachedData['totalCount'] as int? ?? 0;

      if (mounted) {
        setState(() {
          _allSongs = cachedSongs;
          _filteredSongs = List.from(_allSongs);
          _totalCount = cachedTotal > 0 ? cachedTotal : widget.totalCount;
          _currentPage = (_allSongs.length / _pageSize).ceil();
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _allSongs = List.from(widget.playlist.songs);
          _filteredSongs = List.from(_allSongs);
          _totalCount = widget.totalCount > 0 ? widget.totalCount : _allSongs.length;
          _currentPage = (_allSongs.length / _pageSize).ceil();
        });
      }
    }

    _scrollController.addListener(_onScroll);

    if (_allSongs.length >= _totalCount && _totalCount > 0) {
      _hasMoreData = false;
    } else {
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
      unawaited(_loadMoreSongs());
    });
  }

  void _stopAutoLoad() {
    _autoLoadTimer?.cancel();
    _autoLoadTimer = null;
  }

  void _onSearchChanged() {
    _searchDebounceTimer?.cancel();

    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      final query = _searchController.text.toLowerCase();
      if (mounted) {
        setState(() {
          if (query.isEmpty) {
            _filteredSongs = List.from(_allSongs);
            _isSearching = false;
          } else {
            _isSearching = true;
            _filteredSongs = _allSongs.where((song) {
              return song.title.toLowerCase().contains(query) ||
                  song.artist.toLowerCase().contains(query) ||
                  song.album.toLowerCase().contains(query);
            }).toList();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _stopAutoLoad();
    _searchDebounceTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMoreData) {
        unawaited(_loadMoreSongs());
      }
    }
  }

  Future<void> _loadMoreSongs() async {
    if (_isLoadingMore || !_hasMoreData) return;

    if (_totalCount > 0 && _allSongs.length >= _totalCount) {
      setState(() => _hasMoreData = false);
      _stopAutoLoad();
      return;
    }

    setState(() => _isLoadingMore = true);

    try {
      final result = await _repository.fetchPlaylistSongs(
        playlistId: widget.playlist.id,
        page: _currentPage + 1,
        num: _pageSize,
        uin: widget.qqNumber,
      );

      final List<Song> newSongs = (result['songs'] as List<dynamic>?)?.cast<Song>().toList() ?? [];
      final int apiTotalCount = result['totalCount'] as int? ?? 0;

      if (apiTotalCount > 0) {
        _totalCount = apiTotalCount;
      }

      if (mounted) {
        setState(() {
          _currentPage++;

          final existingIds = _allSongs.map((s) => s.id).toSet();
          final uniqueNewSongs = newSongs.where((s) => !existingIds.contains(s.id)).toList();

          _allSongs.addAll(uniqueNewSongs);
          _isLoadingMore = false;

          if (_isSearching) {
            _onSearchChanged();
          } else {
            _filteredSongs = List.from(_allSongs);
          }

          if (newSongs.isEmpty || (_totalCount > 0 && _allSongs.length >= _totalCount)) {
            _hasMoreData = false;
            _stopAutoLoad();
          }
        });

        unawaited(_repository.savePlaylistDetail(widget.playlist.id, _allSongs, _totalCount));
        _updatePlaylistIfPlaying();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  void _updatePlaylistIfPlaying() {
    final musicProvider = Provider.of<MusicProvider>(context, listen: false);
    final currentSong = musicProvider.currentSong;

    if (currentSong != null && _allSongs.any((song) => song.id == currentSong.id)) {
      musicProvider.updatePlaylist(_allSongs);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;
    final musicProvider = Provider.of<MusicProvider>(context);
    final hasCurrentSong = musicProvider.currentSong != null;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colors.background,
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                PlaylistHeader(
                  playlistName: widget.playlist.name,
                  coverUrl: widget.playlist.coverUrl,
                  songCount: _allSongs.length,
                  totalCount: _totalCount,
                  onPlayAll: () {
                    if (_allSongs.isNotEmpty) {
                      final mp = Provider.of<MusicProvider>(context, listen: false);
                      unawaited(mp.playSong(_allSongs.first, playlist: _allSongs));
                    }
                  },
                  onBack: () => Navigator.pop(context),
                ),
                    SliverToBoxAdapter(
                      child: Container(
                        color: colors.background,
                        padding: const EdgeInsets.fromLTRB(
                          AppStyles.spacingXL,
                          AppStyles.spacingL,
                          AppStyles.spacingXL,
                          AppStyles.spacingS,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isSelectionMode ? Icons.checklist_rounded : Icons.music_note_rounded,
                              color: _isSelectionMode ? colors.accent : colors.textPrimary,
                              size: 20,
                            ),
                            const SizedBox(width: AppStyles.spacingS),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isSelectionMode ? '选择歌曲' : '歌曲列表',
                                    style: textTheme.titleSmall,
                                  ),
                                  if (_isSelectionMode && _selectedIds.isNotEmpty)
                                    Text(
                                      '已选择 ${_selectedIds.length} 首',
                                      style: textTheme.labelSmall?.copyWith(
                                        color: colors.accent,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    )
                                  else if (!_isSelectionMode)
                                    Text(
                                      _totalCount > 0
                                          ? '已加载 ${_allSongs.length} / $_totalCount'
                                          : '已加载 ${_allSongs.length} 首',
                                      style: textTheme.labelMedium,
                                    ),
                                ],
                              ),
                            ),
                            if (_allSongs.isNotEmpty && !_isSelectionMode)
                              IconButton(
                                icon: Icon(Icons.checklist_rounded, color: colors.textSecondary, size: 22),
                                onPressed: () => setState(() => _isSelectionMode = true),
                                tooltip: '多选',
                              ),
                            if (_isSelectionMode) ...[
                              if (_selectedIds.isNotEmpty)
                                PopupMenuButton<String>(
                                  icon: Icon(Icons.more_vert, color: colors.textSecondary, size: 22),
                                  color: colors.surface,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: AppStyles.borderRadiusMedium,
                                  ),
                                  offset: const Offset(0, 50),
                                  itemBuilder: (context) => [
                                    PopupMenuItem<String>(
                                      value: 'favorite',
                                      child: Row(
                                        children: [
                                          Icon(Icons.favorite_border, color: colors.accent, size: 20),
                                          const SizedBox(width: AppStyles.spacingM),
                                          Text('批量喜欢', style: TextStyle(color: colors.textPrimary)),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem<String>(
                                      value: 'download',
                                      child: Row(
                                        children: [
                                          Icon(Icons.download_outlined, color: colors.accent, size: 20),
                                          const SizedBox(width: AppStyles.spacingM),
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
                                  padding: const EdgeInsets.symmetric(horizontal: AppStyles.spacingS),
                                  minimumSize: const Size(0, 36),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  _selectedIds.length == _filteredSongs.length ? '取消全选' : '全选',
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
                                padding: const EdgeInsets.all(AppStyles.spacingS),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Container(
                        color: colors.background,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppStyles.spacingXL,
                          vertical: AppStyles.spacingS,
                        ),
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
                                    onPressed: _searchController.clear,
                                  )
                                : null,
                            filled: true,
                            fillColor: colors.card,
                            border: OutlineInputBorder(
                              borderRadius: AppStyles.borderRadiusMedium,
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppStyles.spacingL,
                              vertical: AppStyles.spacingM,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_autoLoadTimer != null && _hasMoreData)
                      SliverToBoxAdapter(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppStyles.spacingXL,
                            vertical: AppStyles.spacingS,
                          ),
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
                              const SizedBox(width: AppStyles.spacingS),
                              Text(
                                '正在自动加载更多歌曲... (${_allSongs.length}/$_totalCount)',
                                style: textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    PlaylistSongsSection(
                      songs: _filteredSongs,
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
                      onMenuAction: _handleMenuAction,
                    ),
                  ],
                ),
              ),
              if (hasCurrentSong) const MiniPlayer(),
            ],
          ),
        );
  }

  Future<void> _batchAddToFavorites() async {
    final selectedSongs = _filteredSongs.where((s) => _selectedIds.contains(s.id)).toList();
    if (selectedSongs.isEmpty) return;

    final musicProvider = Provider.of<MusicProvider>(context, listen: false);
    final favoriteProvider = Provider.of<FavoriteProvider>(context, listen: false);
    int successCount = 0;

    for (final song in selectedSongs) {
      final isFavorite = favoriteProvider.isFavorite(song.id);
      if (!isFavorite) {
        final success = await favoriteProvider.toggleFavorite(
          song.id,
          currentSong: musicProvider.currentSong,
          playlist: musicProvider.playlist,
        );
        if (success) successCount++;
      }
    }

    if (!mounted) return;

    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });

    AppSnackBar.showWithContext(
      context,
      '已添加 $successCount 首歌曲到我喜欢',
      type: SnackBarType.success,
    );
  }

  Future<void> _batchDownload() async {
    final selectedSongs = _filteredSongs.where((s) => _selectedIds.contains(s.id)).toList();
    if (selectedSongs.isEmpty) return;

    final result = await DownloadService().batchAddDownloads(selectedSongs);

    if (!mounted) return;

    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });

    final message = result.alreadyExists > 0
        ? '已添加 ${result.added} 首歌曲到下载队列，${result.alreadyExists} 首已存在'
        : '已添加 ${result.added} 首歌曲到下载队列';

    AppSnackBar.showWithContext(
      context,
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

  Future<void> _handleMenuAction(BuildContext context, String action, Song song) async {
    final musicProvider = Provider.of<MusicProvider>(context, listen: false);
    final favoriteProvider = Provider.of<FavoriteProvider>(context, listen: false);
    switch (action) {
      case 'favorite':
        await favoriteProvider.toggleFavorite(
          song.id,
          currentSong: musicProvider.currentSong,
          playlist: musicProvider.playlist,
        );
        if (!mounted) return;
        AppSnackBar.showWithContext(
          context,
          favoriteProvider.isFavorite(song.id) ? '已添加到我喜欢' : '已从我喜欢中移除',
          type: favoriteProvider.isFavorite(song.id) ? SnackBarType.success : SnackBarType.info,
          icon: favoriteProvider.isFavorite(song.id) ? Icons.favorite : Icons.favorite_border,
        );
        break;

      case 'download':
        final result = await DownloadService().addDownload(song);
        if (!mounted) return;
        DownloadUtils.handleAddDownloadResult(context, result, song.title);
        break;

      case 'play':
        unawaited(musicProvider.playSong(song, playlist: _allSongs));
        break;
    }
  }
}
