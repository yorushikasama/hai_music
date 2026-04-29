import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/audio_settings_provider.dart';
import '../../../providers/music_provider.dart';
import '../../../services/download/download_service.dart';
import '../../../utils/download_utils.dart';
import '../../../widgets/audio_quality_selector.dart';
import '../player_bottom_sheets.dart';

class PlayerMoreMenuSheet extends StatelessWidget {
  final BuildContext rootContext;

  const PlayerMoreMenuSheet({required this.rootContext, super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<MusicProvider, AudioSettingsProvider>(
      builder: (context, musicProvider, audioSettings, child) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDragHandle(),
              _buildQualityTile(context, audioSettings),
              _buildSleepTimerTile(context),
              _buildPlaylistTile(context, musicProvider),
              _buildTranslationSwitch(audioSettings),
              _buildDownloadTile(context, musicProvider),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDragHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildQualityTile(BuildContext context, AudioSettingsProvider audioSettings) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: audioSettings.audioQuality.gradientColors,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: audioSettings.isQualitySwitching
            ? const Padding(
                padding: EdgeInsets.all(10),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(
                audioSettings.switchResult == QualitySwitchResult.failed
                    ? Icons.error_outline_rounded
                    : audioSettings.audioQuality.icon,
                color: Colors.white,
                size: 20,
              ),
      ),
      title: const Text('音质选择', style: TextStyle(color: Colors.white)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: audioSettings.switchResult == QualitySwitchResult.failed
                    ? [Colors.red.withValues(alpha: 0.3), Colors.red.withValues(alpha: 0.2)]
                    : audioSettings.audioQuality.gradientColors
                        .map((c) => c.withValues(alpha: 0.3))
                        .toList(),
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              audioSettings.switchResult == QualitySwitchResult.failed
                  ? '失败'
                  : audioSettings.audioQualityLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: audioSettings.switchResult == QualitySwitchResult.failed
                    ? Colors.red
                    : audioSettings.audioQuality.color,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            audioSettings.isQualitySwitching
                ? '切换中...'
                : audioSettings.audioQuality.bitrate,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.3), size: 18),
        ],
      ),
      onTap: audioSettings.isQualitySwitching
          ? null
          : () {
              if (audioSettings.switchResult == QualitySwitchResult.failed) {
                audioSettings.clearSwitchError();
              }
              Navigator.pop(context);
              showModalBottomSheet<void>(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (context) => const AudioQualitySelector(),
              );
            },
    );
  }

  Widget _buildSleepTimerTile(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.timer_outlined, color: Colors.white),
      title: const Text('定时关闭', style: TextStyle(color: Colors.white)),
      onTap: () {
        Navigator.pop(context);
        showSleepTimerDialog(rootContext);
      },
    );
  }

  Widget _buildPlaylistTile(BuildContext context, MusicProvider musicProvider) {
    return ListTile(
      leading: const Icon(Icons.queue_music_rounded, color: Colors.white),
      title: const Text('播放列表', style: TextStyle(color: Colors.white)),
      trailing: Text(
        '${musicProvider.playlist.length}首',
        style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
      ),
      onTap: () {
        Navigator.pop(context);
        showPlaylistDialog(rootContext, musicProvider);
      },
    );
  }

  Widget _buildTranslationSwitch(AudioSettingsProvider audioSettings) {
    return SwitchListTile.adaptive(
      secondary: const Icon(Icons.translate_rounded, color: Colors.white),
      title: const Text('显示歌词翻译', style: TextStyle(color: Colors.white)),
      value: audioSettings.showLyricsTranslation,
      activeTrackColor: Colors.orange.withValues(alpha: 0.5),
      activeThumbColor: Colors.orange,
      onChanged: (value) {
        audioSettings.setShowLyricsTranslation(value);
      },
    );
  }

  Widget _buildDownloadTile(BuildContext context, MusicProvider musicProvider) {
    return ListTile(
      leading: const Icon(Icons.download_outlined, color: Colors.white),
      title: const Text('下载到本地', style: TextStyle(color: Colors.white)),
      onTap: () async {
        Navigator.pop(context);
        final song = musicProvider.currentPlayingSong ?? musicProvider.currentSong;
        if (song != null) {
          final result = await DownloadService().addDownload(song);
          DownloadUtils.handleAddDownloadResult(rootContext, result, song.title);
        }
      },
    );
  }
}
