import 'dart:io';
import 'dart:typed_data';
import 'package:minio/minio.dart';
import 'package:path/path.dart' as path;
import '../models/storage_config.dart';

/// Cloudflare R2 存储服务（兼容 S3 API）
class R2StorageService {
  static final R2StorageService _instance = R2StorageService._internal();
  Minio? _client;
  String? _bucketName;
  bool _initialized = false;

  factory R2StorageService() => _instance;

  R2StorageService._internal();

  /// 初始化 R2 客户端
  Future<bool> initialize(StorageConfig config) async {
    if (!config.isValid) {
      print('R2 配置无效');
      return false;
    }

    try {
      // 解析 endpoint，移除 https:// 前缀
      String endpoint = config.r2Endpoint;
      if (endpoint.startsWith('https://')) {
        endpoint = endpoint.substring(8);
      } else if (endpoint.startsWith('http://')) {
        endpoint = endpoint.substring(7);
      }

      _client = Minio(
        endPoint: endpoint,
        accessKey: config.r2AccessKey,
        secretKey: config.r2SecretKey,
        useSSL: true,
        region: config.r2Region,
      );

      _bucketName = config.r2BucketName;
      _initialized = true;

      // 检查 bucket 是否存在
      await _ensureBucketExists();

      return true;
    } catch (e) {
      print('初始化 R2 失败: $e');
      _initialized = false;
      return false;
    }
  }

  /// 确保 bucket 存在
  Future<void> _ensureBucketExists() async {
    if (_client == null || _bucketName == null) return;

    try {
      final exists = await _client!.bucketExists(_bucketName!);
      if (!exists) {
        await _client!.makeBucket(_bucketName!);
        print('创建 bucket: $_bucketName');
      }
    } catch (e) {
      print('检查/创建 bucket 失败: $e');
    }
  }

  /// 检查是否已初始化
  bool get isInitialized => _initialized && _client != null && _bucketName != null;

  /// 上传文件
  Future<String?> uploadFile(File file, String objectName) async {
    if (!isInitialized) {
      print('R2 未初始化');
      return null;
    }

    try {
      final fileStream = file.openRead().map((chunk) => Uint8List.fromList(chunk));
      final fileSize = await file.length();

      await _client!.putObject(
        _bucketName!,
        objectName,
        fileStream,
        size: fileSize,
      );

      // 返回文件的公共 URL
      return getPublicUrl(objectName);
    } catch (e) {
      print('上传文件失败: $e');
      return null;
    }
  }

  /// 上传音频文件
  Future<String?> uploadAudio(File audioFile, String songId) async {
    final ext = path.extension(audioFile.path);
    final objectName = 'audio/$songId$ext';
    return await uploadFile(audioFile, objectName);
  }

  /// 上传封面图片
  Future<String?> uploadCover(File coverFile, String songId) async {
    final ext = path.extension(coverFile.path);
    final objectName = 'covers/$songId$ext';
    return await uploadFile(coverFile, objectName);
  }

  /// 下载文件
  Future<bool> downloadFile(String objectName, String savePath) async {
    if (!isInitialized) {
      print('R2 未初始化');
      return false;
    }

    try {
      final stream = await _client!.getObject(_bucketName!, objectName);
      final file = File(savePath);
      await file.create(recursive: true);
      
      final sink = file.openWrite();
      await stream.pipe(sink);
      await sink.close();

      return true;
    } catch (e) {
      print('下载文件失败: $e');
      return false;
    }
  }

  /// 删除文件
  Future<bool> deleteFile(String objectName) async {
    if (!isInitialized) {
      print('R2 未初始化');
      return false;
    }

    try {
      await _client!.removeObject(_bucketName!, objectName);
      return true;
    } catch (e) {
      print('删除文件失败: $e');
      return false;
    }
  }

  /// 删除歌曲相关的所有文件
  Future<bool> deleteSongFiles(String songId) async {
    if (!isInitialized) return false;

    try {
      // 列出该歌曲的所有文件
      final audioPrefix = 'audio/$songId';
      final coverPrefix = 'covers/$songId';

      // 删除音频文件
      await _deleteFilesWithPrefix(audioPrefix);
      // 删除封面文件
      await _deleteFilesWithPrefix(coverPrefix);

      return true;
    } catch (e) {
      print('删除歌曲文件失败: $e');
      return false;
    }
  }

  /// 删除指定前缀的所有文件
  Future<void> _deleteFilesWithPrefix(String prefix) async {
    if (_client == null || _bucketName == null) return;

    try {
      final objectsStream = _client!.listObjects(
        _bucketName!,
        prefix: prefix,
      );

      await for (final obj in objectsStream) {
        // minio 3.5.8 使用 objects 属性
        if (obj.objects != null) {
          for (final item in obj.objects!) {
            if (item.key != null) {
              await _client!.removeObject(_bucketName!, item.key!);
            }
          }
        }
      }
    } catch (e) {
      print('删除前缀文件失败: $e');
    }
  }

  /// 获取文件的公共 URL
  String getPublicUrl(String objectName) {
    if (_client == null || _bucketName == null) return '';
    
    // R2 的公共 URL 格式
    final endpoint = _client!.endPoint;
    return 'https://$endpoint/$_bucketName/$objectName';
  }

  /// 检查文件是否存在
  Future<bool> fileExists(String objectName) async {
    if (!isInitialized) return false;

    try {
      await _client!.statObject(_bucketName!, objectName);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 获取文件大小
  Future<int?> getFileSize(String objectName) async {
    if (!isInitialized) return null;

    try {
      final stat = await _client!.statObject(_bucketName!, objectName);
      return stat.size;
    } catch (e) {
      print('获取文件大小失败: $e');
      return null;
    }
  }

  /// 关闭连接
  void dispose() {
    _client = null;
    _bucketName = null;
    _initialized = false;
  }
}
