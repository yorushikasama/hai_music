import 'dart:io';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:audioplayers/audioplayers.dart';
import '../models/song.dart';
import '../models/favorite_song.dart';
import '../models/storage_config.dart';
import '../config/app_constants.dart';
import 'supabase_service.dart';
import 'r2_storage_service.dart';
import 'storage_config_service.dart';
import 'preferences_service.dart';
import 'music_api_service.dart';

/// 收藏管理服务
/// 负责协调本地存储、数据库和对象存储
class FavoriteManagerService {
  static final FavoriteManagerService _instance = FavoriteManagerService._internal();
  
  final SupabaseService _supabase = SupabaseService();
  final R2StorageService _r2 = R2StorageService();
  final StorageConfigService _configService = StorageConfigService();
  final PreferencesService _prefs = PreferencesService();
  final MusicApiService _apiService = MusicApiService();
  final Dio _dio = Dio();

  bool _initialized = false;
  StorageConfig? _config;

  factory FavoriteManagerService() => _instance;

  FavoriteManagerService._internal();

  /// 初始化服务
  Future<bool> initialize() async {
    if (_initialized) return true;

    try {
      await _configService.init();
      await _prefs.init();
      
      _config = _configService.getConfig();
      
      if (_config != null && _config!.isValid && _config!.enableSync) {
        // 初始化 Supabase 和 R2
        await _supabase.initialize(_config!);
        await _r2.initialize(_config!);
      }

      _initialized = true;
      return true;
    } catch (e) {
      print('初始化收藏管理服务失败: $e');
      return false;
    }
  }

  /// 检查是否启用云端同步
  bool get isSyncEnabled => _config?.enableSync ?? false;

  /// 添加收藏
  /// [song] 要收藏的歌曲
  /// [audioQuality] 音频音质（可选，默认使用臻品母带）
  Future<bool> addFavorite(Song song, {int? audioQuality}) async {
    if (!_initialized) await initialize();

    try {
      // 1. 添加到本地收藏列表
      await _prefs.addFavorite(song.id);

      // 2. 如果启用云端同步，则下载并上传文件
      if (isSyncEnabled) {
        await _syncToCloud(song, audioQuality: audioQuality);
      } else {
        // 未启用云端同步时，也保存基本信息到数据库
        print('保存收藏信息到数据库: ${song.title}');
        
        // 获取歌词
        String? lyricsLrc = song.lyricsLrc;
        if (lyricsLrc == null || lyricsLrc.isEmpty) {
          print('正在获取歌词...');
          lyricsLrc = await _apiService.getLyrics(songId: song.id);
          if (lyricsLrc != null && lyricsLrc.isNotEmpty) {
            print('✅ 歌词获取成功');
          } else {
            print('⚠️ 未获取到歌词');
          }
        }
        
        final favoriteSong = FavoriteSong(
          id: song.id,
          title: song.title,
          artist: song.artist,
          album: song.album,
          coverUrl: song.coverUrl,
          duration: song.duration.inSeconds,
          platform: song.platform,
          lyricsLrc: lyricsLrc,
          syncedAt: DateTime.now(),
        );
        await _supabase.addFavorite(favoriteSong);
        print('✅ 收藏信息已保存到数据库');
      }

      return true;
    } catch (e) {
      print('添加收藏失败: $e');
      return false;
    }
  }

  /// 同步收藏到云端
  /// [song] 要同步的歌曲
  /// [audioQuality] 音频音质（可选，默认使用臻品母带）
  Future<void> _syncToCloud(Song song, {int? audioQuality}) async {
    try {
      print('开始同步歌曲到云端: ${song.title}');
      
      // 1. 获取歌词（如果 song 中没有）
      String? lyricsLrc = song.lyricsLrc;
      if (lyricsLrc == null || lyricsLrc.isEmpty) {
        print('正在获取歌词...');
        lyricsLrc = await _apiService.getLyrics(songId: song.id);
        if (lyricsLrc != null && lyricsLrc.isNotEmpty) {
          print('✅ 歌词获取成功');
        } else {
          print('⚠️ 未获取到歌词');
        }
      }
      
      // 2. 下载音频和封面到本地
      final audioFile = await _downloadAudio(song, audioQuality: audioQuality);
      final coverFile = await _downloadCover(song);

      print('下载完成 - 音频: ${audioFile != null}, 封面: ${coverFile != null}');

      // 3. 获取真实时长（从音频文件）
      int durationSeconds = song.duration.inSeconds;
      if (audioFile != null && durationSeconds == 0) {
        durationSeconds = await _getAudioDuration(audioFile);
        print('从音频文件获取时长: $durationSeconds 秒');
      }

      // 4. 上传到 R2
      String? r2AudioUrl;
      String? r2CoverUrl;

      if (audioFile != null) {
        print('正在上传音频到 R2...');
        r2AudioUrl = await _r2.uploadAudio(audioFile, song.id);
        print('音频上传完成: $r2AudioUrl');
      }

      if (coverFile != null) {
        print('正在上传封面到 R2...');
        r2CoverUrl = await _r2.uploadCover(coverFile, song.id);
        print('封面上传完成: $r2CoverUrl');
      }

      // 5. 保存到 Supabase 数据库
      final favoriteSong = FavoriteSong(
        id: song.id,
        title: song.title,
        artist: song.artist,
        album: song.album,
        coverUrl: song.coverUrl,
        localAudioPath: audioFile?.path,
        localCoverPath: coverFile?.path,
        r2AudioUrl: r2AudioUrl,
        r2CoverUrl: r2CoverUrl,
        duration: durationSeconds > 0 ? durationSeconds : AppConstants.defaultSongDuration,
        platform: song.platform,
        lyricsLrc: lyricsLrc, // 保存获取到的歌词
        syncedAt: DateTime.now(),
      );

      print('正在保存到 Supabase...');
      await _supabase.addFavorite(favoriteSong);
      
      print('✅ 歌曲已成功同步到云端: ${song.title}');
    } catch (e) {
      print('❌ 同步到云端失败: $e');
    }
  }

  /// 下载音频文件
  /// [song] 要下载的歌曲
  /// [audioQuality] 音频音质（可选，默认使用臻品母带）
  Future<File?> _downloadAudio(Song song, {int? audioQuality}) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final audioDir = Directory(path.join(dir.path, AppConstants.musicFolder, AppConstants.audioFolder));
      await audioDir.create(recursive: true);

      final fileName = '${song.id}${AppConstants.audioExtension}';
      final filePath = path.join(audioDir.path, fileName);
      final file = File(filePath);

      // 如果文件已存在，直接返回
      if (await file.exists()) {
        print('音频文件已存在，跳过下载');
        return file;
      }

      // 获取真实的音频URL
      String? audioUrl = song.audioUrl;
      if (audioUrl.isEmpty) {
        // 使用传入的音质，如果没有则使用臻品母带
        final quality = audioQuality ?? AppConstants.qualityLossless;
        print('正在获取音频播放链接... (音质: $quality)');
        audioUrl = await _apiService.getSongUrl(
          songId: song.id,
          quality: quality,
        );
      }

      if (audioUrl == null || audioUrl.isEmpty) {
        print('无法获取音频URL');
        return null;
      }

      print('开始下载音频: $audioUrl');
      // 下载文件
      await _dio.download(audioUrl, filePath);
      print('音频下载完成');
      return file;
    } catch (e) {
      print('下载音频失败: $e');
      return null;
    }
  }

  /// 下载封面图片
  Future<File?> _downloadCover(Song song) async {
    try {
      if (song.coverUrl.isEmpty) return null;

      final dir = await getApplicationDocumentsDirectory();
      final coverDir = Directory(path.join(dir.path, AppConstants.musicFolder, AppConstants.coverFolder));
      await coverDir.create(recursive: true);

      final fileName = '${song.id}${AppConstants.coverExtension}';
      final filePath = path.join(coverDir.path, fileName);
      final file = File(filePath);

      // 如果文件已存在，直接返回
      if (await file.exists()) {
        return file;
      }

      // 下载文件
      await _dio.download(song.coverUrl, filePath);
      return file;
    } catch (e) {
      print('下载封面失败: $e');
      return null;
    }
  }

  /// 获取音频文件的时长
  Future<int> _getAudioDuration(File audioFile) async {
    AudioPlayer? player;
    try {
      player = AudioPlayer();
      await player.setSourceDeviceFile(audioFile.path);
      
      // 使用 Completer 等待时长
      final completer = Completer<Duration>();
      final subscription = player.onDurationChanged.listen((d) {
        if (!completer.isCompleted) {
          completer.complete(d);
        }
      });
      
      // 等待最多3秒
      final duration = await completer.future.timeout(
        Duration(seconds: AppConstants.audioDurationTimeout),
        onTimeout: () => Duration.zero,
      );
      
      await subscription.cancel();
      await player.dispose();
      
      return duration.inSeconds;
    } catch (e) {
      print('获取音频时长失败: $e');
      await player?.dispose();
      return 0;
    }
  }

  /// 移除收藏
  Future<bool> removeFavorite(String songId) async {
    if (!_initialized) await initialize();

    try {
      // 1. 从本地收藏列表移除
      await _prefs.removeFavorite(songId);

      // 2. 从数据库删除（无论是否启用云端同步）
      print('从数据库删除收藏: $songId');
      await _supabase.removeFavorite(songId);

      // 3. 如果启用云端同步，则删除 R2 文件
      if (isSyncEnabled) {
        print('删除 R2 文件: $songId');
        await _r2.deleteSongFiles(songId);
      }

      // 4. 删除本地文件
      await _deleteLocalFiles(songId);

      return true;
    } catch (e) {
      print('移除收藏失败: $e');
      return false;
    }
  }

  /// 删除本地文件
  Future<void> _deleteLocalFiles(String songId) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      
      // 删除音频文件
      final audioFile = File(path.join(dir.path, AppConstants.musicFolder, AppConstants.audioFolder, '$songId${AppConstants.audioExtension}'));
      if (await audioFile.exists()) {
        await audioFile.delete();
      }

      // 删除封面文件
      final coverFile = File(path.join(dir.path, AppConstants.musicFolder, AppConstants.coverFolder, '$songId${AppConstants.coverExtension}'));
      if (await coverFile.exists()) {
        await coverFile.delete();
      }
    } catch (e) {
      print('删除本地文件失败: $e');
    }
  }

  /// 获取所有收藏
  Future<List<FavoriteSong>> getFavorites() async {
    if (!_initialized) {
      print('⚙️ FavoriteManager 未初始化，正在初始化...');
      await initialize();
    }

    try {
      print('📊 云同步状态: ${isSyncEnabled ? "已启用" : "未启用"}');
      
      if (isSyncEnabled) {
        // 从云端获取
        print('☁️ 从云端获取收藏列表...');
        return await _supabase.getFavorites();
      } else {
        // 从本地获取（只有ID列表）
        print('📱 从本地获取收藏ID列表...');
        final ids = _prefs.getFavorites();
        print('📱 本地收藏ID: $ids');
        // 注意：本地模式下无法获取完整的歌曲信息
        // 需要配合其他服务来获取歌曲详情
        return [];
      }
    } catch (e) {
      print('❌ 获取收藏列表失败: $e');
      return [];
    }
  }

  /// 检查是否已收藏
  Future<bool> isFavorite(String songId) async {
    if (!_initialized) await initialize();

    // 优先从本地检查（更快）
    return _prefs.isFavorite(songId);
  }

  /// 获取本地收藏的歌曲ID列表
  List<String> getLocalFavoriteIds() {
    return _prefs.getFavorites();
  }

  /// 更新配置
  Future<bool> updateConfig(StorageConfig config) async {
    try {
      await _configService.saveConfig(config);
      _config = config;

      if (config.isValid && config.enableSync) {
        await _supabase.initialize(config);
        await _r2.initialize(config);
      }

      return true;
    } catch (e) {
      print('更新配置失败: $e');
      return false;
    }
  }

  /// 获取当前配置
  StorageConfig getConfig() {
    return _config ?? StorageConfig.empty();
  }

  /// 同步所有本地收藏到云端
  Future<void> syncAllToCloud(List<Song> songs, {int? audioQuality}) async {
    if (!isSyncEnabled) return;

    final favoriteIds = _prefs.getFavorites();
    final favoriteSongs = songs.where((s) => favoriteIds.contains(s.id)).toList();

    for (final song in favoriteSongs) {
      await _syncToCloud(song, audioQuality: audioQuality);
    }
  }

  /// 从云端同步到本地
  Future<void> syncFromCloud() async {
    if (!isSyncEnabled) return;

    try {
      final cloudFavorites = await _supabase.getFavorites();
      final localIds = cloudFavorites.map((f) => f.id).toList();
      
      await _prefs.setFavoriteSongs(localIds);
    } catch (e) {
      print('从云端同步失败: $e');
    }
  }

  /// 清除所有收藏
  Future<bool> clearAll() async {
    try {
      await _prefs.setFavoriteSongs([]);
      
      if (isSyncEnabled) {
        await _supabase.clearAllFavorites();
      }

      return true;
    } catch (e) {
      print('清除收藏失败: $e');
      return false;
    }
  }
}
