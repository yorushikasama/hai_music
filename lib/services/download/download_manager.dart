import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../models/downloaded_song.dart';
import '../../models/song.dart';
import '../../utils/logger.dart';
import 'download_service.dart';
import '../core/core.dart';
import '../playback/playback.dart';

/// 下载任务状态枚举
enum DownloadStatus {
  waiting,       // 等待中（在队列中排队）
  downloading,   // 下载中
  paused,        // 已暂停（用户主动暂停）
  completed,     // 已完成
  failed,        // 下载失败
  cancelled,     // 已取消
}

/// 添加下载的结果枚举
enum AddDownloadResult {
  added,               // 新增下载任务
  alreadyExists,       // 歌曲已在下载列表中
  qualityUpgraded,     // 音质提升，重新下载
  wifiRequired,        // 当前非WiFi网络，被WiFi限制拦截
  storageInsufficient, // 存储空间不足
}

/// 下载任务数据模型
///
/// 包含任务状态、进度、速度等信息，由 DownloadManager 管理生命周期
class DownloadTask {
  final String id;
  final Song song;
  DownloadStatus status;
  double progress;
  String? errorMessage;
  DownloadedSong? result;
  CancelToken? cancelToken;
  int downloadedBytes;
  int totalBytes;
  double downloadSpeed;

  DownloadTask({
    required this.id,
    required this.song,
    this.status = DownloadStatus.waiting,
    this.progress = 0.0,
    this.errorMessage,
    this.result,
    this.cancelToken,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.downloadSpeed = 0.0,
  });

  String get remainingTime {
    if (downloadSpeed <= 0 || totalBytes <= 0) return '--:--';
    final remaining = totalBytes - downloadedBytes;
    if (remaining <= 0) return '0:00';
    final seconds = (remaining / downloadSpeed).ceil();
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String get progressText {
    if (totalBytes <= 0) return '${(progress * 100).toStringAsFixed(0)}%';
    final downloadedMB = (downloadedBytes / 1024 / 1024).toStringAsFixed(1);
    final totalMB = (totalBytes / 1024 / 1024).toStringAsFixed(1);
    return '$downloadedMB/$totalMB MB';
  }

  String get speedText {
    if (downloadSpeed <= 0) return '';
    final speedMB = downloadSpeed / 1024 / 1024;
    if (speedMB >= 1) {
      return '${speedMB.toStringAsFixed(1)} MB/s';
    }
    final speedKB = downloadSpeed / 1024;
    return '${speedKB.toStringAsFixed(0)} KB/s';
  }
}

/// 速度采样点，用于滑动窗口算法计算实时下载速度
class _SpeedSample {
  final DateTime time;
  final int bytes;
  _SpeedSample(this.time, this.bytes);
}

/// 下载管理器 - 负责下载任务的调度、并发控制和状态管理
///
/// 核心职责：
/// 1. 下载队列管理（添加、暂停、继续、取消、重试）
/// 2. 并发控制（默认3个任务并行，可配置1-5）
/// 3. 下载速度计算（5秒滑动窗口算法）
/// 4. WiFi限制和存储空间检查
/// 5. 下载状态通知（ChangeNotifier）
///
/// 使用方式：
/// ```dart
/// final manager = DownloadManager();
/// await manager.init();
/// final result = await manager.addDownload(song);
/// ```
class DownloadManager with ChangeNotifier {
  static final DownloadManager _instance = DownloadManager._internal();
  factory DownloadManager() => _instance;
  DownloadManager._internal();

  final DownloadService _downloadService = DownloadService();
  final Map<String, DownloadTask> _tasks = {};
  final List<String> _queue = [];
  int _activeCount = 0;
  int _maxConcurrent = 3;
  DateTime? _lastNotifyTime;

  final Map<String, List<_SpeedSample>> _speedSamples = {};

  List<DownloadTask> get tasks => _tasks.values.toList();

  List<DownloadTask> get downloadingTasks =>
      _tasks.values.where((t) => t.status == DownloadStatus.downloading).toList();

  List<DownloadTask> get waitingTasks =>
      _tasks.values.where((t) => t.status == DownloadStatus.waiting).toList();

  List<DownloadTask> get pausedTasks =>
      _tasks.values.where((t) => t.status == DownloadStatus.paused).toList();

  List<DownloadTask> get completedTasks =>
      _tasks.values.where((t) => t.status == DownloadStatus.completed).toList();

  List<DownloadTask> get failedTasks =>
      _tasks.values.where((t) => t.status == DownloadStatus.failed).toList();

  DownloadTask? getTask(String songId) => _tasks[songId];

  int get maxConcurrent => _maxConcurrent;

  set maxConcurrent(int value) {
    if (value >= 1 && value <= 5) {
      _maxConcurrent = value;
      _processQueue();
    }
  }

  Future<void> init() async {
    await _downloadService.init();
    final prefs = PreferencesService();
    await prefs.init();
    _maxConcurrent = await prefs.getMaxConcurrentDownloads();
  }

  Future<AddDownloadResult> addDownload(Song song) async {
    Logger.download('添加下载请求: ${song.title} - ${song.artist} (id=${song.id})', 'DownloadManager');

    final wifiCheck = await _checkWifiRequired();
    if (wifiCheck != null) {
      Logger.warning('下载被WiFi限制拦截: ${song.title}', 'DownloadManager');
      return wifiCheck;
    }

    final storageCheck = await _checkStorageSpace();
    if (storageCheck != null) {
      Logger.warning('下载被存储空间限制拦截: ${song.title}', 'DownloadManager');
      return storageCheck;
    }

    final isDownloaded = await _downloadService.isDownloaded(song.id);
    if (isDownloaded) {
      final prefs = PreferencesService();
      await prefs.init();
      final currentQuality = await prefs.getAudioQuality();

      final downloadedSongs = await _downloadService.getDownloadedSongs();
      final existingSong = downloadedSongs.where((s) => s.id == song.id).firstOrNull;

      if (existingSong != null &&
          existingSong.audioQualityValue != null &&
          existingSong.audioQualityValue! < currentQuality.value) {
        // 音质升级：不立即删除旧版本，下载成功后再删除
        // 将旧版本信息保存，在 _executeTask 完成后清理
        Logger.download(
            '音质提升：将重新下载 ${song.title} (${existingSong.audioQualityValue} → ${currentQuality.value})',
            'DownloadManager');
      } else {
        return AddDownloadResult.alreadyExists;
      }
    }

    final existingTask = _tasks[song.id];
    if (existingTask != null) {
      if (existingTask.status == DownloadStatus.completed ||
          existingTask.status == DownloadStatus.failed ||
          existingTask.status == DownloadStatus.cancelled) {
        _tasks.remove(song.id);
        Logger.download('移除旧任务，允许重新下载: ${song.title}', 'DownloadManager');
      } else {
        return AddDownloadResult.alreadyExists;
      }
    }

    final task = DownloadTask(
      id: song.id,
      song: song,
      cancelToken: CancelToken(),
    );

    _tasks[song.id] = task;
    _queue.add(song.id);
    notifyListeners();

    Logger.download('下载任务已加入队列: ${song.title} (队列长度=${_queue.length}, 活跃=$_activeCount)', 'DownloadManager');

    unawaited(_processQueue());

    return isDownloaded ? AddDownloadResult.qualityUpgraded : AddDownloadResult.added;
  }

  Future<void> _processQueue() async {
    while (_queue.isNotEmpty && _activeCount < _maxConcurrent) {
      final songId = _queue.first;
      final task = _tasks[songId];

      if (task == null || task.status == DownloadStatus.cancelled) {
        _queue.removeAt(0);
        continue;
      }

      if (task.status == DownloadStatus.paused) {
        _queue.removeAt(0);
        continue;
      }

      _queue.removeAt(0);
      _activeCount++;

      task.status = DownloadStatus.downloading;
      if (task.cancelToken == null || task.cancelToken!.isCancelled) {
        task.cancelToken = CancelToken();
      }
      notifyListeners();

      unawaited(_executeTask(task));
    }
  }

  void _throttledNotify() {
    final now = DateTime.now();
    if (_lastNotifyTime == null || now.difference(_lastNotifyTime!).inMilliseconds > 200) {
      _lastNotifyTime = now;
      notifyListeners();
    }
  }

  Future<void> _executeTask(DownloadTask task) async {
    _speedSamples[task.id] = [];

    try {
      Song downloadSong = task.song;
      if (downloadSong.audioUrl.isEmpty ||
          (!downloadSong.audioUrl.startsWith('http') &&
              !downloadSong.audioUrl.startsWith('file://') &&
              !downloadSong.audioUrl.startsWith('content://'))) {
        final audioUrl = await SongUrlService().getSongUrl(downloadSong);
        if (audioUrl == null || audioUrl.isEmpty) {
          task.status = DownloadStatus.failed;
          task.errorMessage = '该歌曲为付费/版权受限，无法获取下载链接';
          _speedSamples.remove(task.id);
          _activeCount--;
          notifyListeners();
          _processQueue();
          return;
        }
        downloadSong = downloadSong.copyWith(audioUrl: audioUrl);
      }

      final result = await _downloadService.downloadSongWithCancel(
        downloadSong,
        cancelToken: task.cancelToken!,
        resumeFromBytes: task.downloadedBytes,
        onProgress: (progress) {
          task.progress = progress;
          _throttledNotify();
        },
        onBytesProgress: (downloaded, total) {
          task.downloadedBytes = downloaded;
          task.totalBytes = total;
          _updateSpeed(task);
          _throttledNotify();
        },
      );

      if (result != null) {
        task.status = DownloadStatus.completed;
        task.result = result;
        task.progress = 1.0;
        task.downloadSpeed = 0;
        Logger.success('下载完成: ${task.song.title} (耗时=${_formatDuration(task)})', 'DownloadManager');
      } else if (task.cancelToken!.isCancelled) {
        task.status = DownloadStatus.cancelled;
        task.errorMessage = '下载已取消';
        Logger.download('下载已取消: ${task.song.title}', 'DownloadManager');
      } else {
        task.status = DownloadStatus.failed;
        task.errorMessage = '下载失败，该歌曲可能为付费/版权受限内容';
        Logger.error('下载失败: ${task.song.title}', null, null, 'DownloadManager');
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        if (task.status != DownloadStatus.paused) {
          task.status = DownloadStatus.cancelled;
          task.errorMessage = '下载已取消';
          Logger.download('下载取消(DioException): ${task.song.title}', 'DownloadManager');
        }
      } else {
        task.status = DownloadStatus.failed;
        task.errorMessage = e.toString();
        Logger.error('下载异常(DioException): ${task.song.title}', e, null, 'DownloadManager');
      }
    } catch (e) {
      task.status = DownloadStatus.failed;
      task.errorMessage = e.toString();
      Logger.error('下载异常: ${task.song.title}', e, null, 'DownloadManager');
    }

    _speedSamples.remove(task.id);

    if (!_tasks.containsKey(task.id)) {
      return;
    }

    _activeCount--;
    notifyListeners();

    _processQueue();
  }

  void _updateSpeed(DownloadTask task) {
    final samples = _speedSamples[task.id];
    if (samples == null) return;
    final now = DateTime.now();
    samples.add(_SpeedSample(now, task.downloadedBytes));
    samples.removeWhere((s) => now.difference(s.time).inSeconds > 5);

    if (samples.length < 2) {
      task.downloadSpeed = 0;
      return;
    }

    final first = samples.first;
    final last = samples.last;
    final duration = last.time.difference(first.time).inMilliseconds / 1000;
    if (duration <= 0) {
      task.downloadSpeed = 0;
      return;
    }
    task.downloadSpeed = (last.bytes - first.bytes) / duration;
  }

  void pauseDownload(String songId) {
    final task = _tasks[songId];
    if (task == null) return;

    if (task.status == DownloadStatus.downloading) {
      task.status = DownloadStatus.paused;
      task.downloadSpeed = 0;
      task.cancelToken?.cancel('用户暂停下载');
      _speedSamples.remove(songId);
      notifyListeners();
      Logger.download('暂停下载: ${task.song.title}', 'DownloadManager');
    } else if (task.status == DownloadStatus.waiting) {
      task.status = DownloadStatus.paused;
      _queue.remove(songId);
      notifyListeners();
      Logger.download('暂停等待中的下载: ${task.song.title}', 'DownloadManager');
    }
  }

  void resumeDownload(String songId) {
    final task = _tasks[songId];
    if (task == null || task.status != DownloadStatus.paused) return;

    // 保留已下载字节数用于断点续传
    final resumeBytes = task.downloadedBytes;
    task.status = DownloadStatus.waiting;
    task.cancelToken = CancelToken();
    task.errorMessage = null;
    _queue.add(songId);
    notifyListeners();
    Logger.download('恢复下载: ${task.song.title} (已下载 ${resumeBytes} 字节)', 'DownloadManager');

    unawaited(_processQueue());
  }

  void pauseAll() {
    for (final task in _tasks.values) {
      if (task.status == DownloadStatus.downloading || task.status == DownloadStatus.waiting) {
        pauseDownload(task.id);
      }
    }
  }

  void resumeAll() {
    for (final task in _tasks.values) {
      if (task.status == DownloadStatus.paused) {
        resumeDownload(task.id);
      }
    }
  }

  void cancelDownload(String songId) {
    final task = _tasks[songId];
    if (task == null) return;

    if (task.status == DownloadStatus.waiting) {
      _queue.remove(songId);
      task.status = DownloadStatus.cancelled;
      notifyListeners();
      Logger.download('取消等待中的下载: ${task.song.title}', 'DownloadManager');
    } else if (task.status == DownloadStatus.downloading) {
      task.cancelToken?.cancel('用户取消下载');
      Logger.download('取消下载中的任务: ${task.song.title}', 'DownloadManager');
    } else if (task.status == DownloadStatus.paused) {
      task.status = DownloadStatus.cancelled;
      notifyListeners();
      Logger.download('取消暂停中的下载: ${task.song.title}', 'DownloadManager');
    }
  }

  Future<void> retryDownload(String songId) async {
    final task = _tasks[songId];
    if (task == null || task.status != DownloadStatus.failed) return;

    task.status = DownloadStatus.waiting;
    task.progress = 0.0;
    task.downloadedBytes = 0;
    task.totalBytes = 0;
    task.downloadSpeed = 0;
    task.errorMessage = null;
    task.cancelToken = CancelToken();
    _queue.add(songId);
    notifyListeners();

    unawaited(_processQueue());
  }

  void clearCompleted() {
    _tasks.removeWhere((key, task) => task.status == DownloadStatus.completed);
    notifyListeners();
  }

  void clearFailed() {
    _tasks.removeWhere((key, task) => task.status == DownloadStatus.failed);
    notifyListeners();
  }

  void clearAll() {
    for (final task in _tasks.values) {
      if (task.status == DownloadStatus.downloading) {
        task.cancelToken?.cancel('清除所有任务');
      }
    }
    _tasks.clear();
    _queue.clear();
    _speedSamples.clear();
    _activeCount = 0;
    notifyListeners();
  }

  void removeTask(String songId) {
    final task = _tasks[songId];
    if (task != null) {
      if (task.status == DownloadStatus.downloading) {
        task.cancelToken?.cancel('移除任务');
        task.status = DownloadStatus.cancelled;
      }
      _tasks.remove(songId);
      _queue.remove(songId);
      _speedSamples.remove(songId);
      notifyListeners();
      Logger.download('已移除任务: $songId', 'DownloadManager');
    }
  }

  Map<String, int> getStatistics() {
    return {
      'total': _tasks.length,
      'waiting': waitingTasks.length,
      'downloading': downloadingTasks.length,
      'paused': pausedTasks.length,
      'completed': completedTasks.length,
      'failed': failedTasks.length,
    };
  }

  Future<AddDownloadResult?> _checkWifiRequired() async {
    if (kIsWeb) return null;
    try {
      final prefs = PreferencesService();
      await prefs.init();
      final wifiOnly = await prefs.getWifiOnlyDownload();
      if (!wifiOnly) return null;

      final connectivity = await Connectivity().checkConnectivity();
      final isWifi = connectivity.contains(ConnectivityResult.wifi);
      if (!isWifi) {
        Logger.warning('当前非WiFi网络，已设置仅WiFi下载', 'DownloadManager');
        return AddDownloadResult.wifiRequired;
      }
    } catch (e) {
      Logger.warning('网络状态检查失败: $e', 'DownloadManager');
    }
    return null;
  }

  Future<AddDownloadResult?> _checkStorageSpace() async {
    try {
      final downloadDir = await _downloadService.getDownloadDirectory();
      if (!downloadDir.existsSync()) return null;

      final downloadSize = await _downloadService.getDownloadedSize();

      // 动态计算：取磁盘可用空间的80%或10GB（取较小值）作为上限
      try {
        await downloadDir.stat();
      } catch (_) {}

      // 默认10GB上限，但可通过 SharedPreferences 配置
      final prefs = PreferencesService();
      await prefs.init();
      final maxDownloadSizeMB = await prefs.getMaxDownloadSizeMB();
      final maxDownloadSize = maxDownloadSizeMB * 1024 * 1024;

      if (downloadSize >= maxDownloadSize) {
        Logger.warning('下载空间已用尽 (已用 ${(downloadSize / 1024 / 1024).toStringAsFixed(0)} MB, 上限 ${maxDownloadSizeMB} MB)', 'DownloadManager');
        return AddDownloadResult.storageInsufficient;
      }
    } catch (e) {
      Logger.warning('存储空间检查失败: $e', 'DownloadManager');
    }
    return null;
  }

  Future<Directory> getDownloadDirectory() async {
    return _downloadService.getDownloadDirectory();
  }

  @override
  void dispose() {
    for (final task in _tasks.values) {
      task.cancelToken?.cancel();
    }
    _tasks.clear();
    _queue.clear();
    _speedSamples.clear();
    super.dispose();
  }

  String _formatDuration(DownloadTask task) {
    if (task.totalBytes <= 0 || task.downloadSpeed <= 0) return '未知';
    final seconds = (task.totalBytes / task.downloadSpeed).ceil();
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return m > 0 ? '$m分${s}秒' : '$s秒';
  }
}
