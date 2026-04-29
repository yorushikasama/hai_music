import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/playlist.dart';
import '../models/song.dart';
import '../providers/theme_provider.dart';
import '../repositories/music_repository.dart';
import '../services/core/preferences_service.dart';
import '../theme/app_styles.dart';
import '../utils/logger.dart';
import '../utils/responsive.dart';
import '../utils/snackbar_util.dart';
import 'download_progress_screen.dart';
import 'downloaded_songs_screen.dart';
import 'favorites_screen.dart';
import 'library/library_dialogs.dart';
import 'library/library_empty_state.dart';
import 'library/library_header.dart';
import 'library/library_playlist_card.dart';
import 'library/library_quick_actions.dart';
import 'playlist_detail_screen.dart';
import 'recent_play_screen.dart';
import 'storage_config_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _repository = MusicRepository();
  List<Map<String, dynamic>> _userPlaylists = [];
  bool _isLoading = true;
  String _qqNumber = '';

  @override
  void initState() {
    super.initState();
    unawaited(_loadQQNumber());
  }

  Future<void> _loadQQNumber() async {
    final prefs = PreferencesService();
    final savedQQ = await prefs.getQQNumber();
    if (savedQQ.isNotEmpty) {
      setState(() {
        _qqNumber = savedQQ;
      });
      unawaited(_loadUserPlaylists());
    } else {
      setState(() => _isLoading = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showEditQQDialog();
      });
    }
  }

  Future<void> _saveQQNumber(String qqNumber) async {
    await PreferencesService().setQQNumber(qqNumber);
  }

  Future<void> _loadUserPlaylists({bool forceRefresh = false}) async {
    if (_qqNumber.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      if (!forceRefresh) {
        final cachedPlaylists = await _repository.getUserPlaylists(_qqNumber);
        if (cachedPlaylists != null) {
          if (mounted) {
            setState(() {
              _userPlaylists = cachedPlaylists;
              _isLoading = false;
            });
          }
          return;
        }
      }

      final playlists = await _repository.fetchUserPlaylists(_qqNumber);

      if (mounted) {
        setState(() {
          _userPlaylists = playlists;
          _isLoading = false;
        });
      }

      await _repository.saveUserPlaylists(_qqNumber, playlists);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showEditQQDialog() {
    LibraryDialogs.showEditQQDialog(
      context,
      currentQQ: _qqNumber,
      onQQSaved: (newQQ) async {
        setState(() {
          _qqNumber = newQQ;
        });

        await _saveQQNumber(newQQ);
        unawaited(_loadUserPlaylists(forceRefresh: true));

        if (!mounted) return;
        AppSnackBar.show(
          '已切换到QQ号：$newQQ',
          type: SnackBarType.success,
        );
      },
    );
  }

  Future<void> _openPlaylistDetail(Map<String, dynamic> playlistData) async {
    final colors = Provider.of<ThemeProvider>(context, listen: false).colors;

    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(color: colors.accent),
      ),
    ));

    final navigator = Navigator.of(context);

    try {
      Logger.info('开始加载我的歌单: ${playlistData['name']} (ID: ${playlistData['id']})', 'LibraryScreen');

      final result = await _repository.getPlaylistSongs(
        playlistId: playlistData['id'] as String,
      );

      final List<Song> songs = (result['songs'] as List<dynamic>?)?.cast<Song>().toList() ?? [];
      final int apiTotalCount = result['totalCount'] as int? ?? 0;
      final int playlistSongCount = playlistData['songCount'] as int? ?? 0;
      final int totalCount = playlistSongCount > 0 ? playlistSongCount : (apiTotalCount > 0 ? apiTotalCount : songs.length);

      Logger.info('我的歌单加载完成: ${songs.length} 首歌曲，总数: $totalCount (API: $apiTotalCount, 歌单信息: $playlistSongCount)', 'LibraryScreen');

      if (!mounted) {
        navigator.pop();
        return;
      }

      navigator.pop();

      if (!mounted) return;

      final playlist = Playlist(
        id: (playlistData['id'] ?? '') as String,
        name: (playlistData['name'] ?? '') as String,
        coverUrl: (playlistData['coverUrl'] ?? '') as String,
        songs: songs,
      );

      unawaited(navigator.push(
        PageRouteBuilder<void>(
          pageBuilder: (context, animation, secondaryAnimation) => PlaylistDetailScreen(
            playlist: playlist,
            totalCount: totalCount,
            qqNumber: _qqNumber,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(parent: animation, curve: AppStyles.animCurve),
              child: child,
            );
          },
          transitionDuration: AppStyles.animNormal,
        ),
      ));
    } catch (e) {
      Logger.error('我的歌单加载失败: ${playlistData['name']} (ID: ${playlistData['id']})', e, null, 'LibraryScreen');

      if (!mounted) {
        navigator.pop();
        return;
      }
      AppSnackBar.show(
        '加载歌单失败：$e',
        type: SnackBarType.error,
      );
    }
  }

  void _navigateTo(Widget screen) {
    Navigator.push(
      context,
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: AppStyles.animCurve),
            child: child,
          );
        },
        transitionDuration: AppStyles.animNormal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            LibraryHeader(
              onOpenDownloadProgress: () => _navigateTo(const DownloadProgressScreen()),
              onOpenStorageConfig: () => _navigateTo(const StorageConfigScreen()),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppStyles.spacingXL),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LibraryQuickActions(
                      onFavoritesTap: () => _navigateTo(const FavoritesScreen()),
                      onRecentTap: () => _navigateTo(const RecentPlayScreen()),
                      onDownloadedTap: () => _navigateTo(const DownloadedSongsScreen()),
                    ),
                    const SizedBox(height: AppStyles.spacingXXL),
                    _buildPlaylistHeader(colors),
                    const SizedBox(height: AppStyles.spacingL),
                  ],
                ),
              ),
            ),
            if (_isLoading)
              SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppStyles.spacingXXXL),
                    child: CircularProgressIndicator(color: colors.accent),
                  ),
                ),
              )
            else if (_userPlaylists.isEmpty)
              SliverToBoxAdapter(
                child: LibraryEmptyState(
                  qqNumber: _qqNumber,
                  onSetQQ: _showEditQQDialog,
                ),
              )
            else
              SliverPadding(
                padding: Responsive.getHorizontalPadding(context),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: Responsive.getCrossAxisCount(context),
                    childAspectRatio: _getChildAspectRatio(context),
                    crossAxisSpacing: AppStyles.spacingM,
                    mainAxisSpacing: AppStyles.spacingM,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return LibraryPlaylistCard(
                        playlistData: _userPlaylists[index],
                        onTap: () => _openPlaylistDetail(_userPlaylists[index]),
                      );
                    },
                    childCount: _userPlaylists.length,
                  ),
                ),
              ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
          ],
        ),
      ),
    );
  }

  double _getChildAspectRatio(BuildContext context) {
    if (Responsive.isDesktop(context)) {
      return 0.78;
    } else if (Responsive.isTablet(context)) {
      return 0.76;
    } else {
      return 0.74;
    }
  }

  Widget _buildPlaylistHeader(ThemeColors colors) {
    return Row(
      children: [
        Text(
          '我的歌单',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(width: AppStyles.spacingS),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _showEditQQDialog,
            borderRadius: AppStyles.borderRadiusSmall,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppStyles.spacingS,
                vertical: AppStyles.spacingXS,
              ),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: AppStyles.borderRadiusSmall,
                border: Border.all(color: colors.border.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.edit_rounded,
                    size: 14,
                    color: colors.textSecondary.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: AppStyles.spacingXS),
                  Text(
                    'QQ: $_qqNumber',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
        const Spacer(),
        if (!_isLoading)
          _RefreshButton(
            onPressed: () => _loadUserPlaylists(forceRefresh: true),
          ),
      ],
    );
  }
}

class _RefreshButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _RefreshButton({required this.onPressed});

  @override
  State<_RefreshButton> createState() => _RefreshButtonState();
}

class _RefreshButtonState extends State<_RefreshButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  void _handleRefresh() {
    _spinController.forward(from: 0).then((_) {
      _spinController.value = 0;
    });
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;

    return Container(
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: 0.1),
        borderRadius: AppStyles.borderRadiusSmall,
      ),
      child: IconButton(
        icon: RotationTransition(
          turns: _spinController,
          child: Icon(Icons.refresh_rounded, color: colors.accent, size: 20),
        ),
        onPressed: _handleRefresh,
        tooltip: '刷新歌单',
        padding: const EdgeInsets.all(AppStyles.spacingS),
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      ),
    );
  }
}
