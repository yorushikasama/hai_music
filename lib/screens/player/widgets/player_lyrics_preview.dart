import 'package:flutter/material.dart';
import 'package:flutter_lyric/lyrics_reader.dart';
import 'package:flutter_lyric/lyrics_reader_model.dart';
import 'package:provider/provider.dart';

import '../../../providers/audio_settings_provider.dart';
import '../../../providers/music_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../utils/logger.dart';

class PlayerLyricsPreview extends StatelessWidget {
  final LyricsReaderModel lyricModel;
  final UINetease lyricUI;
  final String? currentLyricsLrc;
  final String? currentLyricsTrans;

  const PlayerLyricsPreview({
    required this.lyricModel,
    required this.lyricUI,
    this.currentLyricsLrc,
    this.currentLyricsTrans,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;

    return Consumer2<MusicProvider, AudioSettingsProvider>(
      builder: (context, musicProvider, audioSettings, child) {
        LyricsReaderModel? displayModel = lyricModel;
        if (currentLyricsLrc != null && currentLyricsLrc!.isNotEmpty) {
          try {
            final builder = LyricsModelBuilder.create().bindLyricToMain(currentLyricsLrc!);
            if (audioSettings.showLyricsTranslation &&
                currentLyricsTrans != null &&
                currentLyricsTrans!.isNotEmpty) {
              builder.bindLyricToExt(currentLyricsTrans!);
            }
            displayModel = builder.getModel();
          } catch (e) {
            Logger.warning('解析翻译歌词失败: $e', 'PlayerScreen');
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

        return StreamBuilder<Duration>(
          stream: musicProvider.positionStream,
          initialData: musicProvider.currentPosition,
          builder: (context, positionSnapshot) {
            final position = positionSnapshot.data ?? Duration.zero;
            return Container(
              height: 280,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: LyricsReader(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                model: displayModel,
                position: position.inMilliseconds,
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
      },
    );
  }
}
