import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

/// 统一的错误提示组件
class ErrorWidget extends StatelessWidget {
  final String message;
  final String? actionText;
  final VoidCallback? onAction;
  final bool showIcon;

  const ErrorWidget({
    super.key,
    required this.message,
    this.actionText,
    this.onAction,
    this.showIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final colors = themeProvider.colors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showIcon)
              Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            if (showIcon)
              const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                color: colors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionText != null && onAction != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: ElevatedButton(
                  onPressed: onAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(actionText!),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 空状态组件
class EmptyWidget extends StatelessWidget {
  final String message;
  final String? actionText;
  final VoidCallback? onAction;
  final IconData? icon;

  const EmptyWidget({
    super.key,
    required this.message,
    this.actionText,
    this.onAction,
    this.icon = Icons.inbox,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final colors = themeProvider.colors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: colors.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                color: colors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionText != null && onAction != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: OutlinedButton(
                  onPressed: onAction,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: colors.accent),
                    foregroundColor: colors.accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(actionText!),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 网络错误组件
class NetworkErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const NetworkErrorWidget({
    super.key,
    this.message = '网络连接失败，请检查网络设置后重试',
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ErrorWidget(
      message: message,
      actionText: '重试',
      onAction: onRetry,
    );
  }
}
