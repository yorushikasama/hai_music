import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lyric/lyrics_reader.dart';
import 'package:flutter_lyric/lyrics_reader_model.dart';
import 'package:provider/provider.dart';

import '../models/song.dart';
import '../providers/audio_settings_provider.dart';
import '../providers/music_provider.dart';
import '../providers/theme_provider.dart';
import '../repositories/music_repository.dart';
import '../services/download/download_service.dart';
import '../theme/app_styles.dart';
import '../utils/logger.dart';
import 'player/player_controls.dart';
import 'player/widgets/player_app_bar.dart';
import 'player/widgets/player_cover_background.dart';
import 'player/widgets/player_lyrics_preview.dart';
import 'player/widgets/player_sleep_timer_indicator.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with SingleTickerProviderStateMixin {
  static const String _defaultLyrics = '[00:00.00]暂无歌词\n[00:01.00] \n[00:02.00] ';
  static const String _loadingLyrics = '[00:00.00]加载中...\n[00:01.00] \n[00:02.00] ';

  static final _repository = MusicRepository();
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
      unawaited(_loadLyrics().catchError((Object e) {
        Logger.error('加载歌词失败', e, null, 'PlayerScreen');
      }));
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
      final result = await _repository.loadLyrics(song);

      if (!mounted) return;

      if (result != null && result.hasLyrics) {
        setState(() {
          try {
            _currentLyricsLrc = result.lrc;
            _currentLyricsTrans = result.trans;
            final builder = LyricsModelBuilder.create().bindLyricToMain(result.lrc!);
            final showTranslation =
                Provider.of<AudioSettingsProvider>(context, listen: false)
                    .showLyricsTranslation;
            if (showTranslation && result.hasTranslation) {
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
        body: _PlayerScreenBody(
          rotationController: _rotationController,
          currentSongId: _currentSongId,
          currentLyricsLrc: _currentLyricsLrc,
          currentLyricsTrans: _currentLyricsTrans,
          lyricModel: lyricModel,
          lyricUI: lyricUI,
          onLoadLyrics: _loadLyrics,
          onCurrentSongIdChanged: (id) => _currentSongId = id,
        ),
      ),
    );
  }
}

class _PlayerScreenBody extends StatelessWidget {
  final AnimationController rotationController;
  final String? currentSongId;
  final String? currentLyricsLrc;
  final String? currentLyricsTrans;
  final LyricsReaderModel lyricModel;
  final UINetease lyricUI;
  final Future<void> Function() onLoadLyrics;
  final void Function(String? id) onCurrentSongIdChanged;

  const _PlayerScreenBody({
    required this.rotationController,
    required this.currentSongId,
    required this.currentLyricsLrc,
    required this.currentLyricsTrans,
    required this.lyricModel,
    required this.lyricUI,
    required this.onLoadLyrics,
    required this.onCurrentSongIdChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;

    return Selector<MusicProvider, ({Song? song, bool isPlaying})>(
      selector: (_, provider) => (
        song: provider.currentSong,
        isPlaying: provider.isPlaying,
      ),
      builder: (context, data, child) {
        final song = data.song;
        final isPlaying = data.isPlaying;

        if (song != null && song.id != currentSongId) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onCurrentSongIdChanged(song.id);
            unawaited(onLoadLyrics());
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

        if (isPlaying) {
          if (!rotationController.isAnimating) {
            rotationController.repeat();
          }
        } else {
          rotationController.stop();
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            PlayerCoverBackground(song: song, colors: colors),
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
              child: Container(
                color: colors.background.withValues(alpha: 0.5),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  PlayerAppBar(colors: colors, onLoadLyrics: onLoadLyrics),
                  PlayerSleepTimerIndicator(colors: colors),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: AppStyles.spacingXXXL),
                            _buildSongInfo(context, song.title, song.artist, colors),
                            const SizedBox(height: AppStyles.spacingXXXL),
                            PlayerLyricsPreview(
                              lyricModel: lyricModel,
                              lyricUI: lyricUI,
                              currentLyricsLrc: currentLyricsLrc,
                              currentLyricsTrans: currentLyricsTrans,
                            ),
                            const SizedBox(height: 60),
                          ],
                        ),
                      ),
                    ),
                  ),
                  PlayerControlPanel(
                    downloadService: DownloadService(),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSongInfo(BuildContext context, String title, String artist, ThemeColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppStyles.spacingXXXL),
      child: Column(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppStyles.spacingS),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                Navigator.pop(context, {'action': 'search', 'query': artist});
              },
              child: Text(
                artist,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colors.textSecondary,
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
}
