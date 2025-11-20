import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';
import '../../utils/responsive.dart';
import '../../utils/platform_utils.dart';
import '../../widgets/theme_selector.dart';
import '../../widgets/draggable_window_area.dart';

/// 发现页顶部标题栏 SliverAppBar
class DiscoverHeader extends StatelessWidget {
  const DiscoverHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final padding = Responsive.getHorizontalPadding(context);
    final isDesktop = PlatformUtils.isDesktop;

    return SliverAppBar(
      floating: true,
      pinned: false,
      expandedHeight: 100,
      backgroundColor: Colors.transparent,
      flexibleSpace: Stack(
        children: [
          FlexibleSpaceBar(
            title: Text(
              'Hai Music',
              style: Theme.of(context).textTheme.headlineLarge!,
            ),
            titlePadding: EdgeInsets.only(left: padding.left, bottom: 16),
          ),
          // 桌面端拖动区域
          if (isDesktop)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 40,
              child: DraggableWindowBar(),
            ),
        ],
      ),
      actions: !isDesktop
          ? [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  icon: Text(
                    themeProvider.getThemeIcon(themeProvider.currentTheme),
                    style: const TextStyle(fontSize: 24),
                  ),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      builder: (context) => const ThemeSelector(),
                    );
                  },
                ),
              ),
            ]
          : null,
    );
  }
}
