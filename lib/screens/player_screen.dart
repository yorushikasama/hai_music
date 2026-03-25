import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
// import 'package:cached_network_image/cached_network_image';

import '../utils/logger.dart';
import '../providers/music_provider.dart';
import '../models/song.dart';
import '../services/music_api_service.dart';
import '../services/lyrics_service.dart';
import '../services/download_service.dart';
import '../widgets/draggable_window_area.dart';
import '../utils/platform_utils.dart';

// 导入flutter_lyric包的具体文件
import 'package:flutter_lyric/lyrics_reader.dart';
import 'package:flutter_lyric/lyrics_reader_model.dart';
import 'package:flutter_lyric/lyrics_model_builder.dart';
import 'package:flutter_lyric/lyric_ui/lyric_ui.dart';
import 'package:flutter_lyric/lyric_ui/ui_netease.dart';

import 'player/player_bottom_sheets.dart';
import 'player/player_controls.dart';


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

  String? _currentLyricsLrc;
  String? _currentLyricsTrans;

  // 歌词UI配置
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

  // 歌词模型
  late LyricsReaderModel lyricModel;
  String? _currentLyrics; // 暂时使用字符串存储歌词

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
    // 初始化歌词模型
    lyricModel = LyricsModelBuilder.create()
        .bindLyricToMain('[00:00.00]加载中...\n[00:01.00] \n[00:02.00] ')
        .getModel();
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

  /// 加载歌词和翻译
  Future<Map<String, String?>> _loadLyricsData(Song song) async {
    String? lyrics;
    String? trans;
    
    // 1) 优先使用 Song 对象中的歌词和翻译
    if (song.lyricsLrc != null && song.lyricsLrc!.isNotEmpty) {
      lyrics = song.lyricsLrc;
      Logger.debug('✅ 使用对象存储的歌词: ${song.title}');
      if (song.lyricsTrans != null && song.lyricsTrans!.isNotEmpty) {
        trans = song.lyricsTrans;
        Logger.debug('✅ 使用对象存储的翻译: ${song.title}');
      }
      return {'lyrics': lyrics, 'trans': trans};
    }
    
    // 2) 检查是否有本地下载的歌词文件
    final downloaded = await _downloadService.getDownloadedSongs();
    final downloadedSong = downloaded.where((d) => d.id == song.id).firstOrNull;
    
    // 读取本地歌词文件
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
    
    // 读取本地翻译文件
    if (downloadedSong?.localTransPath != null) {
      try {
        final transFile = File(downloadedSong!.localTransPath!);
        if (await transFile.exists()) {
          trans = await transFile.readAsString();
          Logger.debug('✅ 使用本地下载的翻译: ${song.title}');
        }
      } catch (e) {
        Logger.warning('读取本地翻译失败: $e', 'PlayerScreen');
      }
    }
    
    // 3) 检查是否为本地扫描的歌曲，直接从音频文件路径查找歌词和翻译文件
    if (lyrics == null || trans == null) {
      try {
        // 尝试从音频文件路径构建歌词和翻译文件路径
        // 检查 audioUrl 是否为本地文件路径
        if (song.audioUrl.startsWith('file://')) {
          // 从 file:// URI 提取文件路径
          String audioFilePath = song.audioUrl;
          // 移除 file:// 前缀
          if (audioFilePath.startsWith('file:///')) {
            audioFilePath = audioFilePath.substring(8);
          } else if (audioFilePath.startsWith('file://')) {
            audioFilePath = audioFilePath.substring(7);
          }
          // Windows 路径特殊处理
          if (Platform.isWindows && audioFilePath.startsWith('/')) {
            audioFilePath = audioFilePath.substring(1);
          }
          
          if (audioFilePath.isNotEmpty) {
            final basePath = audioFilePath.substring(0, audioFilePath.lastIndexOf('.'));
            
            // 检查歌词文件
            if (lyrics == null) {
              final lrcFile = File('$basePath.lrc');
              if (await lrcFile.exists()) {
                lyrics = await lrcFile.readAsString();
                Logger.debug('✅ 使用本地扫描的歌词: ${song.title}');
              }
            }
            
            // 检查翻译文件
            if (trans == null) {
              final transFile = File('${basePath}_trans.lrc');
              if (await transFile.exists()) {
                trans = await transFile.readAsString();
                Logger.debug('✅ 使用本地扫描的翻译: ${song.title}');
              }
            }
          }
        }
      } catch (e) {
        Logger.warning('读取本地扫描歌曲的歌词和翻译失败: $e', 'PlayerScreen');
      }
    }
    
    if (lyrics != null && lyrics.isNotEmpty) {
      return {'lyrics': lyrics, 'trans': trans};
    }
    
    // 4) 从数据库读取歌词和翻译
    final dbResult = await LyricsService().getLyricsWithTranslation(song.id);
    if (dbResult != null) {
      if (lyrics == null || lyrics.isEmpty) {
        lyrics = dbResult['lrc'];
        if (lyrics != null && lyrics.isNotEmpty) {
          Logger.debug('✅ 从数据库读取歌词: ${song.title}');
        }
      }
      if (trans == null || trans.isEmpty) {
        trans = dbResult['trans'];
        if (trans != null && trans.isNotEmpty) {
          Logger.debug('✅ 从数据库读取翻译: ${song.title}');
        }
      }
      
      if (lyrics != null && lyrics.isNotEmpty) {
        return {'lyrics': lyrics, 'trans': trans};
      }
    }
    
    // 5) 最后回退到 API，并把结果写回数据库
    Logger.debug('⚠️ 无本地歌词，使用API获取: ${song.title}');
    final result = await _apiService.getLyricsWithTranslation(songId: song.id);
    lyrics = result?['lrc'];
    trans = result?['trans'];

    if (lyrics != null && lyrics.isNotEmpty) {
      // 异步写回数据库，失败忽略
      LyricsService().saveLyrics(
        songId: song.id,
        lyrics: lyrics,
        title: song.title,
        artist: song.artist,
        translation: trans,
      );
    }
    
    return {'lyrics': lyrics, 'trans': trans};
  }

  /// 暂时存储歌词数据
  void _storeLyricsData(String? lyrics, String? trans) {
    _currentLyrics = lyrics;
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
      // 加载歌词和翻译数据
      final result = await _loadLyricsData(song);
      final lyrics = result['lyrics'];
      final trans = result['trans'];
      
      if (mounted && lyrics != null && lyrics.isNotEmpty) {
        setState(() {
          _currentLyricsLrc = lyrics;
          _currentLyricsTrans = trans;
          _storeLyricsData(lyrics, trans);
          // 更新歌词模型
          lyricModel = LyricsModelBuilder.create()
              .bindLyricToMain(lyrics)
              .bindLyricToExt(trans ?? '')
              .getModel();
        });
      } else {
        // 没有歌词，使用默认
        if (mounted) {
          setState(() {
            _currentLyrics = '[00:00.00]暂无歌词\n[00:01.00] \n[00:02.00] ';
            _currentLyricsLrc = null;
            _currentLyricsTrans = null;
            // 更新歌词模型为默认状态
            lyricModel = LyricsModelBuilder.create()
                .bindLyricToMain('[00:00.00]暂无歌词\n[00:01.00] \n[00:02.00] ')
                .getModel();
          });
        }
      }
    } catch (e) {
      Logger.error('加载歌词失败', e, null, 'PlayerScreen');
      if (mounted) {
        setState(() {
          _currentLyrics = '[00:00.00]暂无歌词\n[00:01.00] \n[00:02.00] ';
          _currentLyricsLrc = null;
          _currentLyricsTrans = null;
          // 更新歌词模型为默认状态
          lyricModel = LyricsModelBuilder.create()
              .bindLyricToMain('[00:00.00]暂无歌词\n[00:01.00] \n[00:02.00] ')
              .getModel();
        });
      }
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
                Image.network(
                  song.r2CoverUrl ?? song.coverUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
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
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
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
                    );
                  },
                ),
                // 模糊和暗化效果
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
                      // 定时器状态显示
                      _buildSleepTimerIndicator(context, musicProvider),
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
                      PlayerControlPanel(
                        musicProvider: musicProvider,
                        downloadService: _downloadService,
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
              // 桌面端和 Android 端都显示翻译开关
              Consumer<MusicProvider>(
                builder: (context, musicProvider, child) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: IconButton(
                      icon: Icon(
                        musicProvider.showLyricsTranslation
                            ? Icons.translate_rounded
                            : Icons.translate_outlined,
                        color: musicProvider.showLyricsTranslation
                            ? Colors.orange
                            : Colors.white,
                        size: 24,
                      ),
                      onPressed: () {
                        musicProvider.setShowLyricsTranslation(
                          !musicProvider.showLyricsTranslation,
                        );
                        // 重新加载歌词以应用翻译设置
                        _currentSongId = null;
                        _loadLyrics();
                      },
                    ),
                  );
                },
              ),
              // Android 端额外显示"更多"按钮
              if (isAndroid)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.more_horiz, color: Colors.white, size: 24),
                    onPressed: () => showPlayerMoreMenu(context),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建睡眠定时器指示器
  Widget _buildSleepTimerIndicator(BuildContext context, MusicProvider musicProvider) {
    if (!musicProvider.sleepTimer.isActive) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: GestureDetector(
        onTap: () => showSleepTimerDialog(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.orange.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.timer,
                size: 18,
                color: Colors.orange,
              ),
              const SizedBox(width: 8),
              Text(
                '定时关闭: ${musicProvider.sleepTimer.formattedRemainingTime}',
                style: const TextStyle(
                  color: Colors.orange,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: Colors.orange.withValues(alpha: 0.7),
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
        return Container(
          height: 280,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: LyricsReader(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            model: lyricModel,
            lyricUi: lyricUI,
            playing: musicProvider.isPlaying,
            position: musicProvider.currentPosition.inMilliseconds,
          ),
        );
      },
    );
  }


}
