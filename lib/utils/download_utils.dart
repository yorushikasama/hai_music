import 'package:flutter/material.dart';

import '../models/song.dart';
import '../services/download/download_service.dart';
import '../screens/download_progress_screen.dart';
import '../utils/snackbar_util.dart';

/// 下载相关公共工具方法
/// 统一处理 AddDownloadResult 枚举和批量下载逻辑，避免在各页面重复代码
class DownloadUtils {
  DownloadUtils._();

  /// 处理单个下载结果，显示对应的 SnackBar 提示
  ///
  /// [context] - BuildContext，用于显示 SnackBar 和导航
  /// [result] - 下载操作的结果枚举
  /// [songTitle] - 歌曲标题，用于提示信息
  static void handleAddDownloadResult(
    BuildContext context,
    AddDownloadResult result,
    String songTitle,
  ) {
    if (!context.mounted) return;

    switch (result) {
      case AddDownloadResult.added:
        AppSnackBar.show(
          '已添加到下载队列：$songTitle',
          type: SnackBarType.success,
          actionLabel: '查看',
          onAction: () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (context) => const DownloadProgressScreen(),
              ),
            );
          },
        );
      case AddDownloadResult.qualityUpgraded:
        AppSnackBar.show(
          '音质提升：正在重新下载$songTitle',
          type: SnackBarType.info,
          actionLabel: '查看',
          onAction: () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (context) => const DownloadProgressScreen(),
              ),
            );
          },
        );
      case AddDownloadResult.alreadyExists:
        AppSnackBar.show(
          '《$songTitle》已在下载列表中',
          type: SnackBarType.warning,
        );
      case AddDownloadResult.wifiRequired:
        AppSnackBar.show(
          '当前非WiFi网络，请在下载设置中关闭"仅WiFi下载"',
          type: SnackBarType.warning,
        );
      case AddDownloadResult.storageInsufficient:
        AppSnackBar.show(
          '存储空间不足，请清理后重试',
          type: SnackBarType.error,
        );
    }
  }

  /// 批量下载歌曲列表
  ///
  /// [context] - BuildContext
  /// [songs] - 待下载的歌曲列表
  /// [onComplete] - 下载完成后的回调（可选）
  ///
  /// 返回一个 Map 包含统计信息：added、alreadyExists、failed 等
  static Future<Map<String, int>> batchDownload(
    BuildContext context,
    List<Song> songs, {
    VoidCallback? onComplete,
  }) async {
    final result = await DownloadService().batchAddDownloads(songs);

    if (context.mounted) {
      final parts = <String>[];
      if (result.added > 0) parts.add('新增 ${result.added} 首');
      if (result.alreadyExists > 0) parts.add('已存在 ${result.alreadyExists} 首');
      if (result.failed > 0) parts.add('失败 ${result.failed} 首');

      AppSnackBar.show(
        '批量下载完成：${parts.join("，")}',
        type: result.added > 0 ? SnackBarType.success : SnackBarType.warning,
        actionLabel: result.added > 0 ? '查看' : null,
        onAction: result.added > 0
            ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (context) => const DownloadProgressScreen(),
                  ),
                );
              }
            : null,
      );
    }

    onComplete?.call();
    return {'added': result.added, 'alreadyExists': result.alreadyExists, 'failed': result.failed};
  }
}
