import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/download_manager.dart';
import '../theme/app_styles.dart';

/// 下载进度查看页面
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
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            Consumer<DownloadManager>(
              builder: (context, manager, child) {
                return PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: colors.textSecondary),
                  onSelected: (value) {
                    switch (value) {
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
              return _buildEmptyState(colors);
            }

            return Column(
              children: [
                // 统计信息
                _buildStatistics(manager, colors),
                const SizedBox(height: 8),
                // 任务列表
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

  Widget _buildEmptyState(ThemeColors colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.download_outlined,
            size: 80,
            color: colors.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无下载任务',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '在播放器中点击下载按钮开始下载',
            style: TextStyle(
              fontSize: 14,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatistics(DownloadManager manager, ThemeColors colors) {
    final stats = manager.getStatistics();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
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
          _buildStatItem('下载中', stats['downloading']!, Colors.blue, colors),
          _buildStatItem('已完成', stats['completed']!, Colors.green, colors),
          _buildStatItem('失败', stats['failed']!, Colors.red, colors),
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
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
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
              // 状态图标
              _buildStatusIcon(task.status, colors),
              const SizedBox(width: 12),
              // 歌曲信息
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
              // 操作按钮
              _buildActionButton(context, task, manager, colors),
            ],
          ),
          // 进度条（仅下载中显示）
          if (task.status == DownloadStatus.downloading) ...[
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '下载中...',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                    Text(
                      '${(task.progress * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: task.progress,
                    backgroundColor: colors.border.withValues(alpha: 0.3),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ],
          // 错误信息（失败时显示）
          if (task.status == DownloadStatus.failed && task.errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              task.errorMessage!,
              style: TextStyle(
                fontSize: 12,
                color: Colors.red,
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
        color = Colors.blue;
        break;
      case DownloadStatus.completed:
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case DownloadStatus.failed:
        icon = Icons.error;
        color = Colors.red;
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
        return IconButton(
          icon: Icon(Icons.close, color: colors.textSecondary, size: 20),
          onPressed: () => manager.cancelDownload(task.id),
          tooltip: '取消',
        );
      case DownloadStatus.downloading:
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case DownloadStatus.failed:
        return IconButton(
          icon: const Icon(Icons.refresh, color: Colors.orange, size: 20),
          onPressed: () => manager.retryDownload(task.id),
          tooltip: '重试',
        );
      case DownloadStatus.completed:
        return Icon(Icons.done, color: Colors.green, size: 20);
      case DownloadStatus.cancelled:
        return Icon(Icons.cancel, color: colors.textSecondary, size: 20);
    }
  }

  static void _showClearAllDialog(
    BuildContext context,
    DownloadManager manager,
    ThemeColors colors,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.card,
        title: Text('清除所有任务', style: TextStyle(color: colors.textPrimary)),
        content: Text(
          '确定要清除所有下载任务吗？',
          style: TextStyle(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消', style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              manager.clearAll();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('清除'),
          ),
        ],
      ),
    );
  }
}
