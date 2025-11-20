import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';

/// 下载页面顶部导航栏 + TabBar 头部
class DownloadedHeader extends StatelessWidget {
  final TabController tabController;
  final int downloadedCount;
  final int localCount;
  final bool isSearching;
  final bool isSelectionMode;
  final int selectedCount;
  final int currentTabIndex;
  final String totalSizeLabel;
  final bool hasSongsInCurrentTab;
  final TextEditingController searchController;
  final VoidCallback onBack;
  final VoidCallback onToggleSearch;
  final VoidCallback onEnterSelectionMode;
  final VoidCallback onCancelSelection;
  final VoidCallback onToggleSelectAll;
  final VoidCallback onBatchDelete;
  final VoidCallback onScanLocalAudio;
  final VoidCallback onRefreshDownloaded;
  final ValueChanged<String> onSearchChanged;

  const DownloadedHeader({
    super.key,
    required this.tabController,
    required this.downloadedCount,
    required this.localCount,
    required this.isSearching,
    required this.isSelectionMode,
    required this.selectedCount,
    required this.currentTabIndex,
    required this.totalSizeLabel,
    required this.hasSongsInCurrentTab,
    required this.searchController,
    required this.onBack,
    required this.onToggleSearch,
    required this.onEnterSelectionMode,
    required this.onCancelSelection,
    required this.onToggleSelectAll,
    required this.onBatchDelete,
    required this.onScanLocalAudio,
    required this.onRefreshDownloaded,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;

    return SliverAppBar(
      pinned: true,
      backgroundColor: colors.surface.withValues(alpha: 0.95),
      elevation: 0,
      expandedHeight: 120,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new, color: colors.textPrimary, size: 20),
        onPressed: onBack,
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Container(
          color: colors.surface.withValues(alpha: 0.95),
          child: TabBar(
            controller: tabController,
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
                    Text('应用下载 ($downloadedCount)'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.folder_open, size: 20),
                    const SizedBox(width: 8),
                    Text('本地音乐 ($localCount)'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      title: isSearching
          ? TextField(
              controller: searchController,
              autofocus: true,
              style: TextStyle(color: colors.textPrimary),
              decoration: InputDecoration(
                hintText: '搜索下载的歌曲...',
                hintStyle: TextStyle(color: colors.textSecondary),
                border: InputBorder.none,
              ),
              onChanged: onSearchChanged,
            )
          : Row(
              children: [
                Icon(
                  isSelectionMode ? Icons.checklist_rounded : Icons.download,
                  color: isSelectionMode ? colors.accent : Colors.green,
                  size: 26,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isSelectionMode ? '选择歌曲' : '本地下载',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (isSelectionMode && selectedCount > 0)
                      Text(
                        '已选择 $selectedCount 首',
                        style: TextStyle(
                          color: colors.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else if (!isSelectionMode)
                      Text(
                        currentTabIndex == 0
                            ? '$downloadedCount 首 · $totalSizeLabel'
                            : '$localCount 首本地音乐',
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
        if (isSelectionMode) ...[
          if (selectedCount > 0)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
              onPressed: onBatchDelete,
              tooltip: '批量删除',
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            ),
          TextButton(
            onPressed: onToggleSelectAll,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              '全选',
              style: TextStyle(color: colors.accent, fontSize: 13),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: colors.textSecondary, size: 22),
            onPressed: onCancelSelection,
            tooltip: '取消',
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
        ] else ...[
          IconButton(
            icon: Icon(
              isSearching ? Icons.close : Icons.search,
              color: colors.textSecondary,
              size: 22,
            ),
            onPressed: onToggleSearch,
            tooltip: isSearching ? '关闭搜索' : '搜索',
          ),
          if (!isSearching && hasSongsInCurrentTab)
            IconButton(
              icon: Icon(Icons.checklist_rounded, color: colors.textSecondary, size: 22),
              onPressed: onEnterSelectionMode,
              tooltip: '多选',
            ),
          if (!isSearching && currentTabIndex == 1)
            Container(
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: colors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: IconButton(
                icon: Icon(Icons.refresh_rounded, color: colors.accent, size: 22),
                onPressed: onScanLocalAudio,
                tooltip: '扫描本地音乐',
              ),
            ),
          if (!isSearching && currentTabIndex == 0)
            IconButton(
              icon: Icon(Icons.refresh_rounded, color: colors.textSecondary, size: 22),
              onPressed: onRefreshDownloaded,
              tooltip: '刷新',
            ),
        ],
      ],
    );
  }
}
