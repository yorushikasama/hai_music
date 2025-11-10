import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/song.dart';
import '../models/downloaded_song.dart';
import 'download_service.dart';
import '../utils/logger.dart';

/// 下载任务状态
enum DownloadStatus {
  waiting,    // 等待中
  downloading, // 下载中
  completed,   // 已完成
  failed,      // 失败
  cancelled,   // 已取消
}

/// 下载任务
class DownloadTask {
  final String id;
  final Song song;
  DownloadStatus status;
  double progress;
  String? errorMessage;
  DownloadedSong? result;

  DownloadTask({
    required this.id,
    required this.song,
    this.status = DownloadStatus.waiting,
    this.progress = 0.0,
    this.errorMessage,
    this.result,
  });
}

/// 下载管理器 - 支持后台下载和进度追踪
class DownloadManager with ChangeNotifier {
  static final DownloadManager _instance = DownloadManager._internal();
  factory DownloadManager() => _instance;
  DownloadManager._internal();

  final DownloadService _downloadService = DownloadService();
  final Map<String, DownloadTask> _tasks = {};
  final List<String> _queue = []; // 下载队列
  bool _isProcessing = false;

  /// 获取所有下载任务
  List<DownloadTask> get tasks => _tasks.values.toList();

  /// 获取正在下载的任务
  List<DownloadTask> get downloadingTasks => 
      _tasks.values.where((t) => t.status == DownloadStatus.downloading).toList();

  /// 获取等待中的任务
  List<DownloadTask> get waitingTasks => 
      _tasks.values.where((t) => t.status == DownloadStatus.waiting).toList();

  /// 获取已完成的任务
  List<DownloadTask> get completedTasks => 
      _tasks.values.where((t) => t.status == DownloadStatus.completed).toList();

  /// 获取失败的任务
  List<DownloadTask> get failedTasks => 
      _tasks.values.where((t) => t.status == DownloadStatus.failed).toList();

  /// 获取特定任务
  DownloadTask? getTask(String songId) => _tasks[songId];

  /// 初始化
  Future<void> init() async {
    await _downloadService.init();
  }

  /// 添加下载任务
  Future<bool> addDownload(Song song) async {
    // 检查是否已下载
    final isDownloaded = await _downloadService.isDownloaded(song.id);
    if (isDownloaded) {
      return false; // 已下载
    }

    // 检查是否已在任务列表中（排除已完成和失败的任务）
    final existingTask = _tasks[song.id];
    if (existingTask != null) {
      // 如果是已完成或失败的任务，移除旧任务，允许重新下载
      if (existingTask.status == DownloadStatus.completed || 
          existingTask.status == DownloadStatus.failed) {
        _tasks.remove(song.id);
        Logger.download('移除旧任务，允许重新下载: ${song.title}', 'DownloadManager');
      } else {
        // 正在下载或等待中的任务，不允许重复添加
        return false;
      }
    }

    // 创建新任务
    final task = DownloadTask(
      id: song.id,
      song: song,
      status: DownloadStatus.waiting,
    );

    _tasks[song.id] = task;
    _queue.add(song.id);
    notifyListeners();

    // 开始处理队列
    _processQueue();

    return true;
  }

  /// 处理下载队列
  Future<void> _processQueue() async {
    if (_isProcessing || _queue.isEmpty) return;

    _isProcessing = true;

    while (_queue.isNotEmpty) {
      final songId = _queue.first;
      final task = _tasks[songId];

      if (task == null) {
        _queue.removeAt(0);
        continue;
      }

      // 更新状态为下载中
      task.status = DownloadStatus.downloading;
      task.progress = 0.0;
      notifyListeners();

      try {
        // 执行下载
        final result = await _downloadService.downloadSong(
          task.song,
          onProgress: (progress) {
            task.progress = progress;
            notifyListeners();
          },
        );

        if (result != null) {
          task.status = DownloadStatus.completed;
          task.result = result;
          task.progress = 1.0;
        } else {
          task.status = DownloadStatus.failed;
          task.errorMessage = '下载失败';
        }
      } catch (e) {
        task.status = DownloadStatus.failed;
        task.errorMessage = e.toString();
      }

      notifyListeners();
      _queue.removeAt(0);

      // 短暂延迟，避免过快请求
      await Future.delayed(const Duration(milliseconds: 500));
    }

    _isProcessing = false;
  }

  /// 取消下载
  void cancelDownload(String songId) {
    final task = _tasks[songId];
    if (task == null) return;

    if (task.status == DownloadStatus.waiting) {
      _queue.remove(songId);
      task.status = DownloadStatus.cancelled;
      notifyListeners();
    }
    // 注意：正在下载的任务暂不支持取消（需要 Dio CancelToken）
  }

  /// 重试失败的下载
  Future<void> retryDownload(String songId) async {
    final task = _tasks[songId];
    if (task == null || task.status != DownloadStatus.failed) return;

    task.status = DownloadStatus.waiting;
    task.progress = 0.0;
    task.errorMessage = null;
    _queue.add(songId);
    notifyListeners();

    _processQueue();
  }

  /// 清除已完成的任务
  void clearCompleted() {
    _tasks.removeWhere((key, task) => task.status == DownloadStatus.completed);
    notifyListeners();
  }

  /// 清除失败的任务
  void clearFailed() {
    _tasks.removeWhere((key, task) => task.status == DownloadStatus.failed);
    notifyListeners();
  }

  /// 清除所有任务
  void clearAll() {
    _tasks.clear();
    _queue.clear();
    notifyListeners();
  }

  /// 移除单个任务（用于删除已下载的歌曲后清理任务列表）
  void removeTask(String songId) {
    if (_tasks.containsKey(songId)) {
      _tasks.remove(songId);
      _queue.remove(songId);
      notifyListeners();
      Logger.download('已移除任务: $songId', 'DownloadManager');
    }
  }

  /// 获取下载统计
  Map<String, int> getStatistics() {
    return {
      'total': _tasks.length,
      'waiting': waitingTasks.length,
      'downloading': downloadingTasks.length,
      'completed': completedTasks.length,
      'failed': failedTasks.length,
    };
  }
}
