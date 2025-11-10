import 'package:flutter/material.dart';
import '../utils/logger.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/mini_player.dart';
import '../widgets/theme_selector.dart';
import '../widgets/draggable_window_area.dart';
import '../utils/responsive.dart';
import '../utils/platform_utils.dart';
import '../theme/app_styles.dart';
import '../services/keyboard_shortcut_service.dart';
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
  String? _searchQuery; // 用于传递给搜索页的关键词
  Key _searchScreenKey = UniqueKey(); // 用于强制重建 SearchScreen

  // 动态生成页面列表，以便传递搜索关键词
  List<Widget> get _screens => [
    const DiscoverScreen(),
    SearchScreen(key: _searchScreenKey, initialQuery: _searchQuery),
    const LibraryScreen(),
  ];
  
  // 切换到搜索页并执行搜索
  void _navigateToSearch(String query) {
    Logger.debug('🔍 导航到搜索页，关键词: $query');
    setState(() {
      _searchQuery = query;
      _searchScreenKey = UniqueKey(); // 生成新的 key 强制重建
      _selectedIndex = 1; // 切换到搜索页
    });
  }

  @override
  Widget build(BuildContext context) {
    final musicProvider = Provider.of<MusicProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final colors = themeProvider.colors;
    final hasCurrentSong = musicProvider.currentSong != null;
    final isDesktop = Responsive.isDesktop(context);
    final isWeb = PlatformUtils.isWeb;

    // 🔧 添加快捷键支持 (仅桌面和 Web 平台)
    final scaffold = Scaffold(
      backgroundColor: Colors.transparent,
      bottomNavigationBar: (isDesktop || isWeb)
          ? null
          : ClipRect(
              child: BackdropFilter(
                filter: AppStyles.backdropBlur,
                // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
              child: Container(
                  decoration: BoxDecoration(
                    color: colors.surface.withValues(alpha: 0.75),
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
                  // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
                  colors: (colors.backgroundGradient as LinearGradient).colors
                      .map((c) => c.withValues(alpha: 0.95))
                      .toList(),
                )
              : colors.backgroundGradient,
          color: colors.backgroundGradient == null
              ? colors.background.withValues(alpha: 0.95)
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
                      // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
                      child: Container(
                        width: AppStyles.sidebarWidth,
                        decoration: BoxDecoration(
                          color: colors.surface.withValues(alpha: 0.75),
                          border: Border(
                            right: BorderSide(
                              color: colors.border,
                              width: 1,
                            ),
                          ),
                        ),
                    child: Column(
                      children: [
                        DraggableWindowArea(
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
                                // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
                                decoration: BoxDecoration(
                                  color: colors.accent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(AppStyles.radiusMedium),
                                  border: Border.all(
                                    color: colors.accent.withValues(alpha: 0.2),
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
                        // 快捷键帮助按钮 (仅桌面平台显示)
                        if (isDesktop || isWeb)
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              AppStyles.spacingXL,
                              0,
                              AppStyles.spacingXL,
                              AppStyles.spacingXL,
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  KeyboardShortcutService.showShortcutHelp(context);
                                },
                                borderRadius: BorderRadius.circular(AppStyles.radiusMedium),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: AppStyles.spacingL,
                                    vertical: AppStyles.spacingM,
                                  ),
                                  // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
                                  decoration: BoxDecoration(
                                    color: colors.surface.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(AppStyles.radiusMedium),
                                    border: Border.all(
                                      color: colors.border,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.keyboard,
                                        size: 18,
                                        color: colors.textSecondary,
                                      ),
                                      SizedBox(width: AppStyles.spacingS),
                                      Text(
                                        '快捷键',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: colors.textSecondary,
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
                      if (isDesktop && !isWeb)
                        DraggableWindowArea(
                          child: _buildTopDragArea(),
                        ),
                      Expanded(
                        child: _screens[_selectedIndex],
                      ),
                      if (hasCurrentSong) MiniPlayer(
                        onArtistTap: _navigateToSearch,
                      ),
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

    // 只在桌面和 Web 平台启用快捷键
    if (isDesktop || isWeb) {
      return Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          return KeyboardShortcutService.handleKeyEvent(
            event,
            musicProvider,
            context,
            onSearchRequested: () {
              // Ctrl+F: 切换到搜索页面
              setState(() {
                _selectedIndex = 1; // 搜索页面的索引
              });
            },
          );
        },
        child: scaffold,
      );
    }

    // 移动端不启用快捷键
    return scaffold;
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
            // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
            decoration: BoxDecoration(
              color: isSelected
                  ? colors.accent.withValues(alpha: 0.12)
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
          // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
        boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
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
                  if (PlatformUtils.isDesktop) {
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
                  if (PlatformUtils.isDesktop) {
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
                  if (PlatformUtils.isDesktop) {
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
