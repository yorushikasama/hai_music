import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lyric/lyrics_reader.dart';
import 'package:flutter_lyric/lyrics_reader_model.dart';
import 'package:provider/provider.dart';

import '../providers/audio_settings_provider.dart';
import '../providers/music_provider.dart';
import '../providers/sleep_timer_provider.dart';
import '../providers/theme_provider.dart';
import '../services/download_service.dart';
import '../services/lyrics_loading_service.dart';
import '../theme/app_styles.dart';
import '../utils/logger.dart';
import '../utils/platform_utils.dart';
import '../widgets/draggable_window_area.dart';
import 'player/player_bottom_sheets.dart';
import 'player/player_controls.dart';


class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with SingleTickerProviderStateMixin {
  static const String _defaultLyrics = '[00:00.00]暂无歌词\n[00:01.00] \n[00:02.00] ';
  static const String _loadingLyrics = '[00:00.00]加载中...\n[00:01.00] \n[00:02.00] ';

  final _lyricsLoadingService = LyricsLoadingService();
  late AnimationController _rotationController;
  String? _currentSongId;

  String? _currentLyricsLrc;
  String? _currentLyricsTrans;

  final lyricUI = UINetease(
    defaultSize: 16,
    defaultExtSize: 20,
    otherMainSize: 14,
    lineGap: 20,
    inlineGap: 10,
  );

  LyricsReaderModel lyricModel = LyricsModelBuilder.create()
      .bindLyricToMain(_loadingLyrics)
      .getModel();

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadLyrics());
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  Future<void> _loadLyrics() async {
    final musicProvider = Provider.of<MusicProvider>(context, listen: false);
    final song = musicProvider.currentSong;
    if (song == null) return;

    if (song.id == _currentSongId) return;

    _currentSongId = song.id;

    try {
      final result = await _lyricsLoadingService.loadLyrics(song);

      if (!mounted) return;

      if (result != null && result.hasLyrics) {
        setState(() {
          try {
            _currentLyricsLrc = result.lrc;
            _currentLyricsTrans = result.trans;
            final builder = LyricsModelBuilder.create().bindLyricToMain(result.lrc!);
            if (Provider.of<AudioSettingsProvider>(context, listen: false).showLyricsTranslation && result.hasTranslation) {
              builder.bindLyricToExt(result.trans!);
            }
            lyricModel = builder.getModel();
          } catch (e) {
            lyricModel = LyricsModelBuilder.create()
                .bindLyricToMain(_defaultLyrics)
                .getModel();
            _currentLyricsLrc = null;
            _currentLyricsTrans = null;
          }
        });
      } else {
        setState(() {
          lyricModel = LyricsModelBuilder.create()
              .bindLyricToMain(_defaultLyrics)
              .getModel();
          _currentLyricsLrc = null;
          _currentLyricsTrans = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          lyricModel = LyricsModelBuilder.create()
              .bindLyricToMain(_defaultLyrics)
              .getModel();
          _currentLyricsLrc = null;
          _currentLyricsTrans = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;
    final systemUiStyle = colors.isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUiStyle,
      child: Scaffold(
        backgroundColor: colors.background,
        extendBodyBehindAppBar: true,
        body: Consumer<MusicProvider>(
          builder: (context, musicProvider, child) {
            final song = musicProvider.currentSong;

            if (song != null && song.id != _currentSongId) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                unawaited(_loadLyrics());
              });
            }

            if (song == null) {
              return Center(
                child: Text(
                  '没有正在播放的歌曲',
                  style: TextStyle(color: colors.textSecondary),
                ),
              );
            }

            if (musicProvider.isPlaying) {
              if (!_rotationController.isAnimating) {
                _rotationController.repeat();
              }
            } else {
              _rotationController.stop();
            }

            return Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: song.r2CoverUrl ?? song.coverUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    decoration: BoxDecoration(
                      gradient: colors.backgroundGradient ?? LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [colors.surface, colors.background],
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    decoration: BoxDecoration(
                      gradient: colors.backgroundGradient ?? LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [colors.surface, colors.background],
                      ),
                    ),
                  ),
                ),
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                  child: Container(
                    color: colors.background.withValues(alpha: 0.5),
                  ),
                ),
                SafeArea(
                  child: Column(
                    children: [
                      _buildAppBar(context, colors),
                      _buildSleepTimerIndicator(context, musicProvider, colors),
                      Expanded(
                        child: Center(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(height: 40),
                                _buildSongInfo(song.title, song.artist, colors),
                                const SizedBox(height: 32),
                                _buildLyricsPreview(colors),
                                const SizedBox(height: 60),
                              ],
                            ),
                          ),
                        ),
                      ),
                      PlayerControlPanel(
                        musicProvider: musicProvider,
                        downloadService: DownloadService(),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, ThemeColors colors) {
    final isDesktop = PlatformUtils.isDesktop;
    final isAndroid = PlatformUtils.isAndroid;

    return Stack(
      children: [
        if (isDesktop)
          const Positioned(
            top: 0,
            left: 60,
            right: 60,
            height: 56,
            child: DraggableWindowArea(
              child: SizedBox.expand(),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: colors.textPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  icon: Icon(Icons.expand_more, color: colors.textPrimary, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Consumer<AudioSettingsProvider>(
                builder: (context, audioSettings, child) {
                  return Container(
                    decoration: BoxDecoration(
                      color: colors.textPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: IconButton(
                      icon: Icon(
                        audioSettings.showLyricsTranslation
                            ? Icons.translate_rounded
                            : Icons.translate_outlined,
                        color: audioSettings.showLyricsTranslation
                            ? colors.accent
                            : colors.textPrimary,
                        size: 24,
                      ),
                      onPressed: () {
                        audioSettings.setShowLyricsTranslation(
                          !audioSettings.showLyricsTranslation,
                        );
                        _currentSongId = null;
                        unawaited(_loadLyrics());
                      },
                    ),
                  );
                },
              ),
              if (isAndroid)
                Container(
                  decoration: BoxDecoration(
                    color: colors.textPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.more_horiz, color: colors.textPrimary, size: 24),
                    onPressed: () => showPlayerMoreMenu(context),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSleepTimerIndicator(BuildContext context, MusicProvider musicProvider, ThemeColors colors) {
    final sleepTimerProvider = Provider.of<SleepTimerProvider>(context);
    if (!sleepTimerProvider.sleepTimer.isActive) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: GestureDetector(
        onTap: () => showSleepTimerDialog(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: colors.warning.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colors.warning.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.timer,
                size: 18,
                color: colors.warning,
              ),
              const SizedBox(width: 8),
              Text(
                '定时关闭: ${sleepTimerProvider.sleepTimer.formattedRemainingTime}',
                style: TextStyle(
                  color: colors.warning,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: colors.warning.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSongInfo(String title, String artist, ThemeColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
              letterSpacing: 0.3,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                Navigator.pop(context, {'action': 'search', 'query': artist});
              },
              child: Text(
                artist,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: colors.textSecondary,
                  letterSpacing: 0.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLyricsPreview(ThemeColors colors) {
    return Consumer2<MusicProvider, AudioSettingsProvider>(
      builder: (context, musicProvider, audioSettings, child) {
        LyricsReaderModel? displayModel = lyricModel;
        if (_currentLyricsLrc != null && _currentLyricsLrc!.isNotEmpty) {
          try {
            final builder = LyricsModelBuilder.create().bindLyricToMain(_currentLyricsLrc!);
            if (audioSettings.showLyricsTranslation &&
                _currentLyricsTrans != null &&
                _currentLyricsTrans!.isNotEmpty) {
              builder.bindLyricToExt(_currentLyricsTrans!);
            }
            displayModel = builder.getModel();
          } catch (e) {
            Logger.debug('歌词模型构建失败', 'PlayerScreen');
          }
        }

        if (displayModel == null || displayModel.lyrics.isEmpty) {
          return Container(
            height: 280,
            alignment: Alignment.center,
            child: Text(
              '暂无歌词',
              style: TextStyle(
                color: colors.textSecondary.withValues(alpha: 0.3),
                fontSize: 14,
              ),
            ),
          );
        }

        return Container(
          height: 280,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: LyricsReader(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            model: displayModel,
            position: musicProvider.currentPosition.inMilliseconds,
            lyricUi: lyricUI,
            playing: musicProvider.isPlaying,
            size: const Size(double.infinity, 280),
            emptyBuilder: () => Center(
              child: Text(
                '暂无歌词',
                style: TextStyle(
                  color: colors.textSecondary.withValues(alpha: 0.3),
                  fontSize: 14,
                ),
              ),
            ),
            selectLineBuilder: (progress, confirm) {
              return Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.play_arrow, color: colors.textPrimary),
                    onPressed: () {
                      confirm.call();
                      musicProvider.seekTo(Duration(milliseconds: progress));
                    },
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: colors.textSecondary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      height: 2,
                      width: double.infinity,
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }


}
