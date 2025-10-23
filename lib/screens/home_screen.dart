import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/mini_player.dart';
import '../widgets/theme_selector.dart';
import '../utils/responsive.dart';
import '../theme/app_styles.dart';
import 'discover_screen.dart';
import 'search_screen.dart';
import 'library_screen.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart' if (dart.library.html) '';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const DiscoverScreen(),
    const SearchScreen(),
    const LibraryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final musicProvider = Provider.of<MusicProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final colors = themeProvider.colors;
    final hasCurrentSong = musicProvider.currentSong != null;
    final isDesktop = Responsive.isDesktop(context);
    final isWeb = kIsWeb;
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      bottomNavigationBar: (isDesktop || isWeb)
          ? null
          : ClipRect(
              child: BackdropFilter(
                filter: AppStyles.backdropBlur,
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.surface.withOpacity(0.75),
                    boxShadow: AppStyles.getShadows(colors.isLight),
                    border: Border(
                      top: BorderSide(color: colors.border, width: 1),
                    ),
                  ),
                  child: SafeArea(
                    child: NavigationBar(
                      selectedIndex: _selectedIndex,
                      onDestinationSelected: (index) {
                        setState(() {
                          _selectedIndex = index;
                        });
                      },
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      destinations: const [
                        NavigationDestination(
                          icon: Icon(Icons.explore_outlined),
                          selectedIcon: Icon(Icons.explore),
                          label: '发现',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.search_outlined),
                          selectedIcon: Icon(Icons.search),
                          label: '搜索',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.library_music_outlined),
                          selectedIcon: Icon(Icons.library_music),
                          label: '音乐库',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      body: Container(
        decoration: BoxDecoration(
          gradient: colors.backgroundGradient != null && colors.backgroundGradient is LinearGradient
              ? LinearGradient(
                  begin: (colors.backgroundGradient as LinearGradient).begin,
                  end: (colors.backgroundGradient as LinearGradient).end,
                  colors: (colors.backgroundGradient as LinearGradient).colors
                      .map((c) => c.withOpacity(0.95))
                      .toList(),
                )
              : colors.backgroundGradient,
          color: colors.backgroundGradient == null 
              ? colors.background.withOpacity(0.95) 
              : null,
        ),
        child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                if (isDesktop)
                  ClipRRect(
                    child: BackdropFilter(
                      filter: AppStyles.backdropBlur,
                      child: Container(
                        width: AppStyles.sidebarWidth,
                        decoration: BoxDecoration(
                          color: colors.surface.withOpacity(0.75),
                          border: Border(
                            right: BorderSide(
                              color: colors.border,
                              width: 1,
                            ),
                          ),
                        ),
                    child: Column(
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onPanStart: !kIsWeb ? (_) {
                            try {
                              appWindow.startDragging();
                            } catch (e) {
                              // 忽略错误
                            }
                          } : null,
                          child: _buildTitleBar(colors),
                        ),
                        SizedBox(height: AppStyles.spacingL),
                        _buildSidebarItem(
                          icon: Icons.explore_outlined,
                          selectedIcon: Icons.explore,
                          label: '发现',
                          isSelected: _selectedIndex == 0,
                          onTap: () => setState(() => _selectedIndex = 0),
                        ),
                        _buildSidebarItem(
                          icon: Icons.search_outlined,
                          selectedIcon: Icons.search,
                          label: '搜索',
                          isSelected: _selectedIndex == 1,
                          onTap: () => setState(() => _selectedIndex = 1),
                        ),
                        _buildSidebarItem(
                          icon: Icons.library_music_outlined,
                          selectedIcon: Icons.library_music,
                          label: '音乐库',
                          isSelected: _selectedIndex == 2,
                          onTap: () => setState(() => _selectedIndex = 2),
                        ),
                        const Spacer(),
                        // 主题切换按钮
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            AppStyles.spacingXL,
                            AppStyles.spacingS,
                            AppStyles.spacingXL,
                            AppStyles.spacingXL,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  backgroundColor: Colors.transparent,
                                  builder: (context) => const ThemeSelector(),
                                );
                              },
                              borderRadius: BorderRadius.circular(AppStyles.radiusMedium),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: AppStyles.spacingL,
                                  vertical: AppStyles.spacingM,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.accent.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(AppStyles.radiusMedium),
                                  border: Border.all(
                                    color: colors.accent.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      themeProvider.getThemeIcon(themeProvider.currentTheme),
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                    SizedBox(width: AppStyles.spacingS),
                                    Text(
                                      themeProvider.themeName,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: colors.accent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                      ),
                    ),
                  ),
                Expanded(
                  child: Column(
                    children: [
                      if (isDesktop && !kIsWeb)
                        GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onPanStart: (_) {
                            try {
                              appWindow.startDragging();
                            } catch (e) {
                              // 忽略错误
                            }
                          },
                          child: _buildTopDragArea(),
                        ),
                      Expanded(
                        child: _screens[_selectedIndex],
                      ),
                      if (hasCurrentSong) const MiniPlayer(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colors = Provider.of<ThemeProvider>(context).colors;
    
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppStyles.spacingM, vertical: AppStyles.spacingXS),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppStyles.radiusSmall),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: AppStyles.spacingL, vertical: AppStyles.spacingM),
            decoration: BoxDecoration(
              color: isSelected
                  ? colors.accent.withOpacity(0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppStyles.radiusSmall),
            ),
            child: Row(
              children: [
                Icon(
                  isSelected ? selectedIcon : icon,
                  size: 22,
                  color: isSelected ? colors.accent : colors.textSecondary,
                ),
                SizedBox(width: AppStyles.spacingM),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? colors.textPrimary : colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMacOSButton({
    required Color color,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleBar(ThemeColors colors) {
    return Container(
      padding: EdgeInsets.all(AppStyles.spacingL),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildMacOSButton(
                color: const Color(0xFFFF5F57),
                onPressed: () {
                  if (!kIsWeb) {
                    try {
                      appWindow.close();
                    } catch (e) {
                      // 忽略错误
                    }
                  }
                },
              ),
              SizedBox(width: AppStyles.spacingS),
              _buildMacOSButton(
                color: const Color(0xFFFEBC2E),
                onPressed: () {
                  if (!kIsWeb) {
                    try {
                      appWindow.minimize();
                    } catch (e) {
                      // 忽略错误
                    }
                  }
                },
              ),
              SizedBox(width: AppStyles.spacingS),
              _buildMacOSButton(
                color: const Color(0xFF28C840),
                onPressed: () {
                  if (!kIsWeb) {
                    try {
                      appWindow.maximizeOrRestore();
                    } catch (e) {
                      // 忽略错误
                    }
                  }
                },
              ),
            ],
          ),
          SizedBox(height: AppStyles.spacingL),
          Text(
            'Hai Music',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopDragArea() {
    return Container(
      height: 40,
      color: Colors.transparent,
    );
  }
}
