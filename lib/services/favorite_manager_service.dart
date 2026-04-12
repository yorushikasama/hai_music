import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as path;

import '../config/app_constants.dart';
import '../models/audio_quality.dart';
import '../models/favorite_song.dart';
import '../models/song.dart';
import '../models/storage_config.dart';
import '../utils/logger.dart';
import 'audio_quality_service.dart';
import 'dio_client.dart';
import 'music_api_service.dart';
import 'preferences_service.dart';
import 'r2_storage_service.dart';
import 'storage_config_service.dart';
import 'storage_path_manager.dart';
import 'supabase_service.dart';

/// 收藏管理服务
/// 负责协调本地存储、数据库和对象存储
class FavoriteManagerService {
  static final FavoriteManagerService _instance = FavoriteManagerService._internal();

  final SupabaseService _supabase = SupabaseService();
  final R2StorageService _r2 = R2StorageService();
  final StorageConfigService _configService = StorageConfigService();
  final PreferencesService _prefs = PreferencesService();
  final MusicApiService _apiService = MusicApiService();
  final StoragePathManager _pathManager = StoragePathManager();
  final Dio _dio = DioClient().dio;

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

      _config = await _configService.getConfigAsync();

      // 只要配置有效就初始化 Supabase（不依赖 enableSync 开关）
      if (_config != null && _config!.isValid) {
        await _supabase.initialize(_config!);
        if (_config!.enableSync) {
          await _r2.initialize(_config!);
        }
      }

      _initialized = true;
      return true;
    } catch (e) {
      Logger.error('初始化收藏管理服务失败', e, null, 'FavoriteManager');
      return false;
    }
  }

  /// 确保 Supabase 已初始化（懒初始化）
  Future<bool> _ensureSupabaseReady() async {
    if (_supabase.isInitialized) return true;

    // 尝试用现有配置初始化
    _config ??= await _configService.getConfigAsync();
    if (_config != null && _config!.isValid) {
      return await _supabase.initialize(_config!);
    }
    return false;
  }

  /// 检查是否启用云端同步
  bool get isSyncEnabled => _config?.enableSync ?? false;

  /// 添加收藏
  Future<bool> addFavorite(Song song, {AudioQuality? audioQuality}) async {
    if (!_initialized) await initialize();

    // 确保 Supabase 可用
    await _ensureSupabaseReady();

    try {
      // 1. 添加到本地收藏列表
      await _prefs.addFavorite(song.id);

      // 2. 如果启用云端同步，则下载并上传文件
      if (isSyncEnabled) {
        await _syncToCloud(song, audioQuality: audioQuality);
      } else {
        // 未启用云端同步时，也保存基本信息到数据库
        String? lyricsLrc = song.lyricsLrc;
        if (lyricsLrc == null || lyricsLrc.isEmpty) {
          lyricsLrc = await _apiService.getLyrics(songId: song.id);
        }

        final favoriteSong = FavoriteSong(
          id: song.id,
          title: song.title,
          artist: song.artist,
          album: song.album,
          coverUrl: song.coverUrl,
          duration: song.duration,
          platform: song.platform,
          lyricsLrc: lyricsLrc,
          syncedAt: DateTime.now(),
        );
        await _supabase.addFavorite(favoriteSong);
        Logger.database('收藏信息已保存到数据库', 'FavoriteManager');
      }

      return true;
    } catch (e) {
      Logger.error('添加收藏失败', e, null, 'FavoriteManager');
      return false;
    }
  }

  /// 同步收藏到云端
  Future<void> _syncToCloud(Song song, {AudioQuality? audioQuality}) async {
    try {
      // 1. 获取歌词（如果 song 中没有）
      String? lyricsLrc = song.lyricsLrc;
      if (lyricsLrc == null || lyricsLrc.isEmpty) {
        lyricsLrc = await _apiService.getLyrics(songId: song.id);
      }

      // 2. 下载音频和封面到本地
      final audioFile = await _downloadAudio(song, audioQuality: audioQuality);
      final coverFile = await _downloadCover(song);

      // 3. 获取真实时长（从音频文件）
      int durationSeconds = song.duration ?? 0;
      if (audioFile != null && durationSeconds == 0) {
        durationSeconds = await _getAudioDuration(audioFile);
      }

      // 4. 上传到 R2
      String? r2AudioUrl;
      String? r2CoverUrl;

      if (audioFile != null) {
        r2AudioUrl = await _r2.uploadAudio(audioFile, song.id);
      }

      if (coverFile != null) {
        r2CoverUrl = await _r2.uploadCover(coverFile, song.id);
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
        lyricsLrc: lyricsLrc,
        syncedAt: DateTime.now(),
      );

      await _supabase.addFavorite(favoriteSong);

      Logger.success('歌曲已同步到云端: ${song.title}', 'FavoriteManager');
    } catch (e) {
      Logger.error('同步到云端失败', e, null, 'FavoriteManager');
    }
  }

  /// 下载音频文件
  Future<File?> _downloadAudio(Song song, {AudioQuality? audioQuality}) async {
    try {
      final audioDir = await _pathManager.getMusicAudioDir();

      final quality = audioQuality ?? AudioQualityService.instance.getCurrentQuality();
      final fileName = '${song.id}${quality.fileExtension}';
      final filePath = path.join(audioDir.path, fileName);
      final file = File(filePath);

      // 如果文件已存在，直接返回
      if (file.existsSync()) {
        return file;
      }

      // 获取真实的音频URL
      String? audioUrl = song.audioUrl.isNotEmpty ? song.audioUrl : null;
      if (audioUrl == null) {
        audioUrl = await _apiService.getSongUrl(
          songId: song.id,
          quality: quality.value,
        );
      }

      if (audioUrl == null || audioUrl.isEmpty) {
        Logger.warning('无法获取音频URL', 'FavoriteManager');
        return null;
      }

      // 下载文件
      await _dio.download(audioUrl, filePath);
      Logger.success('音频下载完成', 'FavoriteManager');
      return file;
    } catch (e) {
      Logger.error('下载音频失败', e, null, 'FavoriteManager');
      return null;
    }
  }

  /// 下载封面图片
  Future<File?> _downloadCover(Song song) async {
    try {
      if (song.coverUrl.isEmpty) return null;

      final coverDir = await _pathManager.getMusicCoversDir();

      final fileName = '${song.id}${AppConstants.coverExtension}';
      final filePath = path.join(coverDir.path, fileName);
      final file = File(filePath);

      // 如果文件已存在，直接返回
      if (file.existsSync()) {
        return file;
      }

      // 下载文件
      await _dio.download(song.coverUrl, filePath);
      return file;
    } catch (e) {
      Logger.error('下载封面失败', e, null, 'FavoriteManager');
      return null;
    }
  }

  /// 获取音频文件的时长
  Future<int> _getAudioDuration(File audioFile) async {
    AudioPlayer? player;
    try {
      player = AudioPlayer();
      await player.setFilePath(audioFile.path);

      // 等待时长加载
      final durationFuture = player.durationFuture;
      if (durationFuture != null) {
        final duration = await durationFuture.timeout(
          const Duration(seconds: AppConstants.audioDurationTimeout),
          onTimeout: () => null,
        );
        await player.dispose();
        return duration?.inSeconds ?? 0;
      } else {
        await player.dispose();
        return 0;
      }
    } catch (e) {
      Logger.error('获取音频时长失败', e, null, 'FavoriteManager');
      await player?.dispose();
      return 0;
    }
  }

  /// 移除收藏
  Future<bool> removeFavorite(String songId) async {
    if (!_initialized) await initialize();

    // 确保 Supabase 可用
    await _ensureSupabaseReady();

    try {
      // 1. 从本地收藏列表移除
      await _prefs.removeFavorite(songId);

      // 2. 从 Supabase 删除
      if (isSyncEnabled) {
        await _supabase.removeFavorite(songId);
        await _r2.deleteSongFiles(songId);
      } else {
        try {
          await _supabase.removeFavorite(songId);
        } catch (e) {
          Logger.warning('Supabase 移除收藏失败: $songId', 'FavoriteManager');
        }
      }

      await _deleteLocalFiles(songId);

      return true;
    } catch (e) {
      Logger.error('移除收藏失败', e, null, 'FavoriteManager');
      return false;
    }
  }

  /// 删除本地文件
  Future<void> _deleteLocalFiles(String songId) async {
    try {
      final audioPath = await _pathManager.getAudioFilePath(songId);
      final audioFile = File(audioPath);
      if (audioFile.existsSync()) {
        audioFile.deleteSync();
      }

      final coverPath = await _pathManager.getCoverFilePath(songId);
      final coverFile = File(coverPath);
      if (coverFile.existsSync()) {
        coverFile.deleteSync();
      }
    } catch (e) {
      Logger.error('删除本地文件失败', e, null, 'FavoriteManager');
    }
  }

  /// 获取所有收藏
  Future<List<FavoriteSong>> getFavorites() async {
    if (!_initialized) await initialize();

    // 确保 Supabase 可用
    await _ensureSupabaseReady();

    try {
      if (_supabase.isInitialized) {
        final favorites = await _supabase.getFavorites();

        // 同步更新 SharedPreferences 中的 ID 列表
        final favoriteIds = favorites.map((f) => f.id).toList();
        await _prefs.setFavoriteSongs(favoriteIds);

        return favorites;
      } else {
        Logger.warning('Supabase 未初始化，无法获取收藏列表', 'FavoriteManager');
        return [];
      }
    } catch (e) {
      Logger.error('获取收藏列表失败', e, null, 'FavoriteManager');
      return [];
    }
  }

  /// 检查是否已收藏
  Future<bool> isFavorite(String songId) async {
    if (!_initialized) await initialize();

    // 优先从本地检查（更快）
    return _prefs.isFavorite(songId);
  }

  /// 更新配置
  Future<bool> updateConfig(StorageConfig config) async {
    try {
      final saveSuccess = await _configService.saveConfig(config);
      if (!saveSuccess) {
        Logger.error('配置保存到本地失败', null, null, 'FavoriteManager');
        return false;
      }

      _config = config;
      _initialized = false;
      _supabase.dispose();

      if (config.isValid) {
        await _supabase.initialize(config);
        if (config.enableSync) {
          await _r2.initialize(config);
        }
      }

      _initialized = true;
      Logger.success('配置更新完成', 'FavoriteManager');
      return true;
    } catch (e) {
      Logger.error('更新配置失败', e, null, 'FavoriteManager');
      return false;
    }
  }

  final Set<String> _operationInProgress = {};

  bool isOperationInProgress(String songId) => _operationInProgress.contains(songId);

  Future<bool> toggleFavorite(String songId, Song? song, List<Song> playlist) async {
    if (_operationInProgress.contains(songId)) {
      Logger.warning('收藏操作正在进行中，请稍候...', 'FavoriteManager');
      return false;
    }

    _operationInProgress.add(songId);

    try {
      final isFav = _prefs.isFavorite(songId);

      if (isFav) {
        final success = await removeFavorite(songId);
        if (success) {
          Logger.database('取消收藏: $songId', 'FavoriteManager');
        }
        return success;
      } else {
        Song? targetSong = song;
        if (targetSong == null || targetSong.id != songId) {
          final idx = playlist.indexWhere((s) => s.id == songId);
          if (idx >= 0) {
            targetSong = playlist[idx];
          }
        }

        if (targetSong == null) {
          Logger.error('找不到要收藏的歌曲: $songId', null, null, 'FavoriteManager');
          return false;
        }

        final success = await addFavorite(targetSong);
        if (success) {
          Logger.database('添加收藏: ${targetSong.title}', 'FavoriteManager');
        }
        return success;
      }
    } catch (e) {
      Logger.error('收藏操作异常', e, null, 'FavoriteManager');
      return false;
    } finally {
      _operationInProgress.remove(songId);
    }
  }

  StorageConfig getConfig() {
    return _config ?? StorageConfig.empty();
  }

  Future<StorageConfig> getConfigAsync() async {
    _config ??= await _configService.getConfigAsync();
    return _config ?? StorageConfig.empty();
  }

  /// 清除所有收藏
  Future<bool> clearAll() async {
    try {
      await _prefs.setFavoriteSongs([]);

      if (_supabase.isInitialized) {
        await _supabase.clearAllFavorites();
      }

      return true;
    } catch (e) {
      Logger.error('清除收藏失败', e, null, 'FavoriteManager');
      return false;
    }
  }
}
