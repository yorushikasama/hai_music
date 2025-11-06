import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../theme/app_styles.dart';
import '../providers/theme_provider.dart';
import '../utils/responsive.dart';
import '../utils/platform_utils.dart';
import '../widgets/draggable_window_area.dart';
import '../services/music_api_service.dart';
import '../services/cache_manager_service.dart';
import '../services/preferences_cache_service.dart';
import '../services/data_cache_service.dart';
import 'playlist_detail_screen.dart';
import 'storage_config_screen.dart';
import 'favorites_screen.dart';
import 'recent_play_screen.dart';

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
    _loadQQNumber();
  }

  Future<void> _loadQQNumber() async {
    final prefsCache = PreferencesCacheService();
    await prefsCache.init();
    final savedQQ = await prefsCache.getString(_qqNumberKey);
    if (savedQQ != null && savedQQ.isNotEmpty) {
      setState(() {
        _qqNumber = savedQQ;
      });
      _loadUserPlaylists();
    } else {
      // 首次使用，提示用户输入 QQ 号
      setState(() => _isLoading = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showEditQQDialog();
      });
    }
  }

  Future<void> _saveQQNumber(String qqNumber) async {
    final prefsCache = PreferencesCacheService();
    await prefsCache.init();
    await prefsCache.setString(_qqNumberKey, qqNumber);
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
          print('✅ [Library] 从缓存加载 ${cachedPlaylists.length} 个歌单');
          return;
        }
      }

      // 缓存不存在或已过期，从 API 获取
      print('🌐 [Library] 从 API 获取歌单列表...');
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
      print('✅ [Library] 从 API 加载 ${playlists.length} 个歌单并已缓存');
    } catch (e) {
      print('❌ [Library] 加载歌单失败: $e');
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
            SliverAppBar(
              floating: true,
              pinned: true,
              expandedHeight: 100,
              backgroundColor: Colors.transparent,
              flexibleSpace: Stack(
                children: [
                  FlexibleSpaceBar(
                    title: Text(
                      '音乐库',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
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
              actions: [
                IconButton(
                  icon: Icon(Icons.cloud_outlined, color: colors.textPrimary),
                  tooltip: '云端同步设置',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const StorageConfigScreen(),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: Icon(Icons.cleaning_services_outlined, color: colors.textPrimary),
                  tooltip: '清理缓存',
                  onPressed: () => _showClearCacheDialog(context),
                ),
                const SizedBox(width: 8),
              ],
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
                MaterialPageRoute(
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
                MaterialPageRoute(
                  builder: (context) => const RecentPlayScreen(),
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
          // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 1,
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
          children: [
            // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
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
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Center(
            child: CircularProgressIndicator(color: colors.accent),
          ),
        );

        try {
          // 获取歌单中的歌曲（第一页，60首）
          final result = await _apiService.getPlaylistSongs(
            playlistId: playlistData['id'],
            page: 1,
            num: 60,
            uin: _qqNumber,
          );
          
          final List<Song> songs = result['songs'] as List<Song>;
          final int totalCount = result['totalCount'] as int;

          if (!mounted) return;

          Navigator.pop(context); // 关闭加载对话框

          // 检查是否有歌曲
          if (songs.isEmpty) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('该歌单暂无歌曲或无权限访问'),
                backgroundColor: Colors.orange,
              ),
            );
            return;
          }

          // 创建 Playlist 对象
          final playlist = Playlist(
            id: playlistData['id'],
            name: playlistData['name'],
            coverUrl: playlistData['coverUrl'],
            description: playlistData['description'],
            songs: songs,
          );

          if (!mounted) return;

          // 跳转到歌单详情页
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PlaylistDetailScreen(
                playlist: playlist,
                totalCount: totalCount,
                qqNumber: _qqNumber,
              ),
            ),
          );
        } catch (e) {
          if (!mounted) return;

          Navigator.pop(context); // 关闭加载对话框

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
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
            // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
            border: Border.all(
              color: colors.border.withValues(alpha: 0.5),
              width: 1,
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
                      playlistData['coverUrl'].isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: playlistData['coverUrl'],
                              fit: BoxFit.cover,
                              // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
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
                          // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
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
                          // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
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
                      playlistData['name'],
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (playlistData['description'].isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        playlistData['description'],
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
    
    showDialog(
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
            // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
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
              final newQQ = controller.text.trim();
              if (newQQ.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('QQ 号不能为空')),
                );
                return;
              }
              
              if (!RegExp(r'^\d+$').hasMatch(newQQ)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入有效的 QQ 号')),
                );
                return;
              }
              
              Navigator.pop(context);
              
              setState(() {
                _qqNumber = newQQ;
              });

              await _saveQQNumber(newQQ);
              // 切换 QQ 号后强制刷新
              _loadUserPlaylists(forceRefresh: true);

              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
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
    );
  }

  void _showClearCacheDialog(BuildContext context) async {
    final colors = Provider.of<ThemeProvider>(context, listen: false).colors;
    final cacheManager = CacheManagerService(); // 使用单例

    // 显示加载对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(color: colors.accent),
      ),
    );

    // 获取缓存信息
    final cacheInfo = await cacheManager.getCacheInfo();

    if (!mounted) return;

    // 关闭加载对话框
    Navigator.pop(context);

    // 格式化大小
    final totalSizeStr = cacheManager.formatSize(cacheInfo.totalSize);
    final audioSizeStr = cacheManager.formatSize(cacheInfo.audioSize);
    final coverSizeStr = cacheManager.formatSize(cacheInfo.coverSize);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.cleaning_services, color: colors.accent),
            SizedBox(width: 12),
            Text('清理缓存'),
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
            SizedBox(height: 12),
            _buildCacheItem(
              icon: Icons.music_note,
              label: '音频缓存',
              size: audioSizeStr,
              colors: colors,
            ),
            SizedBox(height: 8),
            _buildCacheItem(
              icon: Icons.image,
              label: '封面缓存',
              size: coverSizeStr,
              colors: colors,
            ),
            SizedBox(height: 16),
            Text(
              '清理缓存将删除所有已下载的音频和封面文件',
              style: TextStyle(
                fontSize: 13,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              // 显示加载对话框
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => Center(
                  child: CircularProgressIndicator(color: colors.accent),
                ),
              );

              // 清理缓存
              final success = await cacheManager.clearAllCache();

              if (!mounted) return;

              Navigator.pop(context); // 关闭加载对话框

              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
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
            child: Text('清理'),
          ),
        ],
      ),
    );
  }

  Widget _buildCacheItem({
    required IconData icon,
    required String label,
    required String size,
    required dynamic colors,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: colors.textSecondary),
        SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: colors.textSecondary,
          ),
        ),
        Spacer(),
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
