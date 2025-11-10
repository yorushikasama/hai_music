import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../utils/logger.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_lyric/lyrics_reader.dart';
import '../providers/music_provider.dart';
import '../services/music_api_service.dart';
import '../services/lyrics_service.dart';
import '../services/download_service.dart';
import '../services/download_manager.dart';
import '../models/song.dart';
import '../models/play_mode.dart';
import '../widgets/audio_quality_selector.dart';
import '../widgets/draggable_window_area.dart';
import '../screens/download_progress_screen.dart';
import '../utils/platform_utils.dart';


class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with SingleTickerProviderStateMixin {
  final _apiService = MusicApiService();
  final _downloadService = DownloadService();
  late AnimationController _rotationController;
  String? _currentSongId; // 追踪当前歌曲 ID

  // 自定义歌词UI样式
  final lyricUI = UINetease(
    defaultSize: 16,
    defaultExtSize: 20,
    otherMainSize: 14,
    bias: 0.5,
    lineGap: 20,
    inlineGap: 10,
    lyricAlign: LyricAlign.CENTER,
    highlightDirection: HighlightDirection.LTR,
  );

  var lyricModel = LyricsModelBuilder.create()
      .bindLyricToMain('[00:00.00]加载中...\n[00:01.00] \n[00:02.00] ')
      .getModel();

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
    // 延迟加载歌词，确保 MusicProvider 已经更新
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLyrics();
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  void _loadLyrics() async {
    final musicProvider = Provider.of<MusicProvider>(context, listen: false);
    final song = musicProvider.currentSong;
    if (song == null) return;

    // 如果歌曲没有变化，不重复加载
    if (song.id == _currentSongId) {
      return;
    }

    // 更新当前歌曲 ID
    _currentSongId = song.id;

    try {
      String? lyrics;
      // 1) 优先使用 Song 对象中的歌词（如从“我喜欢”映射而来）
      if (song.lyricsLrc != null && song.lyricsLrc!.isNotEmpty) {
        lyrics = song.lyricsLrc;
        Logger.debug('✅ 使用对象存储的歌词: ${song.title}');
      }
      // 2) 检查是否有本地下载的歌词文件
      if (lyrics == null || lyrics.isEmpty) {
        final downloaded = await _downloadService.getDownloadedSongs();
        final downloadedSong = downloaded.where((d) => d.id == song.id).firstOrNull;
        if (downloadedSong?.localLyricsPath != null) {
          try {
            final lyricsFile = File(downloadedSong!.localLyricsPath!);
            if (await lyricsFile.exists()) {
              lyrics = await lyricsFile.readAsString();
              Logger.debug('✅ 使用本地下载的歌词: ${song.title}');
            }
          } catch (e) {
            Logger.warning('读取本地歌词失败: $e', 'PlayerScreen');
          }
        }
      }
      // 3) 其次从数据库读取歌词
      if (lyrics == null || lyrics.isEmpty) {
        lyrics = await LyricsService().getLyrics(song.id);
        if (lyrics != null && lyrics.isNotEmpty) {
          Logger.debug('✅ 从数据库读取歌词: ${song.title}');
        }
      }
      // 4) 最后回退到 API，并把结果写回数据库
      if (lyrics == null || lyrics.isEmpty) {
        Logger.debug('⚠️ 无本地歌词，使用API获取: ${song.title}');
        lyrics = await _apiService.getLyrics(songId: song.id);
        if (lyrics != null && lyrics.isNotEmpty) {
          // 🔧 优化:移除不必要的 ! 操作符
          // 异步写回数据库，失败忽略
          LyricsService().saveLyrics(
            songId: song.id,
            lyrics: lyrics,
            title: song.title,
            artist: song.artist,
          );
        }
      }
      
      if (mounted && lyrics != null && lyrics.isNotEmpty) {
        setState(() {
          // 使用 flutter_lyric 解析歌词
          try {
            lyricModel = LyricsModelBuilder.create()
                .bindLyricToMain(lyrics!)
                .getModel();
          } catch (e) {
            // 歌词解析失败，使用默认歌词
            lyricModel = LyricsModelBuilder.create()
                .bindLyricToMain('[00:00.00]暂无歌词\n[00:01.00] \n[00:02.00] ')
                .getModel();
          }
        });
      } else {
        // 没有歌词，使用默认
        if (mounted) {
          setState(() {
            lyricModel = LyricsModelBuilder.create()
                .bindLyricToMain('[00:00.00]暂无歌词\n[00:01.00] \n[00:02.00] ')
                .getModel();
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          lyricModel = LyricsModelBuilder.create()
              .bindLyricToMain('[00:00.00]暂无歌词\n[00:01.00] \n[00:02.00] ')
              .getModel();
        });
      }
    }
  }

  IconData _getPlayModeIcon(PlayMode mode) {
    switch (mode) {
      case PlayMode.sequence:
        return Icons.repeat;
      case PlayMode.single:
        return Icons.repeat_one;
      case PlayMode.shuffle:
        return Icons.shuffle;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        body: Consumer<MusicProvider>(
          builder: (context, musicProvider, child) {
            final song = musicProvider.currentSong;
            
            // 检查歌曲是否变化，如果变化则重新加载歌词
            if (song != null && song.id != _currentSongId) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _loadLyrics();
              });
            }
            
            if (song == null) {
              return const Center(
                child: Text(
                  '没有正在播放的歌曲',
                  style: TextStyle(color: Colors.white),
                ),
              );
            }

            // 控制旋转动画
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
                // 背景封面（铺满并模糊）- 优先使用R2封面
                CachedNetworkImage(
                  imageUrl: song.r2CoverUrl ?? song.coverUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF2C2C2E),
                          const Color(0xFF1C1C1E),
                          Colors.black,
                        ],
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF2C2C2E),
                          const Color(0xFF1C1C1E),
                          Colors.black,
                        ],
                      ),
                    ),
                  ),
                ),
                // 模糊和暗化效果
                // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.5),
                  ),
                ),
                // 内容
                SafeArea(
                  child: Column(
                    children: [
                      _buildAppBar(context),
                      Expanded(
                        child: Center(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(height: 40),
                                _buildSongInfo(song.title, song.artist),
                                const SizedBox(height: 32),
                                _buildLyricsPreview(),
                                const SizedBox(height: 60),
                              ],
                            ),
                          ),
                        ),
                      ),
                      _buildControlPanel(context, musicProvider),
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

  Widget _buildAppBar(BuildContext context) {
    final isDesktop = PlatformUtils.isDesktop;
    final isAndroid = PlatformUtils.isAndroid;

    return Stack(
      children: [
        // 桌面端拖动区域
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
        // AppBar 内容
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  icon: const Icon(Icons.expand_more, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              // Android 端显示"更多"按钮
              if (isAndroid)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.more_horiz, color: Colors.white, size: 24),
                    onPressed: () {
                      _showMoreMenu(context);
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // 显示更多菜单
  void _showMoreMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Consumer<MusicProvider>(
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
                // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
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
                    musicProvider.audioQuality.label,
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
                // 定时关闭
                ListTile(
                  leading: const Icon(Icons.timer_outlined, color: Colors.white),
                  title: const Text(
                    '定时关闭',
                    style: TextStyle(color: Colors.white),
                  ),
                  trailing: musicProvider.sleepTimer.isActive
                      ? Text(
                          musicProvider.sleepTimer.formatRemainingTime(),
                          style: TextStyle(color: Colors.orange.withValues(alpha: 0.8)),
                        )
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    _showSleepTimerDialog(context, musicProvider);
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
                    _showPlaylistDialog(context, musicProvider);
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
                    final song = musicProvider.currentSong;
                    if (song != null) {
                      final manager = DownloadManager();
                      await manager.init();
                      final success = await manager.addDownload(song);
                      
                      if (!mounted) return;
                      
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
      ),
    );
  }

  // 显示定时关闭对话框
  void _showSleepTimerDialog(BuildContext context, MusicProvider musicProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖动指示器
            // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
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
            // 定时选项
            _buildTimerOption(context, musicProvider, '15分钟', const Duration(minutes: 15)),
            _buildTimerOption(context, musicProvider, '30分钟', const Duration(minutes: 30)),
            _buildTimerOption(context, musicProvider, '45分钟', const Duration(minutes: 45)),
            _buildTimerOption(context, musicProvider, '60分钟', const Duration(minutes: 60)),
            _buildTimerOption(context, musicProvider, '90分钟', const Duration(minutes: 90)),
            // 取消定时
            if (musicProvider.sleepTimer.isActive)
              ListTile(
                leading: const Icon(Icons.cancel_outlined, color: Colors.red),
                title: const Text(
                  '取消定时',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  musicProvider.sleepTimer.cancel();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('已取消定时关闭'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerOption(
    BuildContext context,
    MusicProvider musicProvider,
    String label,
    Duration duration,
  ) {
    return ListTile(
      leading: const Icon(Icons.timer_outlined, color: Colors.white),
      title: Text(
        label,
        style: const TextStyle(color: Colors.white),
      ),
      onTap: () {
        musicProvider.sleepTimer.setTimer(duration, () {
          // 时间到，暂停播放
          musicProvider.pause();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('定时关闭已触发，已暂停播放'),
              duration: Duration(seconds: 3),
            ),
          );
        });
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已设置定时关闭：$label'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
    );
  }

  // 显示播放列表对话框
  void _showPlaylistDialog(BuildContext context, MusicProvider musicProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
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
              // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
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
                      // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
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
                        // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
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
      ),
    );
  }

  Widget _buildSongInfo(String title, String artist) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
          // 点击歌手名字返回主页并搜索该歌手
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
                  color: Colors.white.withValues(alpha: 0.6),
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

  Widget _buildLyricsPreview() {
    return Consumer<MusicProvider>(
      builder: (context, musicProvider, child) {
        // 如果歌词模型为空或没有歌词行，显示空状态
        // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
        if (lyricModel.lyrics.isEmpty) {
          return Container(
            height: 280,
            alignment: Alignment.center,
            child: Text(
              '暂无歌词',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
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
            model: lyricModel,
            position: musicProvider.currentPosition.inMilliseconds,
            lyricUi: lyricUI,
            playing: musicProvider.isPlaying,
            size: const Size(double.infinity, 280),
            emptyBuilder: () => Center(
              child: Text(
                '暂无歌词',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 14,
                ),
              ),
            ),
            selectLineBuilder: (progress, confirm) {
              return Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.play_arrow, color: Colors.white),
                    onPressed: () {
                      confirm.call();
                      musicProvider.seekTo(Duration(milliseconds: progress));
                    },
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
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


  Widget _buildControlPanel(BuildContext context, MusicProvider musicProvider) {
    final isAndroid = PlatformUtils.isAndroid;
    
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isAndroid ? 16 : 20,
        vertical: isAndroid ? 12 : 20,
      ),
      padding: EdgeInsets.all(isAndroid ? 16 : 20),
      // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(isAndroid ? 20 : 24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isAndroid ? 20 : 24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 进度条
              _buildProgressBar(musicProvider),
              SizedBox(height: isAndroid ? 16 : 20),
              // 控制按钮
              isAndroid 
                  ? _buildAndroidControls(musicProvider)
                  : _buildDesktopControls(musicProvider),
            ],
          ),
        ),
      ),
    );
  }

  // 进度条组件
  Widget _buildProgressBar(MusicProvider musicProvider) {
    return Column(
      children: [
        SliderTheme(
          // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
            thumbColor: Colors.white,
            overlayColor: Colors.white.withValues(alpha: 0.2),
          ),
          child: Slider(
            value: () {
              if (musicProvider.totalDuration.inSeconds <= 0) return 0.0;
              final value = musicProvider.currentPosition.inSeconds /
                  musicProvider.totalDuration.inSeconds;
              if (value.isNaN || value.isInfinite) return 0.0;
              return value.clamp(0.0, 1.0);
            }(),
            onChanged: (value) {
              if (musicProvider.totalDuration.inSeconds > 0) {
                final position = Duration(
                  seconds: (value * musicProvider.totalDuration.inSeconds).round(),
                );
                musicProvider.seekTo(position);
              }
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
            children: [
              Text(
                musicProvider.formatDuration(musicProvider.currentPosition),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              Text(
                musicProvider.formatDuration(musicProvider.totalDuration),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Android 端控制按钮 - 简化布局
  Widget _buildAndroidControls(MusicProvider musicProvider) {
    final song = musicProvider.currentSong;
    
    return Column(
      children: [
        // 播放控制行
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // 播放模式
            _buildSimpleButton(
              icon: _getPlayModeIcon(musicProvider.playMode),
              size: 28,
              opacity: musicProvider.playMode == PlayMode.sequence ? 0.5 : 1.0,
              onPressed: () => musicProvider.togglePlayMode(),
            ),
            // 上一曲
            _buildSimpleButton(
              icon: Icons.skip_previous_rounded,
              size: 36,
              onPressed: () => musicProvider.playPrevious(),
            ),
            // 播放/暂停
            _buildPlayButton(musicProvider),
            // 下一曲
            _buildSimpleButton(
              icon: Icons.skip_next_rounded,
              size: 36,
              onPressed: () => musicProvider.playNext(),
            ),
            // 收藏按钮
            if (song != null)
              musicProvider.isFavoriteOperationInProgress(song.id)
                  ? SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                          ),
                        ),
                      ),
                    )
                  : _buildSimpleButton(
                      icon: musicProvider.isFavorite(song.id)
                          ? Icons.favorite
                          : Icons.favorite_border,
                      size: 28,
                      color: musicProvider.isFavorite(song.id)
                          ? Colors.red
                          : null,
                      onPressed: () async {
                        await musicProvider.toggleFavorite(song.id);
                      },
                    )
            else
              const SizedBox(width: 44), // 占位
          ],
        ),
      ],
    );
  }

  // 桌面端控制按钮 - 单行布局
  Widget _buildDesktopControls(MusicProvider musicProvider) {
    final song = musicProvider.currentSong;
    
    return Row(
      children: [
        // 左侧按钮组
        Expanded(
          child: Row(
            children: [
              // 播放模式
              _buildSimpleButton(
                icon: _getPlayModeIcon(musicProvider.playMode),
                size: 24,
                opacity: musicProvider.playMode == PlayMode.sequence ? 0.5 : 1.0,
                onPressed: () => musicProvider.togglePlayMode(),
              ),
            ],
          ),
        ),
        // 中间播放控制组（绝对居中）
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 上一首
            _buildSimpleButton(
              icon: Icons.skip_previous_rounded,
              size: 36,
              onPressed: () => musicProvider.playPrevious(),
            ),
            const SizedBox(width: 16),
            // 播放/暂停
            _buildPlayButton(musicProvider),
            const SizedBox(width: 16),
            // 下一首
            _buildSimpleButton(
              icon: Icons.skip_next_rounded,
              size: 36,
              onPressed: () => musicProvider.playNext(),
            ),
          ],
        ),
        // 右侧按钮组
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // 收藏按钮
              if (song != null)
                musicProvider.isFavoriteOperationInProgress(song.id)
                    ? SizedBox(
                        width: 40,
                        height: 40,
                        child: Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                            ),
                          ),
                        ),
                      )
                    : _buildSimpleButton(
                        icon: musicProvider.isFavorite(song.id)
                            ? Icons.favorite
                            : Icons.favorite_border,
                        size: 24,
                        color: musicProvider.isFavorite(song.id)
                            ? Colors.red
                            : null,
                        onPressed: () async {
                          await musicProvider.toggleFavorite(song.id);
                        },
                      ),
              const SizedBox(width: 16),
              // 下载按钮（仅 Windows 显示）
              if (Platform.isWindows && song != null)
                _buildDownloadButton(song, musicProvider),
              if (Platform.isWindows && song != null)
                const SizedBox(width: 16),
              // 音量控制
              _buildVolumeControl(musicProvider),
              const SizedBox(width: 16),
              // 音质选择
              _buildSimpleButton(
                icon: Icons.high_quality_rounded,
                size: 24,
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true,
                    builder: (context) => const AudioQualitySelector(),
                  );
                },
              ),
              const SizedBox(width: 16),
              // 定时关闭
              _buildSimpleButton(
                icon: Icons.timer_outlined,
                size: 24,
                color: musicProvider.sleepTimer.isActive ? Colors.orange : null,
                onPressed: () => _showSleepTimerDialog(context, musicProvider),
              ),
              const SizedBox(width: 16),
              // 播放列表
              _buildSimpleButton(
                icon: Icons.queue_music_rounded,
                size: 24,
                onPressed: () => _showPlaylistDialog(context, musicProvider),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 简单按钮组件
  Widget _buildSimpleButton({
    required IconData icon,
    required double size,
    required VoidCallback onPressed,
    double opacity = 1.0,
    Color? color,
  }) {
    // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
    return IconButton(
      icon: Icon(
        icon,
        color: color ?? Colors.white.withValues(alpha: opacity * 0.9),
      ),
      iconSize: size,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(
        minWidth: size + 16,
        minHeight: size + 16,
      ),
      onPressed: onPressed,
    );
  }

  // 播放按钮
  Widget _buildPlayButton(MusicProvider musicProvider) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 1,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => musicProvider.togglePlayPause(),
          borderRadius: BorderRadius.circular(32),
          child: Icon(
            musicProvider.isPlaying 
                ? Icons.pause_rounded 
                : Icons.play_arrow_rounded,
            color: Colors.black87,
            size: 36,
          ),
        ),
      ),
    );
  }

  Widget _buildVolumeControl(MusicProvider musicProvider) {
    IconData volumeIcon;
    if (musicProvider.volume == 0) {
      volumeIcon = Icons.volume_off_rounded;
    } else if (musicProvider.volume < 0.5) {
      volumeIcon = Icons.volume_down_rounded;
    } else {
      volumeIcon = Icons.volume_up_rounded;
    }

    return Builder(
      // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
      builder: (context) => Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.05),
        ),
        child: IconButton(
          padding: EdgeInsets.zero,
          icon: Icon(
            volumeIcon,
            color: Colors.white.withValues(alpha: 0.9),
          ),
          iconSize: 24,
          onPressed: () {
            _showVolumeControlDialog(context, musicProvider);
          },
        ),
      ),
    );
  }

  void _showVolumeControlDialog(BuildContext context, MusicProvider musicProvider) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final Offset buttonPosition = button.localToGlobal(Offset.zero, ancestor: overlay);
    final Size buttonSize = button.size;

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      builder: (context) => Consumer<MusicProvider>(
        builder: (context, musicProvider, child) {
          return Stack(
            children: [
              Positioned(
                left: buttonPosition.dx + buttonSize.width / 2 - 35, // 🔧 修复:调整居中位置
                bottom: overlay.size.height - buttonPosition.dy + 10,
                child: Material(
                  color: Colors.transparent,
                  // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
                  child: Container(
                    width: 70, // 🔧 修复:增加宽度防止文本换行 (60 -> 70)
                    height: 240,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 音量图标（可点击静音/恢复）
                        InkWell(
                          onTap: () {
                            if (musicProvider.volume > 0) {
                              musicProvider.setVolume(0);
                            } else {
                              musicProvider.setVolume(0.5);
                            }
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              musicProvider.volume == 0
                                  ? Icons.volume_off_rounded
                                  : musicProvider.volume < 0.5
                                      ? Icons.volume_down_rounded
                                      : Icons.volume_up_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // 垂直音量滑块
                        Expanded(
                          child: RotatedBox(
                            quarterTurns: 3,
                            child: SliderTheme(
                              // 🔧 优化:使用 withValues() 替代已弃用的 withOpacity()
                              data: SliderThemeData(
                                trackHeight: 6,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                                activeTrackColor: Colors.white,
                                inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
                                thumbColor: Colors.white,
                                overlayColor: Colors.white.withValues(alpha: 0.2),
                              ),
                              child: Slider(
                                value: musicProvider.volume,
                                onChanged: (value) {
                                  musicProvider.setVolume(value);
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // 音量百分比
                        // 🔧 修复:设置固定宽度防止100%时换行
                        Container(
                          width: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${(musicProvider.volume * 100).round()}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // 构建下载按钮
  Widget _buildDownloadButton(Song song, MusicProvider musicProvider) {
    return FutureBuilder<bool>(
      future: _downloadService.isDownloaded(song.id),
      builder: (context, snapshot) {
        final isDownloaded = snapshot.data ?? false;
        
        return _buildSimpleButton(
          icon: isDownloaded ? Icons.download_done : Icons.download_outlined,
          size: 24,
          color: isDownloaded ? Colors.green : null,
          opacity: isDownloaded ? 0.5 : 1.0,
          onPressed: () async {
            // 如果已下载，则不执行任何操作
            if (isDownloaded) return;
            
            final manager = DownloadManager();
            await manager.init();
            final success = await manager.addDownload(song);
            
            if (!mounted) return;
            
            if (success) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.download, color: Colors.white, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '已添加到下载队列：${song.title}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: Colors.blue.shade700,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.all(16),
                  action: SnackBarAction(
                    label: '查看',
                    textColor: Colors.white,
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
                  content: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.white, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '《${song.title}》已在下载列表中',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: Colors.orange.shade700,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.all(16),
                ),
              );
            }
          },
        );
      },
    );
  }

}
