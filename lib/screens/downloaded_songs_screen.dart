import 'dart:io' as io;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/downloaded_song.dart';
import '../models/song.dart';
import '../providers/music_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_styles.dart';
import '../services/download_service.dart';
import '../services/download_manager.dart';
import '../services/local_audio_scanner.dart';
import '../widgets/mini_player.dart';
import '../utils/logger.dart';

/// 下载的歌曲列表页面
class DownloadedSongsScreen extends StatefulWidget {
  const DownloadedSongsScreen({super.key});

  @override
  State<DownloadedSongsScreen> createState() => _DownloadedSongsScreenState();
}

class _DownloadedSongsScreenState extends State<DownloadedSongsScreen> with SingleTickerProviderStateMixin {
  final _downloadService = DownloadService();
  final _localScanner = LocalAudioScanner();
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
    _loadDownloadedSongs();
    _loadLocalSongs(); // 从缓存加载本地歌曲
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
        _totalSize = _downloadService.formatSize(size);
        _isLoading = false;
      });
    }
  }
  
  /// 从缓存加载本地歌曲
  Future<void> _loadLocalSongs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('local_scanned_songs');
      
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final List<dynamic> jsonList = jsonDecode(cachedJson);
        final songs = jsonList.map((json) => DownloadedSong.fromJson(json)).toList();
        
        if (mounted) {
          setState(() {
            _localSongs = songs;
          });
        }
        Logger.success('加载到 ${songs.length} 首下载歌曲', 'DownloadedScreen');
      }
    } catch (e) {
      Logger.error('加载下载列表失败', e, null, 'DownloadedScreen');
    }
  }
  
  /// 保存本地歌曲到缓存
  Future<void> _saveLocalSongsCache(List<DownloadedSong> songs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = songs.map((s) => s.toJson()).toList();
      await prefs.setString('local_scanned_songs', jsonEncode(jsonList));
      Logger.success('已缓存 ${songs.length} 首本地歌曲', 'DownloadedScreen');
    } catch (e) {
      Logger.error('保存缓存失败', e, null, 'DownloadedScreen');
    }
  }
  
  /// 扫描本地音频文件（使用 MediaStore）
  Future<void> _scanLocalAudio() async {
    final colors = Provider.of<ThemeProvider>(context, listen: false).colors;
    
    // 显示加载对话框
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 48),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: colors.accent,
                  strokeWidth: 3,
                ),
                const SizedBox(height: 20),
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
      );
    }
    
    try {
      // 使用 MediaStore 扫描所有音频
      final scannedSongs = await _localScanner.scanAllAudio();
      
      // 保存到缓存
      await _saveLocalSongsCache(scannedSongs);
      
      if (mounted) {
        Navigator.pop(context); // 关闭加载对话框
        
        setState(() {
          _localSongs = scannedSongs;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '扫描完成，找到 ${scannedSongs.length} 首本地音乐',
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green.shade700,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // 关闭加载对话框
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '扫描失败\n请确保已授予存储权限',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red.shade700,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
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
              // 顶部导航栏
              SliverAppBar(
                pinned: true,
                backgroundColor: colors.surface.withValues(alpha: 0.95),
                elevation: 0,
                expandedHeight: 120,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back_ios_new, color: colors.textPrimary, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(48),
                  child: Container(
                    color: colors.surface.withValues(alpha: 0.95),
                    child: TabBar(
                      controller: _tabController,
                      indicatorColor: colors.accent,
                      indicatorWeight: 3,
                      labelColor: colors.accent,
                      unselectedLabelColor: colors.textSecondary,
                      labelStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      tabs: [
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.download, size: 20),
                              const SizedBox(width: 8),
                              Text('应用下载 (${_downloadedSongs.length})'),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.folder_open, size: 20),
                              const SizedBox(width: 8),
                              Text('本地音乐 (${_localSongs.length})'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                title: _isSearching
                    ? TextField(
                        controller: _searchController,
                        autofocus: true,
                        style: TextStyle(color: colors.textPrimary),
                        decoration: InputDecoration(
                          hintText: '搜索下载的歌曲...',
                          hintStyle: TextStyle(color: colors.textSecondary),
                          border: InputBorder.none,
                        ),
                        onChanged: (value) => setState(() {}),
                      )
                    : Row(
                        children: [
                          Icon(
                            _isSelectionMode ? Icons.checklist_rounded : Icons.download,
                            color: _isSelectionMode ? colors.accent : Colors.green,
                            size: 26,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _isSelectionMode 
                                    ? '选择歌曲' 
                                    : '本地下载',
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              if (_isSelectionMode && _selectedIds.isNotEmpty)
                                Text(
                                  '已选择 ${_selectedIds.length} 首',
                                  style: TextStyle(
                                    color: colors.accent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                )
                              else if (!_isSelectionMode)
                                Text(
                                  _currentTabIndex == 0
                                      ? '${_downloadedSongs.length} 首 · $_totalSize'
                                      : '${_localSongs.length} 首本地音乐',
                                  style: TextStyle(
                                    color: colors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                actions: [
                  if (_isSelectionMode) ...[
                    // 批量删除按钮（放在菜单中）
                    if (_selectedIds.isNotEmpty)
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: Colors.red, size: 22),
                        onPressed: _batchDelete,
                        tooltip: '批量删除',
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                      ),
                    // 全选/取消全选
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
                    // 取消选择模式
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
                  ] else ...[
                    IconButton(
                      icon: Icon(
                        _isSearching ? Icons.close : Icons.search,
                        color: colors.textSecondary,
                        size: 22,
                      ),
                      onPressed: () {
                        setState(() {
                          _isSearching = !_isSearching;
                          if (!_isSearching) {
                            _searchController.clear();
                          }
                        });
                      },
                      tooltip: _isSearching ? '关闭搜索' : '搜索',
                    ),
                    if (!_isSearching && _currentSongs.isNotEmpty)
                      IconButton(
                        icon: Icon(Icons.checklist_rounded, color: colors.textSecondary, size: 22),
                        onPressed: () {
                          setState(() {
                            _isSelectionMode = true;
                          });
                        },
                        tooltip: '多选',
                      ),
                    if (!_isSearching && _currentTabIndex == 1)
                      Container(
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          color: colors.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: IconButton(
                          icon: Icon(Icons.refresh_rounded, color: colors.accent, size: 22),
                          onPressed: _scanLocalAudio,
                          tooltip: '扫描本地音乐',
                        ),
                      ),
                    if (!_isSearching && _currentTabIndex == 0)
                      IconButton(
                        icon: Icon(Icons.refresh_rounded, color: colors.textSecondary, size: 22),
                        onPressed: _loadDownloadedSongs,
                        tooltip: '刷新',
                      ),
                  ],
                ],
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
                _buildSongsList(colors, musicProvider, _filteredSongs),
            ],
          ),
          // Mini 播放器
          if (musicProvider.currentSong != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: const MiniPlayer(),
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
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.folder_open_rounded,
                  size: 64,
                  color: colors.accent,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '还没有扫描本地音乐',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '点击右上角的刷新按钮\n扫描设备中的音频文件',
                style: TextStyle(
                  fontSize: 15,
                  color: colors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // 扫描按钮
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _scanLocalAudio,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.accent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh_rounded, color: colors.accent, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '点击此图标开始扫描',
                          style: TextStyle(
                            color: colors.accent,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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
          Icon(
            isSearchEmpty ? Icons.search_off : Icons.download_outlined,
            size: 80,
            color: colors.textSecondary.withValues(alpha: 0.5),
          ),
          SizedBox(height: AppStyles.spacingL),
          Text(
            isSearchEmpty ? '未找到相关歌曲' : '还没有下载的歌曲',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          SizedBox(height: AppStyles.spacingS),
          Text(
            isSearchEmpty 
                ? '试试其他关键词吧' 
                : '在播放器中点击下载按钮保存歌曲到本地',
            style: TextStyle(
              fontSize: 14,
              color: colors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// 构建歌曲列表
  Widget _buildSongsList(ThemeColors colors, MusicProvider musicProvider, List<DownloadedSong> songs) {
    // 计算底部padding：mini播放器(80) + 额外间距(16)
    final bottomPadding = musicProvider.currentSong != null ? 96.0 : 16.0;

    return SliverPadding(
      padding: EdgeInsets.only(left: 20, right: 20, bottom: bottomPadding),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final downloadedSong = songs[index];
            final isPlaying = musicProvider.currentSong?.id == downloadedSong.id;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildSongItem(downloadedSong, isPlaying, colors, musicProvider, _isSelectionMode),
            );
          },
          childCount: songs.length,
        ),
      ),
    );
  }

  Widget _buildSongItem(
    DownloadedSong downloadedSong,
    bool isPlaying,
    ThemeColors colors,
    MusicProvider musicProvider,
    bool isSelectionMode,
  ) {
    final isSelected = _selectedIds.contains(downloadedSong.id);
    return Container(
      decoration: BoxDecoration(
        color: isPlaying
            ? colors.accent.withValues(alpha: 0.08)
            : colors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPlaying
              ? colors.accent.withValues(alpha: 0.3)
              : colors.border.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (isSelectionMode) {
              setState(() {
                if (isSelected) {
                  _selectedIds.remove(downloadedSong.id);
                } else {
                  _selectedIds.add(downloadedSong.id);
                }
              });
            } else {
              // 转换为 Song 对象并播放
              final song = Song(
              id: downloadedSong.id,
              title: downloadedSong.title,
              artist: downloadedSong.artist,
              album: downloadedSong.album,
              coverUrl: downloadedSong.coverUrl,
              audioUrl: _convertToFileUri(downloadedSong.localAudioPath), // 使用本地文件
              duration: downloadedSong.duration,
              platform: downloadedSong.platform,
            );
            
            // 将所有下载的歌曲转换为播放列表
            final allSongs = _filteredSongs.map((d) => Song(
              id: d.id,
              title: d.title,
              artist: d.artist,
              album: d.album,
              coverUrl: d.coverUrl,
              audioUrl: _convertToFileUri(d.localAudioPath),
              duration: d.duration,
              platform: d.platform,
            )).toList();
            
              musicProvider.playSong(song, playlist: allSongs);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // 选择框或封面图
                if (isSelectionMode)
                  Checkbox(
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedIds.add(downloadedSong.id);
                        } else {
                          _selectedIds.remove(downloadedSong.id);
                        }
                      });
                    },
                    activeColor: colors.accent,
                  )
                else
                  const SizedBox(width: 0),
                // 封面图
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: downloadedSong.localCoverPath != null
                          ? Image.file(
                              io.File(downloadedSong.localCoverPath!),
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildCoverPlaceholder(colors, downloadedSong.coverUrl);
                              },
                            )
                          : _buildCoverPlaceholder(colors, downloadedSong.coverUrl),
                    ),
                    if (isPlaying)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            musicProvider.isPlaying ? Icons.equalizer_rounded : Icons.pause_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    // 下载标识
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.download_done,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                // 歌曲信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        downloadedSong.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isPlaying ? colors.accent : colors.textPrimary,
                          height: 1.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        downloadedSong.artist,
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.textSecondary.withValues(alpha: 0.8),
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // 时长
                if (downloadedSong.duration != null)
                  Text(
                    _formatDuration(downloadedSong.duration!),
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.textSecondary.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                if (!isSelectionMode) ...[
                  const SizedBox(width: 8),
                  // 删除按钮
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red.withValues(alpha: 0.1),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      onPressed: () => _showDeleteDialog(downloadedSong),
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoverPlaceholder(ThemeColors colors, String? networkUrl) {
    if (networkUrl != null && networkUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: networkUrl,
        width: 60,
        height: 60,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          width: 60,
          height: 60,
          color: colors.card.withValues(alpha: 0.3),
          child: Icon(Icons.music_note, color: colors.textSecondary.withValues(alpha: 0.3)),
        ),
        errorWidget: (context, url, error) => Container(
          width: 60,
          height: 60,
          color: colors.card.withValues(alpha: 0.3),
          child: Icon(Icons.music_note, color: colors.textSecondary),
        ),
      );
    }
    
    return Container(
      width: 60,
      height: 60,
      color: colors.card.withValues(alpha: 0.3),
      child: Icon(Icons.music_note, color: colors.textSecondary),
    );
  }

  void _showDeleteDialog(DownloadedSong song) {
    final colors = Provider.of<ThemeProvider>(context, listen: false).colors;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.card,
        title: Text('删除下载', style: TextStyle(color: colors.textPrimary)),
        content: Text(
          '确定要删除《${song.title}》吗？',
          style: TextStyle(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消', style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              final success = await _downloadService.deleteDownloadedSong(song.id);
              
              if (mounted) {
                if (success) {
                  // 从下载管理器中移除任务记录
                  DownloadManager().removeTask(song.id);
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('已删除：${song.title}'),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: Colors.orange.shade700,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                  _loadDownloadedSongs();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('删除失败，请重试'),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: Colors.red.shade700,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int durationSeconds) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits((durationSeconds ~/ 60) % 60);
    final seconds = twoDigits(durationSeconds % 60);
    return '$minutes:$seconds';
  }

  /// 将文件路径转换为正确的 file:// URI
  String _convertToFileUri(String filePath) {
    // Windows: C:\Users\... → file:///C:/Users/...
    // Unix: /home/... → file:///home/...
    String uri;
    if (io.Platform.isWindows) {
      // Windows 路径转换：反斜杠改为正斜杠
      final normalizedPath = filePath.replaceAll('\\', '/');
      uri = 'file:///$normalizedPath';
    } else {
      // Unix 路径
      uri = 'file://$filePath';
    }
    Logger.info('原始路径: $filePath', 'FileUri');
    Logger.info('转换后URI: $uri', 'FileUri');
    return uri;
  }

  /// 批量删除
  Future<void> _batchDelete() async {
    final selectedSongs = _filteredSongs
        .where((s) => _selectedIds.contains(s.id))
        .toList();

    if (selectedSongs.isEmpty) return;

    // 确认对话框
    final colors = Provider.of<ThemeProvider>(context, listen: false).colors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colors.surface,
          title: Text(
            '批量删除',
            style: TextStyle(color: colors.textPrimary),
          ),
          content: Text(
            '确定要删除 ${_selectedIds.length} 首歌曲吗？\n删除后将无法恢复。',
            style: TextStyle(color: colors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('取消', style: TextStyle(color: colors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    // 显示加载对话框
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(color: colors.accent),
      ),
    );

    int successCount = 0;
    final downloadManager = DownloadManager();
    
    for (final song in selectedSongs) {
      final success = await _downloadService.deleteDownloadedSong(song.id);
      if (success) {
        successCount++;
        // 从下载管理器中移除任务记录
        downloadManager.removeTask(song.id);
      }
    }

    if (!mounted) return;
    Navigator.pop(context); // 关闭加载对话框

    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });

    // 刷新列表
    await _loadDownloadedSongs();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已删除 $successCount 首歌曲'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.orange.shade700,
      ),
    );
  }
}
