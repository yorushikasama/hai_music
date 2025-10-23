import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/music_provider.dart';
import '../services/music_api_service.dart';
import '../models/play_mode.dart';
import '../widgets/audio_quality_selector.dart';
import 'dart:ui';
import 'package:flutter_lyric/lyrics_reader.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart' if (dart.library.html) '';


class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with SingleTickerProviderStateMixin {
  final _apiService = MusicApiService();
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
    _loadLyrics();
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

    // 更新当前歌曲 ID
    _currentSongId = song.id;

    try {
      final lyrics = await _apiService.getLyrics(songId: song.id);
      if (mounted && lyrics != null && lyrics.isNotEmpty) {
        setState(() {
          // 使用 flutter_lyric 解析歌词
          try {
            lyricModel = LyricsModelBuilder.create()
                .bindLyricToMain(lyrics)
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
                // 背景封面（铺满并模糊）
                CachedNetworkImage(
                  imageUrl: song.coverUrl,
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
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                  child: Container(
                    color: Colors.black.withOpacity(0.5),
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
    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
    final isAndroid = !kIsWeb && Platform.isAndroid;
    
    return Stack(
      children: [
        // 桌面端拖动区域
        if (isDesktop)
          Positioned(
            top: 0,
            left: 60,
            right: 60,
            height: 56,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (_) {
                try {
                  appWindow.startDragging();
                } catch (e) {
                  // 忽略错误
                }
              },
              child: Container(color: Colors.transparent),
            ),
          ),
        // AppBar 内容
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
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
                    color: Colors.white.withOpacity(0.1),
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
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
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
                    style: TextStyle(color: Colors.white.withOpacity(0.6)),
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
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: 实现定时关闭功能
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
                    style: TextStyle(color: Colors.white.withOpacity(0.6)),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: 显示播放列表
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
          Text(
            artist,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: Colors.white.withOpacity(0.6),
              letterSpacing: 0.2,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildLyricsPreview() {
    return Consumer<MusicProvider>(
      builder: (context, musicProvider, child) {
        // 如果歌词模型为空或没有歌词行，显示空状态
        if (lyricModel.lyrics.isEmpty) {
          return Container(
            height: 280,
            alignment: Alignment.center,
            child: Text(
              '暂无歌词',
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
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
                  color: Colors.white.withOpacity(0.3),
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
                        color: Colors.white.withOpacity(0.3),
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
    final isAndroid = !kIsWeb && Platform.isAndroid;
    
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isAndroid ? 16 : 20,
        vertical: isAndroid ? 12 : 20,
      ),
      padding: EdgeInsets.all(isAndroid ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(isAndroid ? 20 : 24),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
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
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white.withOpacity(0.2),
            thumbColor: Colors.white,
            overlayColor: Colors.white.withOpacity(0.2),
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
            children: [
              Text(
                musicProvider.formatDuration(musicProvider.currentPosition),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
              Text(
                musicProvider.formatDuration(musicProvider.totalDuration),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.6),
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
              _buildSimpleButton(
                icon: musicProvider.isFavorite(song.id)
                    ? Icons.favorite
                    : Icons.favorite_border,
                size: 28,
                color: musicProvider.isFavorite(song.id)
                    ? Colors.red
                    : null,
                onPressed: () => musicProvider.toggleFavorite(song.id),
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
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 播放模式
        _buildSimpleButton(
          icon: _getPlayModeIcon(musicProvider.playMode),
          size: 24,
          opacity: musicProvider.playMode == PlayMode.sequence ? 0.5 : 1.0,
          onPressed: () => musicProvider.togglePlayMode(),
        ),
        const SizedBox(width: 20),
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
        const SizedBox(width: 20),
        // 收藏按钮
        if (song != null)
          _buildSimpleButton(
            icon: musicProvider.isFavorite(song.id)
                ? Icons.favorite
                : Icons.favorite_border,
            size: 24,
            color: musicProvider.isFavorite(song.id)
                ? Colors.red
                : null,
            onPressed: () => musicProvider.toggleFavorite(song.id),
          ),
        const SizedBox(width: 20),
        // 音量控制
        _buildVolumeControl(musicProvider),
        const SizedBox(width: 20),
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
    return IconButton(
      icon: Icon(
        icon,
        color: color ?? Colors.white.withOpacity(opacity * 0.9),
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
            color: Colors.white.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 1,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
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
      builder: (context) => Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.05),
        ),
        child: IconButton(
          padding: EdgeInsets.zero,
          icon: Icon(
            volumeIcon,
            color: Colors.white.withOpacity(0.9),
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
                left: buttonPosition.dx + buttonSize.width / 2 - 30,
                bottom: overlay.size.height - buttonPosition.dy + 10,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: 60,
                    height: 240,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
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
                              data: SliderThemeData(
                                trackHeight: 6,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                                activeTrackColor: Colors.white,
                                inactiveTrackColor: Colors.white.withOpacity(0.2),
                                thumbColor: Colors.white,
                                overlayColor: Colors.white.withOpacity(0.2),
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
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${(musicProvider.volume * 100).round()}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
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
}
