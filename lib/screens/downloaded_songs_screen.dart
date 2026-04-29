import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/downloaded_song.dart';
import '../models/song.dart';
import '../providers/music_provider.dart';
import '../providers/theme_provider.dart';
import '../services/download/download_service.dart';
import '../theme/app_styles.dart';
import '../utils/format_utils.dart';
import '../utils/logger.dart';
import '../utils/platform_utils.dart';
import '../utils/snackbar_util.dart';
import '../widgets/confirm_delete_dialog.dart';
import '../widgets/mini_player.dart';
import 'downloaded/downloaded_header.dart';
import 'downloaded/downloaded_songs_list.dart';

/// 下载的歌曲列表页面
class DownloadedSongsScreen extends StatefulWidget {
  const DownloadedSongsScreen({super.key});

  @override
  State<DownloadedSongsScreen> createState() => _DownloadedSongsScreenState();
}

class _DownloadedSongsScreenState extends State<DownloadedSongsScreen> with SingleTickerProviderStateMixin {
  final _downloadService = DownloadService();
  List<DownloadedSong> _downloadedSongs = [];
  List<DownloadedSong> _localSongs = [];
  bool _isLoading = true;
  bool _isSearching = false;
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};
  final TextEditingController _searchController = TextEditingController();
  String _totalSize = '0 MB';
  
  // 标签页控制
  late TabController _tabController;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _currentTabIndex = _tabController.index;
          _isSelectionMode = false;
          _selectedIds.clear();
          _isSearching = false;
          _searchController.clear();
        });
      }
    });
    unawaited(_loadDownloadedSongs().catchError((Object e) {
      Logger.error('加载下载列表失败', e, null, 'DownloadedScreen');
    }));
    unawaited(_loadLocalSongs().catchError((Object e) {
      Logger.error('加载本地歌曲失败', e, null, 'DownloadedScreen');
    }));
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // 获取当前标签页的歌曲列表
  List<DownloadedSong> get _currentSongs {
    return _currentTabIndex == 0 ? _downloadedSongs : _localSongs;
  }

  // 获取过滤后的歌曲列表
  List<DownloadedSong> get _filteredSongs {
    final songs = _currentSongs;
    final query = _searchController.text.toLowerCase();
    
    if (query.isEmpty) {
      return songs;
    }
    
    return songs.where((song) {
      return song.title.toLowerCase().contains(query) ||
             song.artist.toLowerCase().contains(query) ||
             song.album.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _loadDownloadedSongs() async {
    setState(() => _isLoading = true);
    
    await _downloadService.init();
    final songs = await _downloadService.getDownloadedSongs();
    final size = await _downloadService.getDownloadedSize();
    
    if (mounted) {
      setState(() {
        _downloadedSongs = songs;
        _totalSize = FormatUtils.formatSize(size);
        _isLoading = false;
      });
    }
  }
  
  /// 从 SQLite 加载本地歌曲（source='local'）
  Future<void> _loadLocalSongs() async {
    try {
      final songs = await _downloadService.getLocalSongs();
      
      if (mounted) {
        setState(() {
          _localSongs = songs;
        });
      }
      Logger.success('加载到 ${songs.length} 首本地歌曲', 'DownloadedScreen');
    } catch (e) {
      Logger.error('加载本地歌曲失败', e, null, 'DownloadedScreen');
    }
  }
  
  /// 保存本地歌曲到 SQLite
  Future<void> _saveLocalSongsToDb(List<DownloadedSong> songs) async {
    try {
      await _downloadService.saveLocalSongs(songs);
      Logger.success('已保存 ${songs.length} 首本地歌曲到数据库', 'DownloadedScreen');
    } catch (e) {
      Logger.error('保存本地歌曲失败', e, null, 'DownloadedScreen');
    }
  }
  
  /// 扫描本地音频文件（使用 MediaStore）
  Future<void> _scanLocalAudio() async {
    final colors = Provider.of<ThemeProvider>(context, listen: false).colors;
    
    // 显示加载对话框
    if (mounted) {
      unawaited(showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 48),
            padding: const EdgeInsets.all(AppStyles.spacingXXL),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: AppStyles.borderRadiusLarge,
              boxShadow: AppStyles.getShadows(colors.isLight),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: colors.accent,
                  strokeWidth: 3,
                ),
                const SizedBox(height: AppStyles.spacingXXL),
                Text(
                  '正在扫描设备音频...',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '请稍候',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ));
    }
    
    try {
      // 使用 MediaStore 扫描所有音频
      final scannedSongs = await _downloadService.scanLocalAudio();
      
      // 保存到 SQLite
      await _saveLocalSongsToDb(scannedSongs);
      
      if (mounted) {
        Navigator.pop(context); // 关闭加载对话框
        
        setState(() {
          _localSongs = scannedSongs;
        });
        
        AppSnackBar.showWithContext(
          context,
          '扫描完成，找到 ${scannedSongs.length} 首本地音乐',
          type: SnackBarType.success,
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        
        AppSnackBar.showWithContext(
          context,
          '扫描失败，请确保已授予存储权限',
          type: SnackBarType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;
    final musicProvider = Provider.of<MusicProvider>(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              DownloadedHeader(
                tabController: _tabController,
                downloadedCount: _downloadedSongs.length,
                localCount: _localSongs.length,
                isSearching: _isSearching,
                isSelectionMode: _isSelectionMode,
                selectedCount: _selectedIds.length,
                currentTabIndex: _currentTabIndex,
                totalSizeLabel: _totalSize,
                hasSongsInCurrentTab: _currentSongs.isNotEmpty,
                searchController: _searchController,
                onBack: () => Navigator.pop(context),
                onToggleSearch: () {
                  setState(() {
                    _isSearching = !_isSearching;
                    if (!_isSearching) {
                      _searchController.clear();
                    }
                  });
                },
                onEnterSelectionMode: () {
                  setState(() {
                    _isSelectionMode = true;
                  });
                },
                onCancelSelection: () {
                  setState(() {
                    _isSelectionMode = false;
                    _selectedIds.clear();
                  });
                },
                onToggleSelectAll: () {
                  setState(() {
                    if (_selectedIds.length == _filteredSongs.length) {
                      _selectedIds.clear();
                    } else {
                      _selectedIds.addAll(_filteredSongs.map((s) => s.id));
                    }
                  });
                },
                onBatchDelete: _batchDelete,
                onScanLocalAudio: _scanLocalAudio,
                onRefreshDownloaded: _loadDownloadedSongs,
                onSearchChanged: (value) => setState(() {}),
              ),
              // 内容区域
              if (_isLoading)
                SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: colors.accent),
                  ),
                )
              else if (_filteredSongs.isEmpty)
                SliverFillRemaining(
                  child: _buildEmptyState(colors),
                )
              else
                DownloadedSongsListSection(
                  songs: _filteredSongs,
                  isSelectionMode: _isSelectionMode,
                  selectedIds: _selectedIds,
                  currentPlayingId: musicProvider.currentSong?.id,
                  isPlayingNow: musicProvider.isPlaying,
                  bottomPadding: musicProvider.currentSong != null ? 96.0 : 16.0,
                  onSelectionChanged: (song, selected) {
                    setState(() {
                      if (selected) {
                        _selectedIds.add(song.id);
                      } else {
                        _selectedIds.remove(song.id);
                      }
                    });
                  },
                  onPlay: (downloadedSong) {
                    final song = _downloadedSongToSong(downloadedSong);

                    final allSongs = _filteredSongs.map(_downloadedSongToSong).toList();

                    unawaited(musicProvider.playSong(song, playlist: allSongs));
                  },
                  onDelete: _showDeleteDialog,
                ),
            ],
          ),
          // Mini 播放器
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

  Widget _buildEmptyState(ThemeColors colors) {
    final isSearchEmpty = _isSearching && _searchController.text.isNotEmpty;

    // 本地音乐标签页的空状态
    if (_currentTabIndex == 1 && !isSearchEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(AppStyles.spacingXXL),
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: colors.accent.withValues(alpha: 0.06),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.folder_open_rounded,
                  size: 56,
                  color: colors.accent.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: AppStyles.spacingXXL),
              Text(
                '还没有扫描本地音乐',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppStyles.spacingS),
              Text(
                '扫描设备中的音频文件\n即可在这里管理和播放',
                style: TextStyle(
                  fontSize: 14,
                  color: colors.textSecondary,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppStyles.spacingXXXL),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _scanLocalAudio,
                  borderRadius: AppStyles.borderRadiusLarge,
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colors.accent,
                          colors.accent.withValues(alpha: 0.8),
                        ],
                      ),
                      borderRadius: AppStyles.borderRadiusLarge,
                      boxShadow: [
                        BoxShadow(
                          color: colors.accent.withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            '开始扫描',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 应用下载标签页或搜索结果为空的状态
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colors.card.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isSearchEmpty ? Icons.search_off_rounded : Icons.download_outlined,
              size: 56,
              color: colors.textSecondary.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isSearchEmpty ? '未找到相关歌曲' : '还没有下载的歌曲',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            isSearchEmpty
                ? '试试其他关键词吧'
                : '在播放器中点击下载按钮\n保存歌曲到本地',
            style: TextStyle(
              fontSize: 14,
              color: colors.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(DownloadedSong song) {
    final isLocalTab = song.source.isLocal;

    ConfirmDeleteDialog.show(
      context,
      type: ConfirmDeleteType.single,
      title: '删除${isLocalTab ? "本地" : "下载"}歌曲',
      message: isLocalTab
          ? '确定要删除本地歌曲《${song.title}》吗？\n将从列表中移除，同时尝试删除文件。'
          : '确定要删除下载的《${song.title}》吗？',
      itemName: song.title,
    ).then((confirmed) async {
      if (confirmed != true) return;

      final result = await _downloadService.deleteSongs([song]);

      if (!mounted) return;

      if (result.allSuccess) {
        // 从 UI 列表中移除
        _downloadedSongs.removeWhere((s) => s.id == song.id);
        _localSongs.removeWhere((s) => s.id == song.id);
        AppSnackBar.show(
          '已删除：${song.title}',
          type: SnackBarType.info,
        );
        setState(() {});
      } else {
        AppSnackBar.show(
          '删除失败，请重试',
          type: SnackBarType.error,
        );
      }
    });
  }
  String _convertToFileUri(String filePath) {
    final uri = Uri.file(filePath, windows: PlatformUtils.isWindows);
    final uriString = uri.toString();
    Logger.info('原始路径: $filePath', 'FileUri');
    Logger.info('转换后URI: $uriString', 'FileUri');
    return uriString;
  }

  String _getAudioUrl(DownloadedSong d) {
    final contentUri = d.contentUri;
    if (contentUri != null && contentUri.isNotEmpty) {
      Logger.info('使用 contentUri: $contentUri', 'FileUri');
      return contentUri;
    }
    if (d.localAudioPath.isNotEmpty) {
      return _convertToFileUri(d.localAudioPath);
    }
    Logger.warning('音频路径为空: ${d.title}', 'FileUri');
    return '';
  }

  Song _downloadedSongToSong(DownloadedSong d) {
    String coverUrl = d.coverUrl;
    if (d.localCoverPath != null && d.localCoverPath!.isNotEmpty) {
      // 使用缓存的 file:// URI，避免列表构建时 existsSync() IO
      coverUrl = _convertToFileUri(d.localCoverPath!);
    }

    // 歌词内容不在此处同步读取文件，播放时由 LyricsLoadingService 按需异步加载
    // 通过 localLyricsPath / localTransPath 提供文件路径即可

    return Song(
      id: d.id,
      title: d.title,
      artist: d.artist,
      album: d.album,
      coverUrl: coverUrl,
      audioUrl: _getAudioUrl(d),
      duration: d.duration,
      platform: d.platform,
      localCoverPath: d.localCoverPath,
      localLyricsPath: d.localLyricsPath,
      localTransPath: d.localTransPath,
    );
  }

  /// 批量删除
  Future<void> _batchDelete() async {
    final selectedSongs = _filteredSongs
        .where((s) => _selectedIds.contains(s.id))
        .toList();

    if (selectedSongs.isEmpty) return;

    final confirmed = await ConfirmDeleteDialog.show(
      context,
      type: ConfirmDeleteType.batch,
      title: '批量删除',
      message: '确定要删除选中的歌曲吗？\n删除后将无法恢复。',
      itemCount: _selectedIds.length,
    );

    if (confirmed != true) return;

    if (!mounted) return;
    final colors = Provider.of<ThemeProvider>(context, listen: false).colors;
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(color: colors.accent),
      ),
    ));

    final result = await _downloadService.deleteSongs(selectedSongs);

    if (!mounted) return;
    Navigator.pop(context);

    // 从 UI 列表中移除已删除的歌曲
    final deletedIdSet = result.deletedIds.toSet();
    _downloadedSongs.removeWhere((s) => deletedIdSet.contains(s.id));
    _localSongs.removeWhere((s) => deletedIdSet.contains(s.id));

    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });

    if (!mounted) return;

    if (result.allSuccess) {
      AppSnackBar.showWithContext(
        context,
        '已删除 ${result.totalSongs} 首歌曲',
        type: SnackBarType.info,
      );
    } else {
      AppSnackBar.showWithContext(
        context,
        '已删除 ${result.deletedIds.length}/${result.totalSongs} 首歌曲，${result.failedIds.length} 首失败',
        type: SnackBarType.error,
      );
    }
  }
}
