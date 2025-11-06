import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/play_history.dart';
import '../models/song.dart';
import '../providers/music_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_styles.dart';

/// 最近播放页面
class RecentPlayScreen extends StatefulWidget {
  const RecentPlayScreen({super.key});

  @override
  State<RecentPlayScreen> createState() => _RecentPlayScreenState();
}

class _RecentPlayScreenState extends State<RecentPlayScreen> {
  List<PlayHistory> _history = [];
  List<PlayHistory> _filteredHistory = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  // 🔧 优化:移除未使用的字段 _isSearching (只写入,从未读取)

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _searchController.addListener(_onSearchChanged);
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredHistory = List.from(_history);
      } else {
        _filteredHistory = _history.where((item) {
          return item.title.toLowerCase().contains(query) ||
                 item.artist.toLowerCase().contains(query) ||
                 item.album.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    
    final musicProvider = Provider.of<MusicProvider>(context, listen: false);
    final history = await musicProvider.historyService.getHistory();
    
    if (mounted) {
      setState(() {
        _history = history;
        _filteredHistory = List.from(history);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;
    final musicProvider = Provider.of<MusicProvider>(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: Column(
        children: [
          // 自定义顶部导航栏
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              bottom: 16,
            ),
            // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: 0.95),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // 返回按钮
                IconButton(
                  icon: Icon(Icons.arrow_back_ios_new, color: colors.textPrimary, size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.all(8),
                ),
                SizedBox(width: 8),
                // 标题
                Icon(Icons.history, color: colors.accent, size: 26),
                SizedBox(width: 12),
                Text(
                  '最近播放',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                Spacer(),
                // 清空按钮
                if (_history.isNotEmpty)
                  TextButton.icon(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('清空历史记录'),
                          content: Text('确定要清空所有播放历史吗？'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text('取消'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: Text('确定', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                      
                      if (confirm == true) {
                        await musicProvider.historyService.clearHistory();
                        _loadHistory();
                      }
                    },
                    icon: Icon(Icons.delete_outline, color: colors.textSecondary, size: 20),
                    label: Text(
                      '清空',
                      style: TextStyle(color: colors.textSecondary),
                    ),
                  ),
                SizedBox(width: 8),
                // 刷新按钮
                IconButton(
                  icon: Icon(Icons.refresh_rounded, color: colors.textSecondary, size: 22),
                  onPressed: _loadHistory,
                  tooltip: '刷新',
                  padding: EdgeInsets.all(8),
                ),
              ],
            ),
          ),
          // 搜索框
          if (_history.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: colors.textPrimary),
                decoration: InputDecoration(
                  hintText: '搜索历史记录...',
                  hintStyle: TextStyle(color: colors.textSecondary),
                  prefixIcon: Icon(Icons.search, color: colors.textSecondary),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: colors.textSecondary),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: colors.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          // 内容区域
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: colors.accent),
                  )
                : _history.isEmpty
                    ? _buildEmptyState(colors)
                    : _buildHistoryList(colors, musicProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeColors colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 80,
            // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
            color: colors.textSecondary.withValues(alpha: 0.5),
          ),
          SizedBox(height: AppStyles.spacingL),
          Text(
            '暂无播放记录',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          SizedBox(height: AppStyles.spacingS),
          Text(
            '播放过的歌曲会显示在这里',
            style: TextStyle(
              fontSize: 14,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(ThemeColors colors, MusicProvider musicProvider) {
    final displayList = _filteredHistory;
    
    if (displayList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
            Icon(Icons.search_off, size: 64, color: colors.textSecondary.withValues(alpha: 0.5)),
            SizedBox(height: 16),
            Text(
              '没有找到匹配的记录',
              style: TextStyle(color: colors.textSecondary, fontSize: 16),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: displayList.length,
      itemBuilder: (context, index) {
        final history = displayList[index];
        final isPlaying = musicProvider.currentSong?.id == history.id;
        
        return Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: _buildHistoryItem(history, isPlaying, colors, musicProvider),
        );
      },
    );
  }

  Widget _buildHistoryItem(
    PlayHistory history,
    bool isPlaying,
    ThemeColors colors,
    MusicProvider musicProvider,
  ) {
    return Container(
      // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
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
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            final song = Song(
              id: history.id,
              title: history.title,
              artist: history.artist,
              album: history.album,
              coverUrl: history.coverUrl,
              audioUrl: '',
              duration: history.duration,
              platform: history.platform,
            );
            
            musicProvider.playSong(song);
          },
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              children: [
                // 封面图
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: history.coverUrl,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: 60,
                          height: 60,
                          // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
                          color: colors.card.withValues(alpha: 0.3),
                          child: Icon(Icons.music_note, color: colors.textSecondary.withValues(alpha: 0.3)),
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: 60,
                          height: 60,
                          color: colors.card.withValues(alpha: 0.3),
                          child: Icon(Icons.music_note, color: colors.textSecondary),
                        ),
                      ),
                    ),
                    if (isPlaying)
                      Positioned.fill(
                        child: Container(
                          // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
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
                  ],
                ),
                SizedBox(width: 14),
                // 歌曲信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        history.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isPlaying ? colors.accent : colors.textPrimary,
                          height: 1.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Text(
                        history.artist,
                        style: TextStyle(
                          fontSize: 13,
                          // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
                          color: colors.textSecondary.withValues(alpha: 0.8),
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2),
                      Text(
                        _formatPlayedTime(history.playedAt),
                        style: TextStyle(
                          fontSize: 11,
                          // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
                          color: colors.textSecondary.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12),
                // 删除按钮
                IconButton(
                  // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
                  icon: Icon(Icons.close, color: colors.textSecondary.withValues(alpha: 0.6), size: 20),
                  onPressed: () {
                    setState(() {
                      _history.removeWhere((h) => h.id == history.id);
                    });
                    musicProvider.historyService.removeHistory(history.id);
                  },
                  padding: EdgeInsets.all(8),
                  constraints: BoxConstraints(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatPlayedTime(DateTime playedAt) {
    final now = DateTime.now();
    final difference = now.difference(playedAt);

    if (difference.inMinutes < 1) {
      return '刚刚';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}小时前';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    } else {
      return '${playedAt.month}月${playedAt.day}日';
    }
  }
}
