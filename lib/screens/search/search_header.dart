import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';
import '../../theme/app_styles.dart';

/// 搜索页顶部区域（标题 + 多选工具栏 + 搜索框）
class SearchHeader extends StatelessWidget {
  final bool isSelectionMode;
  final int selectedCount;
  final int totalCount;
  final bool hasSearchResults;
  final TextEditingController searchController;
  final void Function(String) onSearchChanged;
  final void Function(String) onSearchSubmitted;
  final VoidCallback onEnterSelectionMode;
  final VoidCallback onCancelSelectionMode;
  final VoidCallback onToggleSelectAll;
  final VoidCallback onBatchAddFavorites;
  final VoidCallback onBatchDownload;

  const SearchHeader({
    super.key,
    required this.isSelectionMode,
    required this.selectedCount,
    required this.totalCount,
    required this.hasSearchResults,
    required this.searchController,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onEnterSelectionMode,
    required this.onCancelSelectionMode,
    required this.onToggleSelectAll,
    required this.onBatchAddFavorites,
    required this.onBatchDownload,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isSelectionMode ? Icons.checklist_rounded : Icons.search,
                color: isSelectionMode ? colors.accent : colors.textPrimary,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSelectionMode ? '选择歌曲' : '搜索',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
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
                      ),
                  ],
                ),
              ),
              if (hasSearchResults && !isSelectionMode)
                IconButton(
                  icon: Icon(Icons.checklist_rounded, color: colors.textSecondary, size: 24),
                  onPressed: onEnterSelectionMode,
                  tooltip: '多选',
                ),
              if (isSelectionMode) ...[
                if (selectedCount > 0)
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: colors.textSecondary, size: 22),
                    color: colors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    offset: const Offset(0, 50),
                    itemBuilder: (context) => [
                      PopupMenuItem<String>(
                        value: 'favorite',
                        child: Row(
                          children: [
                            Icon(Icons.favorite_border, color: colors.accent, size: 20),
                            const SizedBox(width: 12),
                            Text('批量喜欢', style: TextStyle(color: colors.textPrimary)),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'download',
                        child: Row(
                          children: [
                            Icon(Icons.download_outlined, color: colors.accent, size: 20),
                            const SizedBox(width: 12),
                            Text('批量下载', style: TextStyle(color: colors.textPrimary)),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'favorite') {
                        onBatchAddFavorites();
                      } else if (value == 'download') {
                        onBatchDownload();
                      }
                    },
                  ),
                TextButton(
                  onPressed: onToggleSelectAll,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    selectedCount == totalCount && totalCount > 0 ? '全不选' : '全选',
                    style: TextStyle(color: colors.accent, fontSize: 13),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: colors.textSecondary, size: 22),
                  onPressed: onCancelSelectionMode,
                  tooltip: '取消',
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            onSubmitted: onSearchSubmitted,
            style: TextStyle(color: colors.textPrimary),
            decoration: InputDecoration(
              hintText: '搜索歌曲、歌手、专辑...',
              hintStyle: TextStyle(color: colors.textSecondary),
              prefixIcon: Icon(Icons.search, color: colors.textSecondary),
              suffixIcon: searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: colors.textSecondary),
                      onPressed: () {
                        searchController.clear();
                        onSearchChanged('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: colors.card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppStyles.radiusMedium),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
