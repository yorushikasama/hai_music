import 'package:flutter/material.dart';

import '../../models/storage_config.dart';
import '../../services/favorite/clipboard_config_parser.dart';

/// 存储配置对话框集合
class StorageConfigDialogs {
  /// 显示配置格式说明对话框
  static void showImportHelpDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('配置格式说明'),
        content: SingleChildScrollView(
          child: Text(
            ClipboardConfigParser.generateExample(),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  /// 显示导入确认对话框
  static Future<bool?> showImportConfirmDialog(
    BuildContext context,
    StorageConfig config,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认导入配置'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('将从剪贴板导入以下配置：'),
            const SizedBox(height: 12),
            Text('Supabase URL: ${config.supabaseUrl}', style: const TextStyle(fontSize: 13)),
            Text('R2 Endpoint: ${config.r2Endpoint}', style: const TextStyle(fontSize: 13)),
            Text('Bucket: ${config.r2BucketName}', style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            const Text(
              '⚠️ 请确认配置来源可信，错误的配置可能导致数据异常。',
              style: TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认导入'),
          ),
        ],
      ),
    );
  }
}
