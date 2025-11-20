import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';
import '../../utils/platform_utils.dart';
import '../../widgets/draggable_window_area.dart';
import '../../services/download_manager.dart';

/// 音乐库页面顶部 SliverAppBar 头部
class LibraryHeader extends StatelessWidget {
  final VoidCallback onOpenDownloadProgress;
  final VoidCallback onOpenStorageConfig;
  final VoidCallback onClearCache;

  const LibraryHeader({
    super.key,
    required this.onOpenDownloadProgress,
    required this.onOpenStorageConfig,
    required this.onClearCache,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;

    return SliverAppBar(
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
        ChangeNotifierProvider.value(
          value: DownloadManager(),
          child: Consumer<DownloadManager>(
            builder: (context, manager, child) {
              final downloadingCount = manager.downloadingTasks.length;
              return Stack(
                children: [
                  IconButton(
                    icon: Icon(Icons.download_outlined, color: colors.textPrimary),
                    tooltip: '下载管理',
                    onPressed: onOpenDownloadProgress,
                  ),
                  if (downloadingCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: colors.accent,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          downloadingCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        IconButton(
          icon: Icon(Icons.cloud_outlined, color: colors.textPrimary),
          tooltip: '云端同步设置',
          onPressed: onOpenStorageConfig,
        ),
        IconButton(
          icon: Icon(Icons.cleaning_services_outlined, color: colors.textPrimary),
          tooltip: '清理缓存',
          onPressed: onClearCache,
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}
