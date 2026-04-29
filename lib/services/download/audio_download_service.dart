import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;

import '../../models/audio_quality.dart';
import '../../models/song.dart';
import '../../utils/format_utils.dart';
import '../../utils/logger.dart';
import '../core/core.dart';
import '../network/network.dart';

/// 音频下载结果
///
/// 包含下载完成后的文件引用、文件大小、实际使用的音频URL和音质信息。
/// 当下载成功时，[file] 指向本地已下载的音频文件。
class AudioDownloadResult {
  final File file;
  final int sizeBytes;
  final String audioUrl;
  final AudioQuality quality;

  AudioDownloadResult({
    required this.file,
    required this.sizeBytes,
    required this.audioUrl,
    required this.quality,
  });
}

/// 统一音频下载服务
///
/// 提供音频文件和封面图片的下载能力，消除了之前在
/// [DownloadService]、[FavoriteManagerService]、[SmartCacheService] 中
/// 重复实现的"获取URL → 下载文件"流程。
///
/// 职责边界：
/// - 音频URL解析（优先使用 Song.audioUrl，否则通过 API 获取）
/// - 文件下载（支持进度回调和取消令牌）
/// - 下载后验证（文件存在性、非空检查）
/// - 失败后清理（删除不完整的下载文件）
///
/// 不负责：
/// - 下载队列调度（由 [DownloadManager] 负责）
/// - 下载记录持久化（由 [DownloadDatabase] 负责）
/// - 元数据写入（由 [DownloadService] 负责）
class AudioDownloadService {
  static final AudioDownloadService _instance =
      AudioDownloadService._internal();
  factory AudioDownloadService() => _instance;
  AudioDownloadService._internal();

  final Dio _dio = DioClient().dio;
  final MusicApiService _apiService = MusicApiService();

  /// 下载音频文件到指定路径
  ///
  /// 完整的音频下载流程：
  /// 1. 解析音频URL（优先 [Song.audioUrl]，否则调用 API 获取）
  /// 2. 跳过本地路径（file:// / content:// 开头的URL）
  /// 3. 确保目标目录存在
  /// 4. 执行下载（支持 [CancelToken] 取消和进度回调）
  /// 5. 验证下载结果（文件存在性 + 非空检查）
  /// 6. 失败时清理不完整文件
  ///
  /// 支持断点续传：当 [resumeFromBytes] > 0 时，使用 HTTP Range 头
  /// 从已下载的字节位置继续下载，追加到已有文件末尾。
  ///
  /// [song] 要下载的歌曲
  /// [targetPath] 目标文件完整路径
  /// [audioQuality] 音频质量，为 null 时使用当前设置
  /// [cancelToken] 取消令牌，支持下载中途取消
  /// [onProgress] 下载进度回调 (receivedBytes, totalBytes)
  /// [resumeFromBytes] 已下载的字节数，用于断点续传
  ///
  /// 返回 [AudioDownloadResult] 包含文件和元信息，失败返回 null。
  /// 当 [CancelToken] 触发取消时，会 rethrow [DioException]。
  Future<AudioDownloadResult?> downloadAudio({
    required Song song,
    required String targetPath,
    AudioQuality? audioQuality,
    CancelToken? cancelToken,
    void Function(int received, int total)? onProgress,
    int resumeFromBytes = 0,
  }) async {
    Logger.download('开始下载音频: ${song.title} (id=${song.id}${resumeFromBytes > 0 ? ", 断点续传从 ${resumeFromBytes}字节" : ""})', 'AudioDownload');

    final quality =
        audioQuality ?? await AudioQualityService.instance.getCurrentQuality();

    final audioUrl = await _resolveAudioUrl(song, quality);
    if (audioUrl == null || audioUrl.isEmpty) {
      Logger.warning('无法获取音频URL: ${song.id}', 'AudioDownload');
      return null;
    }

    if (audioUrl.startsWith('file://') || audioUrl.startsWith('content://')) {
      Logger.info('音频为本地路径，跳过下载: ${song.id}', 'AudioDownload');
      return null;
    }

    final targetDir = Directory(path.dirname(targetPath));
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    try {
      if (resumeFromBytes > 0) {
        // 断点续传：使用 Range 头从已下载位置继续
        final partialFile = File(targetPath);
        if (!await partialFile.exists()) {
          Logger.warning('断点续传文件不存在，从头下载: ${song.title}', 'AudioDownload');
          resumeFromBytes = 0;
        } else {
          final actualSize = await partialFile.length();
          if (actualSize != resumeFromBytes) {
            Logger.warning('断点续传文件大小不匹配(${actualSize} vs ${resumeFromBytes})，从头下载', 'AudioDownload');
            resumeFromBytes = 0;
            await partialFile.delete();
          }
        }
      }

      if (resumeFromBytes > 0) {
        // 下载剩余部分到临时文件，然后追加
        final tempPath = '$targetPath.resume.tmp';
        try {
          await _dio.download(
            audioUrl,
            tempPath,
            cancelToken: cancelToken,
            options: Options(headers: {'Range': 'bytes=$resumeFromBytes-'}),
            onReceiveProgress: (received, total) {
              // 续传时 total 是剩余部分的大小，加上已下载部分得到总进度
              final totalWithExisting = resumeFromBytes + (total > 0 ? total : 0);
              onProgress?.call(resumeFromBytes + received, totalWithExisting);
            },
          );

          // 将临时文件追加到已有文件末尾
          final existingFile = File(targetPath);
          final tempFile = File(tempPath);
          final existingSink = existingFile.openWrite(mode: FileMode.append);
          await existingSink.addStream(tempFile.openRead());
          await existingSink.close();
          await tempFile.delete();
        } on DioException catch (e) {
          // 断点续传失败时清理临时文件，但保留部分下载文件
          final tempFile = File(tempPath);
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
          if (e.type == DioExceptionType.cancel) {
            Logger.download('音频断点续传已取消: ${song.title}', 'AudioDownload');
            rethrow;
          }
          // 续传失败，从头重试
          Logger.warning('断点续传失败，从头重新下载: ${song.title}', 'AudioDownload');
          final file = File(targetPath);
          if (await file.exists()) {
            await file.delete();
          }
          resumeFromBytes = 0;
        }
      }

      if (resumeFromBytes == 0) {
        await _dio.download(
          audioUrl,
          targetPath,
          cancelToken: cancelToken,
          onReceiveProgress: (received, total) {
            onProgress?.call(received, total);
          },
        );
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        Logger.download('音频下载已取消: ${song.title}', 'AudioDownload');
        rethrow;
      }
      Logger.error('音频下载失败: ${song.title}', e, null, 'AudioDownload');
      final file = File(targetPath);
      if (await file.exists()) {
        await file.delete();
      }
      return null;
    }

    final file = File(targetPath);
    if (!await file.exists()) {
      Logger.error('音频文件下载后不存在: $targetPath', null, null, 'AudioDownload');
      return null;
    }

    final sizeBytes = await file.length();
    if (sizeBytes == 0) {
      Logger.warning('下载的音频文件为空: ${song.title}', 'AudioDownload');
      await file.delete();
      return null;
    }

    Logger.success(
      '音频下载完成: ${song.title} (${FormatUtils.formatSize(sizeBytes)})',
      'AudioDownload',
    );

    return AudioDownloadResult(
      file: file,
      sizeBytes: sizeBytes,
      audioUrl: audioUrl,
      quality: quality,
    );
  }

  /// 解析音频URL
  ///
  /// 优先使用 [Song.audioUrl]（可能来自搜索结果或缓存），
  /// 为空时通过 [MusicApiService.getSongUrl] 从 API 获取。
  /// API 获取失败时返回 null。
  Future<String?> _resolveAudioUrl(Song song, AudioQuality quality) async {
    if (song.audioUrl.isNotEmpty) return song.audioUrl;

    try {
      return await _apiService.getSongUrl(
        songId: song.id,
        quality: quality.value,
      );
    } catch (e) {
      Logger.error('获取音频URL失败: ${song.id}', e, null, 'AudioDownload');
      return null;
    }
  }

  /// 下载封面图片到指定路径
  ///
  /// 支持三种来源：
  /// - 本地文件路径（file:// 开头）：直接复制
  /// - Content URI（content:// 开头）：跳过（Android 专用）
  /// - 网络 URL：通过 HTTP 下载
  ///
  /// 如果目标文件已存在且非空，直接返回该文件。
  /// 下载失败时会清理不完整文件。
  ///
  /// [coverUrl] 封面图片URL
  /// [targetPath] 目标文件完整路径
  /// [cancelToken] 取消令牌
  ///
  /// 返回下载成功的 [File]，失败返回 null。
  Future<File?> downloadCover({
    required String coverUrl,
    required String targetPath,
    CancelToken? cancelToken,
  }) async {
    if (coverUrl.isEmpty) return null;

    if (coverUrl.startsWith('file://')) {
      try {
        final sourcePath = Uri.parse(coverUrl).toFilePath();
        final sourceFile = File(sourcePath);
        if (await sourceFile.exists()) {
          final targetDir = Directory(path.dirname(targetPath));
          if (!await targetDir.exists()) {
            await targetDir.create(recursive: true);
          }
          return await sourceFile.copy(targetPath);
        }
      } catch (e) {
        Logger.warning('复制本地封面失败: $e', 'AudioDownload');
      }
      return null;
    }

    if (coverUrl.startsWith('content://')) return null;

    final existingFile = File(targetPath);
    if (await existingFile.exists()) {
      final size = await existingFile.length();
      if (size > 0) return existingFile;
      await existingFile.delete();
    }

    try {
      final targetDir = Directory(path.dirname(targetPath));
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      await _dio.download(coverUrl, targetPath, cancelToken: cancelToken);

      final file = File(targetPath);
      if (await file.exists() && await file.length() > 0) {
        Logger.success('封面下载完成', 'AudioDownload');
        return file;
      }

      if (await file.exists()) await file.delete();
      Logger.warning('下载的封面文件为空', 'AudioDownload');
      return null;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        Logger.download('封面下载已取消', 'AudioDownload');
        rethrow;
      }
      Logger.error('封面下载失败', e, null, 'AudioDownload');
      final file = File(targetPath);
      if (await file.exists()) await file.delete();
      return null;
    } catch (e) {
      Logger.error('封面下载失败', e, null, 'AudioDownload');
      final file = File(targetPath);
      if (await file.exists()) await file.delete();
      return null;
    }
  }

}
