import 'dart:async';
import 'dart:io';

import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as path;

import '../../config/app_constants.dart';
import '../../models/audio_quality.dart';
import '../../models/favorite_song.dart';
import '../../models/song.dart';
import '../../models/storage_config.dart';
import '../../utils/logger.dart';
import '../download/download.dart';
import '../core/core.dart';
import '../network/network.dart';
import 'r2_storage_service.dart';
import 'storage_config_service.dart';
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
  final _audioDownloadService = AudioDownloadService();

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

  Future<File?> _downloadAudio(Song song, {AudioQuality? audioQuality}) async {
    try {
      final audioDir = await _pathManager.getMusicAudioDir();
      final quality = audioQuality ?? await AudioQualityService.instance.getCurrentQuality();
      final fileName = '${song.id}${quality.fileExtension}';
      final filePath = path.join(audioDir.path, fileName);

      final file = File(filePath);
      if (file.existsSync()) return file;

      final result = await _audioDownloadService.downloadAudio(
        song: song,
        targetPath: filePath,
        audioQuality: quality,
      );

      return result?.file;
    } catch (e) {
      Logger.error('下载音频失败', e, null, 'FavoriteManager');
      return null;
    }
  }

  Future<File?> _downloadCover(Song song) async {
    try {
      if (song.coverUrl.isEmpty) return null;

      final coverDir = await _pathManager.getMusicCoversDir();
      final fileName = '${song.id}${AppConstants.coverExtension}';
      final filePath = path.join(coverDir.path, fileName);

      return await _audioDownloadService.downloadCover(
        coverUrl: song.coverUrl,
        targetPath: filePath,
      );
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
        return duration?.inSeconds ?? 0;
      } else {
        return 0;
      }
    } catch (e) {
      Logger.error('获取音频时长失败', e, null, 'FavoriteManager');
      return 0;
    } finally {
      await player?.dispose();
    }
  }

  /// 移除收藏
  Future<bool> removeFavorite(String songId) async {
    if (!_initialized) await initialize();

    // 确保 Supabase 可用
    await _ensureSupabaseReady();

    bool allSuccess = true;

    try {
      // 1. 从本地收藏列表移除
      await _prefs.removeFavorite(songId);

      // 2. 从 Supabase 删除
      if (isSyncEnabled) {
        try {
          await _supabase.removeFavorite(songId);
        } catch (e) {
          Logger.error('Supabase 移除收藏失败: $songId', e, null, 'FavoriteManager');
          allSuccess = false;
        }

        try {
          final r2Deleted = await _r2.deleteSongFiles(songId);
          if (!r2Deleted) {
            Logger.warning('R2 文件删除失败: $songId', 'FavoriteManager');
            allSuccess = false;
          }
        } catch (e) {
          Logger.error('R2 文件删除失败: $songId', e, null, 'FavoriteManager');
          allSuccess = false;
        }
      } else {
        try {
          await _supabase.removeFavorite(songId);
        } catch (e) {
          Logger.warning('Supabase 移除收藏失败: $songId', 'FavoriteManager');
          // 未启用同步时 Supabase 失败不视为关键错误
        }
      }

      await _deleteLocalFiles(songId);

      return allSuccess;
    } catch (e) {
      Logger.error('移除收藏失败', e, null, 'FavoriteManager');
      return false;
    }
  }

  /// 批量移除收藏
  /// 返回 [BatchFavoriteResult] 包含成功/失败统计
  Future<BatchFavoriteResult> removeFavorites(List<String> songIds) async {
    if (songIds.isEmpty) {
      return const BatchFavoriteResult(total: 0, successIds: [], failedIds: []);
    }

    if (!_initialized) await initialize();
    await _ensureSupabaseReady();

    final successIds = <String>[];
    final failedIds = <String>[];

    // 批量从本地收藏列表移除
    for (final songId in songIds) {
      try {
        await _prefs.removeFavorite(songId);
        successIds.add(songId);
      } catch (e) {
        Logger.error('移除本地收藏失败: $songId', e, null, 'FavoriteManager');
        failedIds.add(songId);
      }
    }

    // 批量从 Supabase 删除
    if (isSyncEnabled) {
      for (final songId in successIds) {
        try {
          await _supabase.removeFavorite(songId);
        } catch (e) {
          Logger.error('Supabase 批量移除收藏失败: $songId', e, null, 'FavoriteManager');
        }

        try {
          await _r2.deleteSongFiles(songId);
        } catch (e) {
          Logger.error('R2 批量文件删除失败: $songId', e, null, 'FavoriteManager');
        }
      }
    } else {
      // 未启用同步时也尝试清理 Supabase 数据
      for (final songId in successIds) {
        try {
          await _supabase.removeFavorite(songId);
        } catch (e) {
          // 不视为关键错误
        }
      }
    }

    // 批量删除本地文件
    for (final songId in successIds) {
      await _deleteLocalFiles(songId);
    }

    Logger.info(
      '批量移除收藏完成: ${songIds.length}首, 成功${successIds.length}首, 失败${failedIds.length}首',
      'FavoriteManager',
    );

    return BatchFavoriteResult(
      total: songIds.length,
      successIds: successIds,
      failedIds: failedIds,
    );
  }

  /// 删除本地文件
  Future<void> _deleteLocalFiles(String songId) async {
    try {
      final audioPath = await _pathManager.getAudioFilePath(songId);
      final audioFile = File(audioPath);
      if (await audioFile.exists()) {
        await audioFile.delete();
      }

      final coverPath = await _pathManager.getCoverFilePath(songId);
      final coverFile = File(coverPath);
      if (await coverFile.exists()) {
        await coverFile.delete();
      }

      final lyricsDir = await _pathManager.getLyricsCacheDir();
      final lyricsFile = File(path.join(lyricsDir.path, '$songId.lrc'));
      if (await lyricsFile.exists()) {
        await lyricsFile.delete();
      }

      final transFile = File(path.join(lyricsDir.path, '${songId}_trans.lrc'));
      if (await transFile.exists()) {
        await transFile.delete();
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
    return await _prefs.isFavorite(songId);
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

  /// 检查指定歌曲的收藏操作是否正在进行中
  bool isOperationInProgress(String songId) => _operationInProgress.contains(songId);

  /// 切换歌曲收藏状态（收藏/取消收藏）
  Future<bool> toggleFavorite(String songId, Song? song, List<Song> playlist) async {
    if (_operationInProgress.contains(songId)) {
      Logger.warning('收藏操作正在进行中，请稍候...', 'FavoriteManager');
      return false;
    }

    _operationInProgress.add(songId);

    try {
      final isFav = await _prefs.isFavorite(songId);

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

  /// 异步获取存储配置（带缓存）
  Future<StorageConfig> getConfigAsync() async {
    _config ??= await _configService.getConfigAsync();
    return _config ?? StorageConfig.empty();
  }

}

/// 批量收藏操作结果
class BatchFavoriteResult {
  final int total;
  final List<String> successIds;
  final List<String> failedIds;

  /// 是否全部操作成功
  bool get allSuccess => failedIds.isEmpty;

  const BatchFavoriteResult({
    required this.total,
    required this.successIds,
    required this.failedIds,
  });
}
