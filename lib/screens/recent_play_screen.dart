import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/play_history.dart';
import '../models/song.dart';
import '../providers/music_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_styles.dart';
import '../widgets/confirm_delete_dialog.dart';

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

  @override
  void initState() {
    super.initState();
    unawaited(_loadHistory());
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
          _buildHeader(context, colors, musicProvider),
          if (_history.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppStyles.spacingXL,
                vertical: AppStyles.spacingS,
              ),
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
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: colors.accent))
                : _history.isEmpty
                    ? _buildEmptyState(context, colors)
                    : _buildHistoryList(context, colors, musicProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeColors colors, MusicProvider musicProvider) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + AppStyles.spacingS,
        left: AppStyles.spacingL,
        right: AppStyles.spacingL,
        bottom: AppStyles.spacingL,
      ),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.95),
        boxShadow: AppStyles.getShadows(colors.isLight),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: colors.textPrimary, size: 20),
            onPressed: () => Navigator.pop(context),
            padding: const EdgeInsets.all(AppStyles.spacingS),
          ),
          const SizedBox(width: AppStyles.spacingS),
          Container(
            padding: const EdgeInsets.all(AppStyles.spacingXS + 2),
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.15),
              borderRadius: AppStyles.borderRadiusSmall,
            ),
            child: Icon(Icons.history_rounded, color: colors.accent, size: 18),
          ),
          const SizedBox(width: AppStyles.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('最近播放', style: textTheme.headlineMedium),
                if (_history.isNotEmpty)
                  Text(
                    '${_history.length} 首',
                    style: textTheme.labelMedium,
                  ),
              ],
            ),
          ),
          if (_history.isNotEmpty)
            TextButton.icon(
              onPressed: () async {
                final confirm = await ConfirmDeleteDialog.show(
                  context,
                  type: ConfirmDeleteType.batch,
                  title: '清空历史记录',
                  message: '确定要清空所有播放历史吗？',
                  confirmText: '清空',
                  icon: Icons.history_rounded,
                );

                if (confirm ?? false) {
                  await musicProvider.historyService.clearHistory();
                  unawaited(_loadHistory());
                }
              },
              icon: Icon(Icons.delete_outline, color: colors.textSecondary, size: 20),
              label: Text('清空', style: TextStyle(color: colors.textSecondary)),
            ),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: colors.textSecondary, size: 22),
            onPressed: _loadHistory,
            tooltip: '刷新',
            padding: const EdgeInsets.all(AppStyles.spacingS),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeColors colors) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(AppStyles.spacingXXL),
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.history_rounded,
              size: 56,
              color: colors.textSecondary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: AppStyles.spacingXXL),
          Text('暂无播放记录', style: textTheme.titleLarge),
          const SizedBox(height: AppStyles.spacingS),
          Text('播放过的歌曲会显示在这里', style: textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildHistoryList(BuildContext context, ThemeColors colors, MusicProvider musicProvider) {
    final displayList = _filteredHistory;
    final textTheme = Theme.of(context).textTheme;

    if (displayList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: colors.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: AppStyles.spacingL),
            Text('没有找到匹配的记录', style: textTheme.bodyLarge),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: AppStyles.spacingXL,
        vertical: AppStyles.spacingL,
      ),
      itemCount: displayList.length,
      itemBuilder: (context, index) {
        final history = displayList[index];
        final isPlaying = musicProvider.currentSong?.id == history.id;

        return Padding(
          padding: const EdgeInsets.only(bottom: AppStyles.spacingM),
          child: _buildHistoryItem(context, history, isPlaying, colors, musicProvider, textTheme),
        );
      },
    );
  }

  Widget _buildHistoryItem(
    BuildContext context,
    PlayHistory history,
    bool isPlaying,
    ThemeColors colors,
    MusicProvider musicProvider,
    TextTheme textTheme,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isPlaying
            ? colors.accent.withValues(alpha: 0.08)
            : colors.surface.withValues(alpha: 0.6),
        borderRadius: AppStyles.borderRadiusLarge,
        border: Border.all(
          color: isPlaying
              ? colors.accent.withValues(alpha: 0.3)
              : colors.border.withValues(alpha: 0.1),
        ),
        boxShadow: AppStyles.getShadows(colors.isLight),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppStyles.borderRadiusLarge,
          onTap: () {
            final song = Song(
              id: history.id,
              title: history.title,
              artist: history.artist,
              album: history.album,
              coverUrl: history.coverUrl,
              duration: history.duration,
              platform: history.platform,
            );
            unawaited(musicProvider.playSong(song));
          },
          child: Padding(
            padding: const EdgeInsets.all(AppStyles.spacingM),
            child: Row(
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: AppStyles.borderRadiusMedium,
                      child: CachedNetworkImage(
                        imageUrl: history.coverUrl,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        memCacheWidth: 112,
                        memCacheHeight: 112,
                        placeholder: (context, url) => Container(
                          width: 56,
                          height: 56,
                          color: colors.card.withValues(alpha: 0.3),
                          child: Icon(Icons.music_note_rounded, color: colors.textSecondary.withValues(alpha: 0.3), size: 22),
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: 56,
                          height: 56,
                          color: colors.card.withValues(alpha: 0.3),
                          child: Icon(Icons.music_note_rounded, color: colors.textSecondary, size: 22),
                        ),
                        fadeInDuration: AppStyles.animNormal,
                      ),
                    ),
                    if (isPlaying)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: AppStyles.borderRadiusMedium,
                          ),
                          child: Icon(
                            musicProvider.isPlaying ? Icons.equalizer_rounded : Icons.pause_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: AppStyles.spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        history.title,
                        style: textTheme.titleSmall?.copyWith(
                          color: isPlaying ? colors.accent : colors.textPrimary,
                          height: 1.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppStyles.spacingXS),
                      Text(
                        history.artist,
                        style: textTheme.labelMedium?.copyWith(
                          color: colors.textSecondary.withValues(alpha: 0.8),
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatPlayedTime(history.playedAt),
                        style: textTheme.labelSmall?.copyWith(
                          color: colors.textSecondary.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppStyles.spacingM),
                IconButton(
                  icon: Icon(Icons.close, color: colors.textSecondary.withValues(alpha: 0.6), size: 20),
                  onPressed: () async {
                    await musicProvider.historyService.removeHistory(history.id);
                    if (mounted) {
                      setState(() {
                        _history.removeWhere((h) => h.id == history.id);
                        _filteredHistory.removeWhere((h) => h.id == history.id);
                      });
                    }
                  },
                  padding: const EdgeInsets.all(AppStyles.spacingS),
                  constraints: const BoxConstraints(),
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
