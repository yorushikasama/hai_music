import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/playlist.dart';
import '../models/song.dart';
import '../providers/theme_provider.dart';
import '../services/cache_manager_service.dart';
import '../services/data_cache_service.dart';
import '../services/music_api_service.dart';
import '../services/preferences_service.dart';
import '../theme/app_styles.dart';
import '../utils/format_utils.dart';
import '../utils/logger.dart';
import '../utils/responsive.dart';
import 'download_progress_screen.dart';
import 'downloaded_songs_screen.dart';
import 'favorites_screen.dart';
import 'library/library_header.dart';
import 'playlist_detail_screen.dart';
import 'recent_play_screen.dart';
import 'storage_config_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _apiService = MusicApiService();
  final _cacheService = DataCacheService();
  List<Map<String, dynamic>> _userPlaylists = [];
  bool _isLoading = true;
  String _qqNumber = ''; // 不再硬编码，从本地存储读取

  static const String _qqNumberKey = 'qq_number';

  @override
  void initState() {
    super.initState();
    _initCache();
  }

  Future<void> _initCache() async {
    await _cacheService.init();
    unawaited(_loadQQNumber());
  }

  Future<void> _loadQQNumber() async {
    final prefs = PreferencesService();
    final savedQQ = await prefs.getString(_qqNumberKey);
    if (savedQQ != null && savedQQ.isNotEmpty) {
      setState(() {
        _qqNumber = savedQQ;
      });
      unawaited(_loadUserPlaylists());
    } else {
      // 首次使用，提示用户输入 QQ 号
      setState(() => _isLoading = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showEditQQDialog();
      });
    }
  }

  Future<void> _saveQQNumber(String qqNumber) async {
    final prefs = PreferencesService();
    await prefs.setString(_qqNumberKey, qqNumber);
  }

  Future<void> _loadUserPlaylists({bool forceRefresh = false}) async {
    if (_qqNumber.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      // 如果不是强制刷新，先尝试从缓存加载
      if (!forceRefresh) {
        final cachedPlaylists = await _cacheService.getUserPlaylists(_qqNumber);
        if (cachedPlaylists != null) {
          if (mounted) {
            setState(() {
              _userPlaylists = cachedPlaylists;
              _isLoading = false;
            });
          }
          Logger.debug('✅ [Library] 从缓存加载 ${cachedPlaylists.length} 个歌单');
          return;
        }
      }

      // 缓存不存在或已过期，从 API 获取
      Logger.debug('🌐 [Library] 从 API 获取歌单列表...');
      final playlists = await _apiService.getUserPlaylists(
        qqNumber: _qqNumber,
      );

      if (mounted) {
        setState(() {
          _userPlaylists = playlists;
          _isLoading = false;
        });
      }

      // 保存到缓存
      await _cacheService.saveUserPlaylists(_qqNumber, playlists);
      Logger.debug('✅ [Library] 从 API 加载 ${playlists.length} 个歌单并已缓存');
    } catch (e) {
      Logger.debug('❌ [Library] 加载歌单失败: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            LibraryHeader(
              onOpenDownloadProgress: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (context) => const DownloadProgressScreen(),
                  ),
                );
              },
              onOpenStorageConfig: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (context) => const StorageConfigScreen(),
                  ),
                );
              },
              onClearCache: _showClearCacheDialog,
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildQuickActions(context, colors),
                    const SizedBox(height: 32),
Row(
                      children: [
                        Text(
                          '我的歌单',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: _showEditQQDialog,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: colors.card,
                              borderRadius: BorderRadius.circular(AppStyles.radiusSmall),
                              border: Border.all(color: colors.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'QQ: $_qqNumber',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: colors.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.edit,
                                  size: 16,
                                  color: colors.textSecondary,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (!_isLoading)
                          IconButton(
                            icon: Icon(Icons.refresh, color: colors.accent),
                            onPressed: () => _loadUserPlaylists(forceRefresh: true),
                            tooltip: '刷新歌单',
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
if (_isLoading)
              SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: CircularProgressIndicator(color: colors.accent),
                  ),
                ),
              )
            else if (_userPlaylists.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: Responsive.getHorizontalPadding(context),
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
                            _qqNumber.isEmpty 
                                ? Icons.person_outline 
                                : Icons.library_music_outlined,
                            size: 64,
                            color: colors.textSecondary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _qqNumber.isEmpty ? '未设置 QQ 号' : '暂无歌单',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _qqNumber.isEmpty 
                                ? '点击右上角设置按钮输入 QQ 号' 
                                : '该 QQ 账号没有公开歌单',
                            style: TextStyle(
                              fontSize: 14,
                              color: colors.textSecondary,
                            ),
                          ),
                          if (_qqNumber.isEmpty) ...[
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: _showEditQQDialog,
                              icon: const Icon(Icons.edit),
                              label: const Text('设置 QQ 号'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colors.accent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: Responsive.getHorizontalPadding(context),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: Responsive.getCrossAxisCount(context),
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final playlistData = _userPlaylists[index];
                      return _buildUserPlaylistCard(
                        context,
                        playlistData,
                      );
                    },
                    childCount: _userPlaylists.length,
                  ),
                ),
              ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, ThemeColors colors) {
    return Row(
      children: [
        Expanded(
          child: _buildActionCard(
            context,
            icon: Icons.favorite,
            title: '我喜欢',
            color: Colors.red,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (context) => const FavoritesScreen(),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildActionCard(
            context,
            icon: Icons.history,
            title: '最近播放',
            color: colors.accent,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (context) => const RecentPlayScreen(),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildActionCard(
            context,
            icon: Icons.download,
            title: '本地下载',
            color: Colors.green,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (context) => const DownloadedSongsScreen(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    final colors = Provider.of<ThemeProvider>(context).colors;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppStyles.radiusMedium),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(AppStyles.radiusMedium),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: colors.isLight ? 0.08 : 0.3),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: colors.isLight ? 0.04 : 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserPlaylistCard(
    BuildContext context,
    Map<String, dynamic> playlistData,
  ) {
    final colors = Provider.of<ThemeProvider>(context).colors;
    
    return GestureDetector(
      onTap: () async {
        // 显示加载对话框
        unawaited(showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) => Center(
            child: CircularProgressIndicator(color: colors.accent),
          ),
        ));

        // 在异步操作前提取 context 相关对象
        final navigator = Navigator.of(context);
        final messenger = ScaffoldMessenger.of(context);
        
        try {
          Logger.info('🎵 开始加载我的歌单: ${playlistData['name']} (ID: ${playlistData['id']})', 'LibraryScreen');
          Logger.debug('📋 QQ号: $_qqNumber', 'LibraryScreen');
          Logger.debug('📋 歌单数据结构: ${playlistData.keys.toList()}', 'LibraryScreen');
          
          // 直接获取歌单歌曲（第一页）
          final result = await _apiService.getPlaylistSongs(
            playlistId: playlistData['id'] as String,
            uin: _qqNumber,
          );
          
          Logger.debug('📊 我的歌单API返回结果: ${result.keys.toList()}', 'LibraryScreen');
          
          final List<Song> songs = result['songs'] as List<Song>;
          final int totalCount = result['totalCount'] as int;
          
          Logger.info('✅ 我的歌单加载完成: ${songs.length} 首歌曲，总数: $totalCount', 'LibraryScreen');

          if (!mounted) return;

          navigator.pop(); // 关闭加载对话框

          if (!mounted) return;

          // 创建 Playlist 对象
          final playlist = Playlist(
            id: playlistData['id'] as String,
            name: playlistData['name'] as String,
            coverUrl: playlistData['coverUrl'] as String,
            songs: songs,
          );

          // 跳转到歌单详情页
          unawaited(navigator.push(
            MaterialPageRoute<void>(
              builder: (context) => PlaylistDetailScreen(
                playlist: playlist,
                totalCount: totalCount,
                qqNumber: _qqNumber,
              ),
            ),
          ));
        } catch (e) {
          Logger.error('❌ 我的歌单加载失败: ${playlistData['name']} (ID: ${playlistData['id']})', e, null, 'LibraryScreen');
          
          if (!mounted) return;

          navigator.pop(); // 关闭加载对话框

          if (!mounted) return;
          messenger.showSnackBar(
            SnackBar(
              content: Text('加载歌单失败: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: SizedBox(
        width: 180,
        child: Container(
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(AppStyles.radiusLarge),
            border: Border.all(
              color: colors.border.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: colors.isLight ? 0.08 : 0.3),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: colors.isLight ? 0.04 : 0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                flex: 3,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      (playlistData['coverUrl'] as String).isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: playlistData['coverUrl'] as String,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: colors.card.withValues(alpha: 0.5),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: colors.card,
                                child: Icon(
                                  Icons.library_music,
                                  size: 48,
                                  color: colors.textSecondary,
                                ),
                              ),
                            )
                          : Container(
                              color: colors.card,
                              child: Icon(
                                Icons.library_music,
                                size: 48,
                                color: colors.textSecondary,
                              ),
                            ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.5),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${playlistData['songCount']} 首',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      playlistData['name'] as String,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if ((playlistData['description'] as String?) != null && (playlistData['description'] as String).isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        playlistData['description'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textSecondary,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditQQDialog() {
    final colors = Provider.of<ThemeProvider>(context, listen: false).colors;
    final controller = TextEditingController(text: _qqNumber);
    
    if (!mounted) return;
    unawaited(showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.card,
        title: Text(
          '修改 QQ 号',
          style: TextStyle(color: colors.textPrimary),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'QQ 号',
            labelStyle: TextStyle(color: colors.textSecondary),
            hintText: '请输入 QQ 号',
            hintStyle: TextStyle(color: colors.textSecondary.withValues(alpha: 0.5)),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: colors.border),
              borderRadius: BorderRadius.circular(AppStyles.radiusSmall),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: colors.accent, width: 2),
              borderRadius: BorderRadius.circular(AppStyles.radiusSmall),
            ),
          ),
          style: TextStyle(color: colors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              '取消',
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              
              final newQQ = controller.text.trim();
              if (newQQ.isEmpty) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('QQ 号不能为空')),
                );
                return;
              }
              
              if (!RegExp(r'^\d+$').hasMatch(newQQ)) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('请输入有效的 QQ 号')),
                );
                return;
              }
              
              navigator.pop();
              
              setState(() {
                _qqNumber = newQQ;
              });

              await _saveQQNumber(newQQ);
              // 切换 QQ 号后强制刷新
              unawaited(_loadUserPlaylists(forceRefresh: true));

              if (!mounted) return;
              messenger.showSnackBar(
                SnackBar(content: Text('已切换到 QQ: $newQQ')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.accent,
              foregroundColor: Colors.white,
            ),
            child: const Text('确定'),
          ),
        ],
      ),
    ));
  }

  Future<void> _showClearCacheDialog() async {
    final colors = Provider.of<ThemeProvider>(context, listen: false).colors;
    final cacheManager = CacheManagerService(); // 使用单例
    final navigator = Navigator.of(context);

    // 显示加载对话框
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(color: colors.accent),
      ),
    ));

    // 获取缓存信息
    final cacheInfo = await cacheManager.getCacheInfo();

    if (!mounted) return;

    // 关闭加载对话框
    navigator.pop();

    // 格式化大小
    final totalSizeStr = FormatUtils.formatSize(cacheInfo.totalSize);
    final audioSizeStr = FormatUtils.formatSize(cacheInfo.audioSize);
    final coverSizeStr = FormatUtils.formatSize(cacheInfo.coverSize);

    unawaited(showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.cleaning_services, color: colors.accent),
            const SizedBox(width: 12),
            const Text('清理缓存'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '当前缓存大小：$totalSizeStr',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            _buildCacheItem(
              icon: Icons.music_note,
              label: '音频缓存',
              size: audioSizeStr,
              colors: colors,
            ),
            const SizedBox(height: 8),
            _buildCacheItem(
              icon: Icons.image,
              label: '封面缓存',
              size: coverSizeStr,
              colors: colors,
            ),
            const SizedBox(height: 8),
            _buildCacheItem(
              icon: Icons.photo_library,
              label: '图片缓存',
              size: FormatUtils.formatSize(cacheInfo.imageSize),
              colors: colors,
            ),
            if (cacheInfo.downloadSize > 0) ...[
              const SizedBox(height: 8),
              _buildCacheItem(
                icon: Icons.download,
                label: '下载文件',
                size: FormatUtils.formatSize(cacheInfo.downloadSize),
                colors: colors,
              ),
            ],
            const SizedBox(height: 16),
            Text(
              '清理缓存将删除音频、封面和图片缓存\n（不包括下载的歌曲）',
              style: TextStyle(
                fontSize: 13,
                color: colors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              
              navigator.pop();

              // 显示加载对话框
              unawaited(showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (context) => Center(
                  child: CircularProgressIndicator(color: colors.accent),
                ),
              ));

              // 清理缓存
              final success = await cacheManager.clearAllCache();

              if (!mounted) return;

              navigator.pop(); // 关闭加载对话框

              if (!mounted) return;
              messenger.showSnackBar(
                SnackBar(
                  content: Text(success ? '✅ 缓存清理完成' : '❌ 清理失败'),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('清理'),
          ),
        ],
      ),
    ));
  }

  Widget _buildCacheItem({
    required IconData icon,
    required String label,
    required String size,
    required ThemeColors colors,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: colors.textSecondary),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: colors.textSecondary,
          ),
        ),
        const Spacer(),
        Text(
          size,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: colors.textPrimary,
          ),
        ),
      ],
    );
  }
}
