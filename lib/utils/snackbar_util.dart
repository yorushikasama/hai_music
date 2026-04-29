import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';

import '../providers/theme_provider.dart';
import '../theme/app_styles.dart';

enum SnackBarType {
  success,
  warning,
  error,
  info,
}

class AppSnackBar {
  AppSnackBar._();

  static void show(
    String message, {
    SnackBarType type = SnackBarType.info,
    IconData? icon,
    Duration duration = const Duration(seconds: 2),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _showToast(
      message: message,
      type: type,
      icon: icon,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void showWithContext(
    BuildContext context,
    String message, {
    SnackBarType type = SnackBarType.info,
    IconData? icon,
    Duration duration = const Duration(seconds: 2),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _showToast(
      context: context,
      message: message,
      type: type,
      icon: icon,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static ThemeColors? _resolveColors(BuildContext? context) {
    if (context == null) return null;
    try {
      return Provider.of<ThemeProvider>(context, listen: false).colors;
    } catch (_) {
      return null;
    }
  }

  static void _showToast({
    BuildContext? context,
    required String message,
    required SnackBarType type,
    IconData? icon,
    required Duration duration,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final toastType = _mapType(type);
    final config = _typeConfig(type, _resolveColors(context));
    final displayIcon = icon ?? config.icon;

    if (actionLabel != null) {
      _showWithAction(
        context: context,
        message: message,
        toastType: toastType,
        config: config,
        icon: displayIcon,
        duration: duration,
        actionLabel: actionLabel,
        onAction: onAction,
      );
    } else {
      toastification.show(
        context: context,
        type: toastType,
        style: ToastificationStyle.fillColored,
        title: Text(
          message,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        icon: Icon(displayIcon, color: Colors.white, size: 20),
        autoCloseDuration: duration,
        showProgressBar: true,
        dragToClose: true,
        pauseOnHover: true,
        closeButtonShowType: CloseButtonShowType.onHover,
        alignment: Alignment.bottomCenter,
        borderRadius: AppStyles.borderRadiusMedium,
      );
    }
  }

  static void _showWithAction({
    BuildContext? context,
    required String message,
    required ToastificationType toastType,
    required _SnackBarConfig config,
    required IconData icon,
    required Duration duration,
    required String actionLabel,
    VoidCallback? onAction,
  }) {
    toastification.showCustom(
      context: context,
      autoCloseDuration: duration,
      alignment: Alignment.bottomCenter,
      builder: (context, holder) {
        return Container(
          decoration: BoxDecoration(
            color: config.backgroundColor,
            borderRadius: AppStyles.borderRadiusMedium,
            boxShadow: AppStyles.getShadows(false),
          ),
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppStyles.spacingL,
                vertical: AppStyles.spacingM,
              ),
              child: Row(
                children: [
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: AppStyles.spacingM),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppStyles.spacingS),
                  TextButton(
                    onPressed: () {
                      toastification.dismissById(holder.id);
                      onAction?.call();
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppStyles.spacingM,
                        vertical: AppStyles.spacingXS,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: Colors.white.withValues(alpha: 0.9),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppStyles.borderRadiusSmall,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                    child: Text(
                      actionLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static ToastificationType _mapType(SnackBarType type) {
    return switch (type) {
      SnackBarType.success => ToastificationType.success,
      SnackBarType.warning => ToastificationType.warning,
      SnackBarType.error => ToastificationType.error,
      SnackBarType.info => ToastificationType.info,
    };
  }

  static _SnackBarConfig _typeConfig(SnackBarType type, ThemeColors? colors) {
    final successColor = colors?.success ?? const Color(0xFF2E7D32);
    final warningColor = colors?.warning ?? const Color(0xFFEF6C00);
    final errorColor = colors?.error ?? const Color(0xFFC62828);
    final infoColor = colors?.info ?? const Color(0xFF1565C0);

    return switch (type) {
      SnackBarType.success => _SnackBarConfig(
          icon: Icons.check_circle_outline,
          backgroundColor: successColor,
        ),
      SnackBarType.warning => _SnackBarConfig(
          icon: Icons.warning_amber_rounded,
          backgroundColor: warningColor,
        ),
      SnackBarType.error => _SnackBarConfig(
          icon: Icons.error_outline_rounded,
          backgroundColor: errorColor,
        ),
      SnackBarType.info => _SnackBarConfig(
          icon: Icons.info_outline_rounded,
          backgroundColor: infoColor,
        ),
    };
  }
}

class _SnackBarConfig {
  final IconData icon;
  final Color backgroundColor;

  const _SnackBarConfig({
    required this.icon,
    required this.backgroundColor,
  });
}
