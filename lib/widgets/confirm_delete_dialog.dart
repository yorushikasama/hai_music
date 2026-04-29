import 'package:flutter/material.dart';

import '../theme/app_styles.dart';

enum ConfirmDeleteType {
  single,
  batch,
  cache,
  allData,
}

class ConfirmDeleteDialog extends StatelessWidget {
  final ConfirmDeleteType type;
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final IconData icon;
  final bool destructive;
  final String? itemName;
  final int? itemCount;

  const ConfirmDeleteDialog({
    super.key,
    required this.type,
    required this.title,
    required this.message,
    required this.confirmText,
    required this.cancelText,
    required this.icon,
    required this.destructive,
    this.itemName,
    this.itemCount,
  });

  static Future<bool?> show(
    BuildContext context, {
    required ConfirmDeleteType type,
    required String title,
    required String message,
    String? itemName,
    int? itemCount,
    String confirmText = '删除',
    String cancelText = '取消',
    IconData icon = Icons.delete_outline_rounded,
    bool destructive = true,
  }) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) => ConfirmDeleteDialog(
        type: type,
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        icon: icon,
        destructive: destructive,
        itemName: itemName,
        itemCount: itemCount,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: BorderRadius.circular(AppStyles.radiusLarge),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(isDark),
            _buildBody(isDark),
            _buildActions(context, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    final iconColor = destructive ? Colors.red : const Color(0xFF3B82F6);
    final bgColor = destructive
        ? Colors.red.withValues(alpha: 0.1)
        : const Color(0xFF3B82F6).withValues(alpha: 0.1);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 32,
              color: iconColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1C1C1E),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    final secondaryColor =
        isDark ? const Color(0xFF9E9E9E) : const Color(0xFF6E6E73);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              color: secondaryColor,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          if (type == ConfirmDeleteType.batch && itemCount != null) ...[
            const SizedBox(height: 12),
            _buildInfoChip(
              '$itemCount 首歌曲',
              Icons.music_note,
              isDark,
            ),
          ],
          if (type == ConfirmDeleteType.allData) ...[
            const SizedBox(height: 12),
            _buildWarningChip(isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoChip(String text, IconData iconData, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconData, size: 14, color: isDark ? Colors.white70 : Colors.black54),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningChip(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded,
              size: 16, color: Colors.orange.shade700),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '此操作不可恢复，所有数据将被永久删除',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Row(
        children: [
          Expanded(
            child: _buildButton(
              text: cancelText,
              isPrimary: false,
              isDark: isDark,
              onTap: () => Navigator.of(context).pop(false),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildButton(
              text: confirmText,
              isPrimary: true,
              isDark: isDark,
              onTap: () => Navigator.of(context).pop(true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required String text,
    required bool isPrimary,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    if (isPrimary) {
      final bgColor = destructive ? Colors.red : const Color(0xFF3B82F6);
      return Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppStyles.radiusMedium),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppStyles.radiusMedium),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      );
    }

    final bgColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.05);
    final textColor = isDark ? Colors.white70 : Colors.black54;

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(AppStyles.radiusMedium),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppStyles.radiusMedium),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}
