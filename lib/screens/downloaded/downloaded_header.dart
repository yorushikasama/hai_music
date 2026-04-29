import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';
import '../../theme/app_styles.dart';
import '../download_settings_screen.dart';

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
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;

    return SliverAppBar(
      pinned: true,
      backgroundColor: colors.surface.withValues(alpha: 0.97),
      elevation: 0,
      expandedHeight: 128,
      titleSpacing: 0,
      actionsPadding: EdgeInsets.zero,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(AppStyles.spacingS - 1),
          decoration: BoxDecoration(
            color: colors.card.withValues(alpha: 0.6),
            borderRadius: AppStyles.borderRadiusSmall,
          ),
          child: Icon(Icons.arrow_back_ios_new, color: colors.textPrimary, size: 16),
        ),
        onPressed: onBack,
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(52),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: AppStyles.spacingXL),
          decoration: BoxDecoration(
            color: colors.card.withValues(alpha: 0.5),
            borderRadius: AppStyles.borderRadiusXL,
          ),
          child: TabBar(
            controller: tabController,
            indicatorColor: colors.accent,
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.label,
            labelColor: colors.accent,
            unselectedLabelColor: colors.textSecondary,
            labelStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            dividerColor: Colors.transparent,
            tabs: [
              Tab(
                height: 44,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.download_rounded, size: 18),
                    const SizedBox(width: AppStyles.spacingXS),
                    Text('应用下载 ($downloadedCount)'),
                  ],
                ),
              ),
              Tab(
                height: 44,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.folder_open_rounded, size: 18),
                    const SizedBox(width: AppStyles.spacingXS),
                    Text('本地音乐 ($localCount)'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      title: isSearching
          ? Container(
              height: 40,
              decoration: BoxDecoration(
                color: colors.card.withValues(alpha: 0.6),
                borderRadius: AppStyles.borderRadiusMedium,
              ),
              child: TextField(
                controller: searchController,
                autofocus: true,
                style: TextStyle(color: colors.textPrimary, fontSize: 15),
                decoration: InputDecoration(
                  hintText: '搜索下载的歌曲...',
                  hintStyle: TextStyle(color: colors.textSecondary.withValues(alpha: 0.6)),
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search, color: colors.textSecondary, size: 20),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: onSearchChanged,
              ),
            )
          : SizedBox(
              width: 130,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppStyles.spacingXS + 2),
                    decoration: BoxDecoration(
                      color: (isSelectionMode ? colors.accent : colors.success)
                          .withValues(alpha: 0.15),
                      borderRadius: AppStyles.borderRadiusSmall,
                    ),
                    child: Icon(
                      isSelectionMode ? Icons.checklist_rounded : Icons.download_rounded,
                      color: isSelectionMode ? colors.accent : colors.success,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: AppStyles.spacingS),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isSelectionMode ? '选择歌曲' : '本地下载',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        if (isSelectionMode && selectedCount > 0)
                          Text(
                            '已选择 $selectedCount 首',
                            style: TextStyle(
                              color: colors.accent,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          )
                        else if (!isSelectionMode)
                          Text(
                            currentTabIndex == 0
                                ? '$downloadedCount 首 · $totalSizeLabel'
                                : '$localCount 首',
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 10,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      actions: [
        if (isSelectionMode) ...[
          if (selectedCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: AppStyles.spacingS),
              child: Material(
                color: colors.error.withValues(alpha: 0.12),
                borderRadius: AppStyles.borderRadiusSmall,
                child: InkWell(
                  borderRadius: AppStyles.borderRadiusSmall,
                  onTap: onBatchDelete,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppStyles.spacingM,
                      vertical: AppStyles.spacingS,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete_outline, color: colors.error, size: 18),
                        const SizedBox(width: AppStyles.spacingXS),
                        Text(
                          '删除($selectedCount)',
                          style: TextStyle(
                            color: colors.error,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          TextButton(
            onPressed: onToggleSelectAll,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: AppStyles.spacingS),
              minimumSize: const Size(0, 44),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              '全选',
              style: TextStyle(color: colors.accent, fontSize: 13),
            ),
          ),
          _HeaderIconButton(
            icon: Icons.close,
            tooltip: '取消',
            onPressed: onCancelSelection,
            color: colors.textSecondary,
          ),
        ] else ...[
          _HeaderIconButton(
            icon: isSearching ? Icons.close : Icons.search,
            tooltip: isSearching ? '关闭搜索' : '搜索',
            onPressed: onToggleSearch,
            color: colors.textSecondary,
          ),
          if (!isSearching && hasSongsInCurrentTab)
            _HeaderIconButton(
              icon: Icons.checklist_rounded,
              tooltip: '多选',
              onPressed: onEnterSelectionMode,
              color: colors.textSecondary,
            ),
          if (!isSearching && currentTabIndex == 1)
            _HeaderIconButton(
              icon: Icons.refresh_rounded,
              tooltip: '扫描本地音乐',
              onPressed: onScanLocalAudio,
              color: colors.accent,
            ),
          if (!isSearching && currentTabIndex == 0)
            _HeaderIconButton(
              icon: Icons.refresh_rounded,
              tooltip: '刷新',
              onPressed: onRefreshDownloaded,
              color: colors.textSecondary,
            ),
          if (!isSearching)
            _HeaderIconButton(
              icon: Icons.settings_outlined,
              tooltip: '下载设置',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (context) => const DownloadSettingsScreen(),
                  ),
                );
              },
              color: colors.textSecondary,
            ),
        ],
        const SizedBox(width: AppStyles.spacingL),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;

    return Padding(
      padding: const EdgeInsets.only(left: AppStyles.spacingM),
      child: IconButton(
        icon: Icon(icon, color: color ?? colors.textPrimary, size: 22),
        tooltip: tooltip,
        onPressed: onPressed,
        padding: const EdgeInsets.all(10),
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        style: ButtonStyle(
          backgroundColor: WidgetStatePropertyAll(
            colors.card.withValues(alpha: 0.5),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: AppStyles.borderRadiusSmall),
          ),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}
