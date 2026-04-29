import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

import '../../utils/logger.dart';

/// Android 平台通道服务
///
/// 通过 MethodChannel(com.hai.music/media)与 Android 原生层通信，
/// 提供 MediaStore 扫描通知、文件删除、封面提取、元数据读取和文件保存等能力。
/// 主要用于解决 Android 16+ Scoped Storage 限制下 Dart File API 无法操作公共目录的问题。
class MediaScanService {
  static final MediaScanService _instance = MediaScanService._internal();
  factory MediaScanService() => _instance;
  MediaScanService._internal();

  static const _channel = MethodChannel('com.hai.music/media');

  Future<bool> scanFile(String filePath) async {
    if (kIsWeb || !Platform.isAndroid) return false;

    try {
      final result = await _channel.invokeMethod<bool>('scanFile', {
        'path': filePath,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      Logger.warning('MediaStore 扫描通知失败: ${e.message}', 'MediaScan');
      return false;
    } catch (e) {
      Logger.warning('MediaStore 扫描通知异常: $e', 'MediaScan');
      return false;
    }
  }

  Future<bool> deleteFile(String filePath) async {
    if (kIsWeb || !Platform.isAndroid) return false;

    try {
      final result = await _channel.invokeMethod<bool>('deleteFile', {
        'path': filePath,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      Logger.warning('平台通道删除文件失败: ${e.message}', 'MediaScan');
      return false;
    } catch (e) {
      Logger.warning('平台通道删除文件异常: $e', 'MediaScan');
      return false;
    }
  }

  Future<bool> deleteFiles(List<String> filePaths) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    if (filePaths.isEmpty) return true;

    try {
      final result = await _channel.invokeMethod<bool>('deleteFiles', {
        'paths': filePaths,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      Logger.warning('平台通道批量删除文件失败: ${e.message}', 'MediaScan');
      return false;
    } catch (e) {
      Logger.warning('平台通道批量删除文件异常: $e', 'MediaScan');
      return false;
    }
  }

  Future<String?> extractCover(String audioPath, String savePath) async {
    if (kIsWeb || !Platform.isAndroid) return null;

    try {
      final result = await _channel.invokeMethod<String>('extractCover', {
        'path': audioPath,
        'savePath': savePath,
      });
      if (result != null) {
        Logger.info('平台通道提取封面成功: $audioPath -> $savePath', 'MediaScan');
      }
      return result;
    } on PlatformException catch (e) {
      Logger.warning('平台通道提取封面失败: ${e.message}', 'MediaScan');
      return null;
    } catch (e) {
      Logger.warning('平台通道提取封面异常: $e', 'MediaScan');
      return null;
    }
  }

  Future<Map<String, String>?> getMetadata(String audioPath) async {
    if (kIsWeb || !Platform.isAndroid) return null;

    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>('getMetadata', {
        'path': audioPath,
      });
      if (result != null) {
        return result.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
      }
      return null;
    } on PlatformException catch (e) {
      Logger.warning('平台通道读取元数据失败: ${e.message}', 'MediaScan');
      return null;
    } catch (e) {
      Logger.warning('平台通道读取元数据异常: $e', 'MediaScan');
      return null;
    }
  }

  Future<String?> saveFile(String targetPath, Uint8List bytes) async {
    if (kIsWeb || !Platform.isAndroid) return null;

    try {
      final result = await _channel.invokeMethod<String>('saveFile', {
        'targetPath': targetPath,
        'bytes': bytes,
      });
      if (result != null) {
        Logger.info('平台通道保存文件成功: $targetPath', 'MediaScan');
      }
      return result;
    } on PlatformException catch (e) {
      Logger.warning('平台通道保存文件失败: ${e.message}', 'MediaScan');
      return null;
    } catch (e) {
      Logger.warning('平台通道保存文件异常: $e', 'MediaScan');
      return null;
    }
  }

  /// 检查是否拥有管理所有文件权限（MANAGE_EXTERNAL_STORAGE）
  /// Android 11+ 需要此权限才能静默删除公共目录文件和完整读取封面图片
  Future<bool> checkManageStoragePermission() async {
    if (kIsWeb || !Platform.isAndroid) return true;

    try {
      final result = await _channel.invokeMethod<bool>('checkManageStoragePermission');
      return result ?? false;
    } on PlatformException catch (e) {
      Logger.warning('检查管理存储权限失败: ${e.message}', 'MediaScan');
      return false;
    } catch (e) {
      Logger.warning('检查管理存储权限异常: $e', 'MediaScan');
      return false;
    }
  }

  /// 请求管理所有文件权限，会打开系统设置页面
  /// 返回 false 表示需要用户在设置中手动授权
  Future<bool> requestManageStoragePermission() async {
    if (kIsWeb || !Platform.isAndroid) return true;

    try {
      final result = await _channel.invokeMethod<bool>('requestManageStoragePermission');
      return result ?? false;
    } on PlatformException catch (e) {
      Logger.warning('请求管理存储权限失败: ${e.message}', 'MediaScan');
      return false;
    } catch (e) {
      Logger.warning('请求管理存储权限异常: $e', 'MediaScan');
      return false;
    }
  }
}
