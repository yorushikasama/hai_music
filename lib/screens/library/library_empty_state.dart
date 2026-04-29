import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';
import '../../theme/app_styles.dart';

class LibraryEmptyState extends StatelessWidget {
  final String qqNumber;
  final VoidCallback onSetQQ;

  const LibraryEmptyState({
    required this.qqNumber,
    required this.onSetQQ,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppStyles.spacingXL),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Container(
          padding: const EdgeInsets.all(AppStyles.spacingXXXL),
          decoration: BoxDecoration(
            color: colors.card.withValues(alpha: 0.5),
            borderRadius: AppStyles.borderRadiusLarge,
            border: Border.all(color: colors.border.withValues(alpha: 0.1)),
          ),
          child: Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppStyles.spacingXXL),
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    qqNumber.isEmpty
                        ? Icons.person_outline_rounded
                        : Icons.library_music_outlined,
                    size: 48,
                    color: colors.textSecondary.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: AppStyles.spacingXXL),
                Text(
                  qqNumber.isEmpty ? '未设置 QQ 号' : '暂无歌单',
                  style: textTheme.titleLarge,
                ),
                const SizedBox(height: AppStyles.spacingS),
                Text(
                  qqNumber.isEmpty
                      ? '点击右上角设置按钮输入 QQ 号'
                      : '该 QQ 账号没有公开歌单',
                  style: textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
                if (qqNumber.isEmpty) ...[
                  const SizedBox(height: AppStyles.spacingXXL),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onSetQQ,
                      borderRadius: AppStyles.borderRadiusMedium,
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colors.accent,
                              colors.accent.withValues(alpha: 0.8),
                            ],
                          ),
                          borderRadius: AppStyles.borderRadiusMedium,
                          boxShadow: [
                            BoxShadow(
                              color: colors.accent.withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppStyles.spacingXXL,
                            vertical: AppStyles.spacingM,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
                              const SizedBox(width: AppStyles.spacingS),
                              Text(
                                '设置 QQ 号',
                                style: textTheme.labelLarge?.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
