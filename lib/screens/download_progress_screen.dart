import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/download/download_manager.dart';
import '../theme/app_styles.dart';
import '../widgets/confirm_delete_dialog.dart';

class DownloadProgressScreen extends StatelessWidget {
  const DownloadProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;

    return ChangeNotifierProvider.value(
      value: DownloadManager(),
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: colors.surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: colors.textPrimary, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            '下载管理',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          actions: [
            Consumer<DownloadManager>(
              builder: (context, manager, child) {
                return PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: colors.textSecondary),
                  onSelected: (value) {
                    switch (value) {
                      case 'pause_all':
                        manager.pauseAll();
                        break;
                      case 'resume_all':
                        manager.resumeAll();
                        break;
                      case 'clear_completed':
                        manager.clearCompleted();
                        break;
                      case 'clear_failed':
                        manager.clearFailed();
                        break;
                      case 'clear_all':
                        _showClearAllDialog(context, manager, colors);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'pause_all',
                      child: Text('全部暂停'),
                    ),
                    const PopupMenuItem(
                      value: 'resume_all',
                      child: Text('全部继续'),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'clear_completed',
                      child: Text('清除已完成'),
                    ),
                    const PopupMenuItem(
                      value: 'clear_failed',
                      child: Text('清除失败任务'),
                    ),
                    const PopupMenuItem(
                      value: 'clear_all',
                      child: Text('清除所有任务'),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        body: Consumer<DownloadManager>(
          builder: (context, manager, child) {
            final tasks = manager.tasks;

            if (tasks.isEmpty) {
              return _buildEmptyState(context, colors);
            }

            return Column(
              children: [
                _buildStatistics(manager, colors),
                const SizedBox(height: AppStyles.spacingS),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppStyles.spacingL,
                      vertical: AppStyles.spacingS,
                    ),
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      return _buildTaskItem(context, task, manager, colors);
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeColors colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.download_outlined,
            size: 80,
            color: colors.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppStyles.spacingL),
          Text(
            '暂无下载任务',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppStyles.spacingS),
          Text(
            '在播放器中点击下载按钮开始下载',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildStatistics(DownloadManager manager, ThemeColors colors) {
    final stats = manager.getStatistics();

    return Container(
      margin: const EdgeInsets.all(AppStyles.spacingL),
      padding: const EdgeInsets.all(AppStyles.spacingL),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(AppStyles.radiusMedium),
        border: Border.all(color: colors.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('总计', stats['total']!, colors.textPrimary, colors),
          _buildStatItem('等待', stats['waiting']!, colors.textSecondary, colors),
          _buildStatItem('下载中', stats['downloading']!, colors.info, colors),
          _buildStatItem('暂停', stats['paused']!, colors.warning, colors),
          _buildStatItem('完成', stats['completed']!, colors.success, colors),
          _buildStatItem('失败', stats['failed']!, colors.error, colors),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int count, Color color, ThemeColors colors) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildTaskItem(
    BuildContext context,
    DownloadTask task,
    DownloadManager manager,
    ThemeColors colors,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppStyles.spacingM),
      padding: const EdgeInsets.all(AppStyles.spacingM),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppStyles.radiusMedium),
        border: Border.all(color: colors.border.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildStatusIcon(task.status, colors),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.song.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      task.song.artist,
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              _buildActionButton(context, task, manager, colors),
            ],
          ),
          if (task.status == DownloadStatus.downloading ||
              task.status == DownloadStatus.paused) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  task.status == DownloadStatus.paused ? '已暂停' : '下载中...',
                  style: TextStyle(
                      fontSize: 12,
                      color: task.status == DownloadStatus.paused
                          ? colors.warning
                          : colors.textSecondary,
                    ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (task.speedText.isNotEmpty) ...[
                      Text(
                        task.speedText,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      task.progressText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.info,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: task.progress,
                backgroundColor: colors.border.withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation<Color>(
                  task.status == DownloadStatus.paused ? colors.warning : colors.info,
                ),
                minHeight: 6,
              ),
            ),
            if (task.status == DownloadStatus.downloading &&
                task.remainingTime != '--:--') ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '剩余 ${task.remainingTime}',
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
          ],
          if (task.status == DownloadStatus.failed && task.errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              task.errorMessage!,
              style: TextStyle(
                fontSize: 12,
                color: colors.error,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusIcon(DownloadStatus status, ThemeColors colors) {
    IconData icon;
    Color color;

    switch (status) {
      case DownloadStatus.waiting:
        icon = Icons.schedule;
        color = colors.textSecondary;
        break;
      case DownloadStatus.downloading:
        icon = Icons.downloading;
        color = colors.info;
        break;
      case DownloadStatus.paused:
        icon = Icons.pause_circle;
        color = colors.warning;
        break;
      case DownloadStatus.completed:
        icon = Icons.check_circle;
        color = colors.success;
        break;
      case DownloadStatus.failed:
        icon = Icons.error;
        color = colors.error;
        break;
      case DownloadStatus.cancelled:
        icon = Icons.cancel;
        color = colors.textSecondary;
        break;
    }

    return Icon(icon, color: color, size: 24);
  }

  Widget _buildActionButton(
    BuildContext context,
    DownloadTask task,
    DownloadManager manager,
    ThemeColors colors,
  ) {
    switch (task.status) {
      case DownloadStatus.waiting:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.pause, color: colors.warning, size: 20),
              onPressed: () => manager.pauseDownload(task.id),
              tooltip: '暂停',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            IconButton(
              icon: Icon(Icons.close, color: colors.textSecondary, size: 20),
              onPressed: () => manager.cancelDownload(task.id),
              tooltip: '取消',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        );
      case DownloadStatus.downloading:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.pause, color: colors.warning, size: 20),
              onPressed: () => manager.pauseDownload(task.id),
              tooltip: '暂停',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            IconButton(
              icon: Icon(Icons.close, color: colors.textSecondary, size: 20),
              onPressed: () => manager.cancelDownload(task.id),
              tooltip: '取消',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        );
      case DownloadStatus.paused:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.play_arrow, color: colors.info, size: 22),
              onPressed: () => manager.resumeDownload(task.id),
              tooltip: '继续',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            IconButton(
              icon: Icon(Icons.close, color: colors.textSecondary, size: 20),
              onPressed: () => manager.cancelDownload(task.id),
              tooltip: '取消',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        );
      case DownloadStatus.failed:
        return IconButton(
          icon: Icon(Icons.refresh, color: colors.warning, size: 20),
          onPressed: () => manager.retryDownload(task.id),
          tooltip: '重试',
        );
      case DownloadStatus.completed:
        return Icon(Icons.done, color: colors.success, size: 20);
      case DownloadStatus.cancelled:
        return Icon(Icons.cancel, color: colors.textSecondary, size: 20);
    }
  }

  static void _showClearAllDialog(
    BuildContext context,
    DownloadManager manager,
    ThemeColors colors,
  ) {
    ConfirmDeleteDialog.show(
      context,
      type: ConfirmDeleteType.batch,
      title: '清除所有任务',
      message: '确定要清除所有下载任务吗？',
      confirmText: '清除',
      icon: Icons.clear_all_rounded,
    ).then((confirmed) {
      if (confirmed == true) {
        manager.clearAll();
      }
    });
  }
}
