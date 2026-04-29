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
      padding: const EdgeInsets.all(AppStyles.spacingXL),
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
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.close, color: colors.textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: AppStyles.spacingXL),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: AppStyles.spacingM,
              mainAxisSpacing: AppStyles.spacingM,
              childAspectRatio: 0.85,
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
                  Future.delayed(const Duration(milliseconds: 350), () {
                    if (context.mounted) Navigator.pop(context);
                  });
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ThemeCard extends StatefulWidget {
  final AppThemeMode theme;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.theme,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_ThemeCard> createState() => _ThemeCardState();
}

class _ThemeCardState extends State<_ThemeCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: AppStyles.animFast,
      lowerBound: 0.95,
      upperBound: 1.0,
      value: 1.0,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: AppStyles.animCurve,
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _scaleController.reverse();
  void _onTapUp(TapUpDetails _) => _scaleController.forward();
  void _onTapCancel() => _scaleController.forward();

  @override
  Widget build(BuildContext context) {
    final previewColors = widget.theme.colors;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: AppStyles.animNormal,
          curve: AppStyles.animCurve,
          decoration: BoxDecoration(
            gradient: previewColors.backgroundGradient,
            color: previewColors.backgroundGradient == null
                ? previewColors.background
                : null,
            borderRadius: AppStyles.borderRadiusMedium,
            border: Border.all(
              color: widget.isSelected ? previewColors.accent : previewColors.border,
              width: widget.isSelected ? 2.5 : 1,
            ),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: previewColors.accent.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.theme.icon,
                size: 26,
                color: previewColors.textPrimary,
              ),
              const SizedBox(height: AppStyles.spacingS),
              Text(
                widget.theme.displayName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: previewColors.textPrimary,
                ),
              ),
              AnimatedSwitcher(
                duration: AppStyles.animFast,
                child: widget.isSelected
                    ? Padding(
                        key: const ValueKey('check'),
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.check_circle,
                          size: 14,
                          color: previewColors.accent,
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey('no_check')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
