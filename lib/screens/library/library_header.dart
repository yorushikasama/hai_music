import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';
import '../../services/download/download_manager.dart';
import '../../theme/app_styles.dart';
import '../../utils/platform_utils.dart';
import '../../widgets/draggable_window_area.dart';

class LibraryHeader extends StatelessWidget {
  final VoidCallback onOpenDownloadProgress;
  final VoidCallback onOpenStorageConfig;

  const LibraryHeader({
    required this.onOpenDownloadProgress,
    required this.onOpenStorageConfig,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      floating: true,
      pinned: true,
      expandedHeight: 110,
      backgroundColor: Colors.transparent,
      actionsPadding: EdgeInsets.zero,
      flexibleSpace: Stack(
        children: [
          FlexibleSpaceBar(
            title: Text(
              '音乐库',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                letterSpacing: 0.5,
              ),
            ),
            titlePadding: const EdgeInsets.only(
              left: AppStyles.spacingXL,
              bottom: AppStyles.spacingM,
            ),
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
              return _DownloadBadge(
                downloadingCount: downloadingCount,
                onTap: onOpenDownloadProgress,
              );
            },
          ),
        ),
        _HeaderIconButton(
          icon: Icons.cloud_outlined,
          tooltip: '云端同步设置',
          onPressed: onOpenStorageConfig,
        ),
        const SizedBox(width: AppStyles.spacingL),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;

    return Padding(
      padding: const EdgeInsets.only(left: AppStyles.spacingM),
      child: IconButton(
        icon: Icon(icon, color: colors.textPrimary, size: 22),
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

class _DownloadBadge extends StatefulWidget {
  final int downloadingCount;
  final VoidCallback onTap;

  const _DownloadBadge({
    required this.downloadingCount,
    required this.onTap,
  });

  @override
  State<_DownloadBadge> createState() => _DownloadBadgeState();
}

class _DownloadBadgeState extends State<_DownloadBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    if (widget.downloadingCount > 0) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _DownloadBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.downloadingCount > 0 && oldWidget.downloadingCount == 0) {
      _pulseController.repeat(reverse: true);
    } else if (widget.downloadingCount == 0) {
      _pulseController.stop();
      _pulseController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(Icons.download_outlined, color: colors.textPrimary, size: 22),
          tooltip: '下载管理',
          onPressed: widget.onTap,
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
        if (widget.downloadingCount > 0)
          Positioned(
            right: 2,
            top: 2,
            child: ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                padding: const EdgeInsets.all(AppStyles.spacingXS),
                decoration: BoxDecoration(
                  color: colors.accent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: colors.accent.withValues(alpha: 0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  widget.downloadingCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
