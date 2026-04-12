import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/downloaded_song.dart';
import '../models/song.dart';
import '../utils/logger.dart';
import 'download_service.dart';

enum DownloadStatus {
  waiting,
  downloading,
  completed,
  failed,
  cancelled,
}

class DownloadTask {
  final String id;
  final Song song;
  DownloadStatus status;
  double progress;
  String? errorMessage;
  DownloadedSong? result;
  CancelToken? cancelToken;

  DownloadTask({
    required this.id,
    required this.song,
    this.status = DownloadStatus.waiting,
    this.progress = 0.0,
    this.errorMessage,
    this.result,
    this.cancelToken,
  });
}

class DownloadManager with ChangeNotifier {
  static final DownloadManager _instance = DownloadManager._internal();
  factory DownloadManager() => _instance;
  DownloadManager._internal();

  final DownloadService _downloadService = DownloadService();
  final Map<String, DownloadTask> _tasks = {};
  final List<String> _queue = [];
  bool _isProcessing = false;

  List<DownloadTask> get tasks => _tasks.values.toList();

  List<DownloadTask> get downloadingTasks =>
      _tasks.values.where((t) => t.status == DownloadStatus.downloading).toList();

  List<DownloadTask> get waitingTasks =>
      _tasks.values.where((t) => t.status == DownloadStatus.waiting).toList();

  List<DownloadTask> get completedTasks =>
      _tasks.values.where((t) => t.status == DownloadStatus.completed).toList();

  List<DownloadTask> get failedTasks =>
      _tasks.values.where((t) => t.status == DownloadStatus.failed).toList();

  DownloadTask? getTask(String songId) => _tasks[songId];

  Future<void> init() async {
    await _downloadService.init();
  }

  Future<bool> addDownload(Song song) async {
    final isDownloaded = await _downloadService.isDownloaded(song.id);
    if (isDownloaded) {
      return false;
    }

    final existingTask = _tasks[song.id];
    if (existingTask != null) {
      if (existingTask.status == DownloadStatus.completed ||
          existingTask.status == DownloadStatus.failed ||
          existingTask.status == DownloadStatus.cancelled) {
        _tasks.remove(song.id);
        Logger.download('移除旧任务，允许重新下载: ${song.title}', 'DownloadManager');
      } else {
        return false;
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

    unawaited(_processQueue());

    return true;
  }

  Future<void> _processQueue() async {
    if (_isProcessing || _queue.isEmpty) return;

    _isProcessing = true;

    while (_queue.isNotEmpty) {
      final songId = _queue.first;
      final task = _tasks[songId];

      if (task == null || task.status == DownloadStatus.cancelled) {
        _queue.removeAt(0);
        continue;
      }

      task.status = DownloadStatus.downloading;
      task.progress = 0.0;
      if (task.cancelToken == null || task.cancelToken!.isCancelled) {
        task.cancelToken = CancelToken();
      }
      notifyListeners();

      try {
        final result = await _downloadService.downloadSongWithCancel(
          task.song,
          cancelToken: task.cancelToken!,
          onProgress: (progress) {
            task.progress = progress;
            notifyListeners();
          },
        );

        if (task.cancelToken!.isCancelled) {
          task.status = DownloadStatus.cancelled;
          task.errorMessage = '下载已取消';
        } else if (result != null) {
          task.status = DownloadStatus.completed;
          task.result = result;
          task.progress = 1.0;
        } else {
          task.status = DownloadStatus.failed;
          task.errorMessage = '下载失败';
        }
      } on DioException catch (e) {
        if (e.type == DioExceptionType.cancel) {
          task.status = DownloadStatus.cancelled;
          task.errorMessage = '下载已取消';
        } else {
          task.status = DownloadStatus.failed;
          task.errorMessage = e.toString();
        }
      } catch (e) {
        task.status = DownloadStatus.failed;
        task.errorMessage = e.toString();
      }

      notifyListeners();
      _queue.removeAt(0);

      await Future<void>.delayed(const Duration(milliseconds: 500));
    }

    _isProcessing = false;
  }

  void cancelDownload(String songId) {
    final task = _tasks[songId];
    if (task == null) return;

    if (task.status == DownloadStatus.waiting) {
      _queue.remove(songId);
      task.status = DownloadStatus.cancelled;
      notifyListeners();
    } else if (task.status == DownloadStatus.downloading) {
      task.cancelToken?.cancel('用户取消下载');
    }
  }

  Future<void> retryDownload(String songId) async {
    final task = _tasks[songId];
    if (task == null || task.status != DownloadStatus.failed) return;

    task.status = DownloadStatus.waiting;
    task.progress = 0.0;
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
    notifyListeners();
  }

  void removeTask(String songId) {
    final task = _tasks[songId];
    if (task != null) {
      if (task.status == DownloadStatus.downloading) {
        task.cancelToken?.cancel('移除任务');
      }
      _tasks.remove(songId);
      _queue.remove(songId);
      notifyListeners();
      Logger.download('已移除任务: $songId', 'DownloadManager');
    }
  }

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
