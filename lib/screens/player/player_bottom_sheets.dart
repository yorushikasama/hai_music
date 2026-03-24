import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../providers/music_provider.dart';
import '../../services/download_manager.dart';
import '../../screens/download_progress_screen.dart';
import '../../widgets/audio_quality_selector.dart';

/// 显示播放器的“更多”菜单 bottom sheet
void showPlayerMoreMenu(BuildContext rootContext) {
  showModalBottomSheet(
    context: rootContext,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _MoreMenuSheet(rootContext: rootContext),
  );
}

/// 显示定时关闭对话框
void showSleepTimerDialog(BuildContext context) {
  final musicProvider = Provider.of<MusicProvider>(context, listen: false);
  
  // 如果定时器已激活，显示管理界面
  if (musicProvider.sleepTimer.isActive) {
    _showActiveSleepTimerDialog(context, musicProvider);
    return;
  }
  
  // 否则显示设置界面
  const initialDuration = Duration(minutes: 30);

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      Duration selectedDuration = initialDuration;
      return StatefulBuilder(
        builder: (innerContext, setState) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 拖动指示器
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    '定时关闭',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(
                  height: 180,
                  child: CupertinoTimerPicker(
                    mode: CupertinoTimerPickerMode.hm,
                    initialTimerDuration: selectedDuration,
                    onTimerDurationChanged: (duration) {
                      setState(() {
                        selectedDuration = duration;
                      });
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                        },
                        child: const Text(
                          '取消',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          if (selectedDuration.inSeconds <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('请选择有效的时间'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                            return;
                          }
                          
                          // 启动定时器
                          musicProvider.startSleepTimer(selectedDuration);
                          
                          Navigator.pop(sheetContext);
                          
                          final hours = selectedDuration.inHours;
                          final minutes = selectedDuration.inMinutes.remainder(60);
                          String timeText;
                          if (hours > 0) {
                            timeText = '$hours小时${minutes > 0 ? '$minutes分钟' : ''}';
                          } else {
                            timeText = '$minutes分钟';
                          }
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('定时关闭已启动：$timeText后暂停播放'),
                              duration: const Duration(seconds: 3),
                              action: SnackBarAction(
                                label: '取消',
                                onPressed: () {
                                  musicProvider.cancelSleepTimer();
                                },
                              ),
                            ),
                          );
                        },
                        child: const Text(
                          '开始定时',
                          style: TextStyle(color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      );
    },
  );
}

/// 显示已激活的定时器管理界面
void _showActiveSleepTimerDialog(BuildContext context, MusicProvider musicProvider) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖动指示器
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    '定时关闭已启动',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // 倒计时显示
                  Consumer<MusicProvider>(
                    builder: (context, provider, child) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.5),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              '剩余时间',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              provider.sleepTimer.formattedRemainingTime,
                              style: const TextStyle(
                                color: Colors.orange,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                fontFeatures: [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  // 操作按钮
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            musicProvider.extendSleepTimer(const Duration(minutes: 15));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('已延长15分钟'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add, color: Colors.white),
                          label: const Text(
                            '延长15分钟',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white30),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            musicProvider.cancelSleepTimer();
                            Navigator.pop(sheetContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('定时关闭已取消'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          icon: const Icon(Icons.close),
                          label: const Text('取消定时'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      );
    },
  );
}

/// 显示播放列表 bottom sheet
void showPlaylistDialog(BuildContext context, MusicProvider musicProvider) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => _PlaylistSheet(rootContext: sheetContext, musicProvider: musicProvider),
  );
}

class _MoreMenuSheet extends StatelessWidget {
  final BuildContext rootContext;

  const _MoreMenuSheet({required this.rootContext});

  @override
  Widget build(BuildContext context) {
    return Consumer<MusicProvider>(
      builder: (context, musicProvider, child) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 拖动指示器
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 音质选择
              ListTile(
                leading: const Icon(Icons.high_quality_rounded, color: Colors.white),
                title: const Text(
                  '音质选择',
                  style: TextStyle(color: Colors.white),
                ),
                trailing: Text(
                  musicProvider.audioQuality,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                ),
                onTap: () {
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true,
                    builder: (context) => const AudioQualitySelector(),
                  );
                },
              ),
              // 定时关闭（仅保留 UI，已无业务逻辑）
              ListTile(
                leading: const Icon(Icons.timer_outlined, color: Colors.white),
                title: const Text(
                  '定时关闭',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  // 先关闭当前“更多”面板，再使用外层 context 打开定时关闭面板
                  Navigator.pop(context);
                  showSleepTimerDialog(rootContext);
                },
              ),
              // 播放列表
              ListTile(
                leading: const Icon(Icons.queue_music_rounded, color: Colors.white),
                title: const Text(
                  '播放列表',
                  style: TextStyle(color: Colors.white),
                ),
                trailing: Text(
                  '${musicProvider.playlist.length}首',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                ),
                onTap: () {
                  Navigator.pop(context);
                  showPlaylistDialog(rootContext, musicProvider);
                },
              ),
              SwitchListTile.adaptive(
                secondary: const Icon(Icons.translate_rounded, color: Colors.white),
                title: const Text(
                  '显示歌词翻译',
                  style: TextStyle(color: Colors.white),
                ),
                value: musicProvider.showLyricsTranslation,
                activeTrackColor: Colors.orange.withValues(alpha: 0.5),
                activeThumbColor: Colors.orange,
                onChanged: (value) {
                  musicProvider.setShowLyricsTranslation(value);
                },
              ),
              // 下载歌曲
              ListTile(
                leading: const Icon(Icons.download_outlined, color: Colors.white),
                title: const Text(
                  '下载到本地',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final song = musicProvider.currentPlayingSong ?? musicProvider.currentSong;
                  if (song != null) {
                    final manager = DownloadManager();
                    await manager.init();
                    final success = await manager.addDownload(song);

                    if (!context.mounted) return;

                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('已添加到下载队列：${song.title}'),
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                          action: SnackBarAction(
                            label: '查看',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const DownloadProgressScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('《${song.title}》已在下载列表中'),
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}

class _PlaylistSheet extends StatelessWidget {
  final BuildContext rootContext;
  final MusicProvider musicProvider;

  const _PlaylistSheet({required this.rootContext, required this.musicProvider});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // 拖动指示器
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 标题
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '播放列表 (${musicProvider.playlist.length})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      musicProvider.clearPlaylist();
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('已清空播放列表'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Text(
                      '清空',
                      style: TextStyle(color: Colors.red.withValues(alpha: 0.8)),
                    ),
                  ),
                ],
              ),
            ),
            // 播放列表
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: musicProvider.playlist.length,
                itemBuilder: (context, index) {
                  final song = musicProvider.playlist[index];
                  final isPlaying = musicProvider.currentSong?.id == song.id;

                  return ListTile(
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: CachedNetworkImageProvider(song.r2CoverUrl ?? song.coverUrl),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: isPlaying
                          ? Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.equalizer_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            )
                          : null,
                    ),
                    title: Text(
                      song.title,
                      style: TextStyle(
                        color: isPlaying ? Colors.orange : Colors.white,
                        fontWeight: isPlaying ? FontWeight.w600 : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      song.artist,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () {
                        musicProvider.removeFromPlaylist(index);
                      },
                    ),
                    onTap: () {
                      musicProvider.playSong(song, playlist: musicProvider.playlist);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
