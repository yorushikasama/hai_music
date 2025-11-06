import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_styles.dart';

class ThemeSelector extends StatelessWidget {
  const ThemeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final colors = themeProvider.colors;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppStyles.radiusLarge),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '选择主题',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.close, color: colors.textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 1,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: AppThemeMode.values.length,
            itemBuilder: (context, index) {
              final theme = AppThemeMode.values[index];
              final isSelected = themeProvider.currentTheme == theme;
              
              return _ThemeCard(
                theme: theme,
                isSelected: isSelected,
                onTap: () {
                  themeProvider.setTheme(theme);
                  Navigator.pop(context);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  final AppThemeMode theme;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.theme,
    required this.isSelected,
    required this.onTap,
  });

  ThemeColors _getPreviewColors() {
    switch (theme) {
      case AppThemeMode.dark:
        return ThemeColors.dark;
      case AppThemeMode.light:
        return ThemeColors.light;
      case AppThemeMode.purple:
        return ThemeColors.purple;
      case AppThemeMode.blue:
        return ThemeColors.blue;
      case AppThemeMode.pink:
        return ThemeColors.pink;
      case AppThemeMode.orange:
        return ThemeColors.orange;
      case AppThemeMode.green:
        return ThemeColors.green;
      case AppThemeMode.rainbow:
        return ThemeColors.rainbow;
    }
  }

  String _getThemeName() {
    switch (theme) {
      case AppThemeMode.dark:
        return '深色';
      case AppThemeMode.light:
        return '浅色';
      case AppThemeMode.purple:
        return '紫色';
      case AppThemeMode.blue:
        return '蓝色';
      case AppThemeMode.pink:
        return '粉色';
      case AppThemeMode.orange:
        return '橙色';
      case AppThemeMode.green:
        return '绿色';
      case AppThemeMode.rainbow:
        return '彩虹';
    }
  }

  String _getThemeIcon() {
    switch (theme) {
      case AppThemeMode.dark:
        return '🌙';
      case AppThemeMode.light:
        return '☀️';
      case AppThemeMode.purple:
        return '💜';
      case AppThemeMode.blue:
        return '💙';
      case AppThemeMode.pink:
        return '🌸';
      case AppThemeMode.orange:
        return '🍊';
      case AppThemeMode.green:
        return '🌿';
      case AppThemeMode.rainbow:
        return '🌈';
    }
  }

  @override
  Widget build(BuildContext context) {
    final previewColors = _getPreviewColors();
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: previewColors.backgroundGradient,
          color: previewColors.backgroundGradient == null 
              ? previewColors.background 
              : null,
          borderRadius: BorderRadius.circular(AppStyles.radiusMedium),
          border: Border.all(
            color: isSelected 
                ? previewColors.accent 
                : previewColors.border,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected
              ? [
                  // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
                  BoxShadow(
                    color: previewColors.accent.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _getThemeIcon(),
              style: const TextStyle(fontSize: 32),
            ),
            const SizedBox(height: 8),
            Text(
              _getThemeName(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: previewColors.textPrimary,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(height: 4),
              Icon(
                Icons.check_circle,
                size: 16,
                color: previewColors.accent,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
