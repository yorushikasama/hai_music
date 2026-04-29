import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';
import '../../theme/app_styles.dart';
import '../../utils/snackbar_util.dart';

class LibraryDialogs {
  static Future<void> showEditQQDialog(
    BuildContext context, {
    required String currentQQ,
    required void Function(String) onQQSaved,
  }) async {
    final colors = Provider.of<ThemeProvider>(context, listen: false).colors;
    final textTheme = Theme.of(context).textTheme;
    final controller = TextEditingController(text: currentQQ);

    unawaited(showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(borderRadius: AppStyles.borderRadiusLarge),
        title: Text(
          '修改 QQ 号',
          style: textTheme.titleLarge,
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'QQ 号',
            labelStyle: TextStyle(color: colors.textSecondary),
            hintText: '请输入 QQ 号',
            hintStyle: TextStyle(color: colors.textSecondary.withValues(alpha: 0.5)),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: colors.border),
              borderRadius: AppStyles.borderRadiusSmall,
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: colors.accent, width: 2),
              borderRadius: AppStyles.borderRadiusSmall,
            ),
          ),
          style: TextStyle(color: colors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              '取消',
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);

              final newQQ = controller.text.trim();
              if (newQQ.isEmpty) {
                AppSnackBar.showWithContext(
                  context,
                  'QQ号不能为空',
                  type: SnackBarType.warning,
                );
                return;
              }

              if (!RegExp(r'^\d+$').hasMatch(newQQ)) {
                AppSnackBar.showWithContext(
                  context,
                  '请输入有效的QQ号',
                  type: SnackBarType.warning,
                );
                return;
              }

              navigator.pop();
              onQQSaved(newQQ);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: AppStyles.borderRadiusSmall,
              ),
            ),
            child: const Text('确定'),
          ),
        ],
      ),
    ));
  }
}
