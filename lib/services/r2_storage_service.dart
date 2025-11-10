import 'dart:io';
import 'dart:typed_data';
import 'package:minio/minio.dart';
import 'package:path/path.dart' as path;
import '../models/storage_config.dart';
import '../utils/logger.dart';

/// Cloudflare R2 存储服务（兼容 S3 API）
class R2StorageService {
  static final R2StorageService _instance = R2StorageService._internal();
  Minio? _client;
  String? _bucketName;
  String? _customDomain; // 自定义域名
  bool _initialized = false;

  factory R2StorageService() => _instance;

  R2StorageService._internal();

  /// 初始化 R2 客户端
  Future<bool> initialize(StorageConfig config) async {
    if (!config.isValid) {
      Logger.warning('R2 配置无效', 'R2Storage');
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
      _customDomain = config.r2CustomDomain; // 保存自定义域名
      _initialized = true;
      
      // 打印配置信息
      if (_customDomain != null && _customDomain!.isNotEmpty) {
        Logger.info('R2 自定义域名: $_customDomain', 'R2Storage');
      } else {
        Logger.warning('未配置自定义域名，将使用预签名 URL', 'R2Storage');
      }

      // 检查 bucket 是否存在
      await _ensureBucketExists();

      return true;
    } catch (e) {
      Logger.error('初始化 R2 失败', e, null, 'R2Storage');
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
        Logger.info('创建 bucket: $_bucketName', 'R2Storage');
      }
    } catch (e) {
      Logger.error('检查/创建 bucket 失败', e, null, 'R2Storage');
    }
  }

  /// 检查是否已初始化
  bool get isInitialized => _initialized && _client != null && _bucketName != null;

  /// 上传文件
  /// 如果配置了自定义域名，直接使用公开 URL；否则使用预签名 URL
  Future<String?> uploadFile(File file, String objectName) async {
    if (!isInitialized) {
      Logger.warning('R2 未初始化', 'R2Storage');
      return null;
    }

    try {
      final fileStream = file.openRead().map((chunk) => Uint8List.fromList(chunk));
      final fileSize = await file.length();

      Logger.info('上传文件到 R2: $objectName (${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB)', 'R2Storage');

      await _client!.putObject(
        _bucketName!,
        objectName,
        fileStream,
        size: fileSize,
      );

      Logger.success('文件上传成功', 'R2Storage');

      // 如果配置了自定义域名，直接返回公开 URL（永久有效）
      if (_customDomain != null && _customDomain!.isNotEmpty) {
        final publicUrl = getPublicUrl(objectName);
        Logger.info('使用自定义域名 URL（永久有效）', 'R2Storage');
        return publicUrl;
      }

      // 否则使用预签名 URL（7天有效）
      Logger.warning('未配置自定义域名，使用预签名 URL（7天有效）', 'R2Storage');
      final presignedUrl = await getPresignedUrl(objectName);
      if (presignedUrl != null) {
        return presignedUrl;
      }

      // 最后回退到公开 URL
      Logger.warning('预签名URL生成失败，回退到公开URL', 'R2Storage');
      return getPublicUrl(objectName);
    } catch (e) {
      Logger.error('上传文件失败', e, null, 'R2Storage');
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
      Logger.warning('R2 未初始化', 'R2Storage');
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
      Logger.error('下载文件失败', e, null, 'R2Storage');
      return false;
    }
  }

  /// 删除文件
  Future<bool> deleteFile(String objectName) async {
    if (!isInitialized) {
      Logger.warning('R2 未初始化', 'R2Storage');
      return false;
    }

    try {
      await _client!.removeObject(_bucketName!, objectName);
      return true;
    } catch (e) {
      Logger.error('删除文件失败', e, null, 'R2Storage');
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
      Logger.error('删除歌曲文件失败', e, null, 'R2Storage');
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
        // 🔧 优化:移除不必要的 null 检查和 ! 操作符
        // minio 3.5.8 使用 objects 属性
        for (final item in obj.objects) {
          if (item.key != null) {
            await _client!.removeObject(_bucketName!, item.key!);
          }
        }
      }
    } catch (e) {
      Logger.error('删除前缀文件失败', e, null, 'R2Storage');
    }
  }

  /// 获取文件的公共 URL
  /// 优先级：自定义域名 > R2.dev > S3 格式
  String getPublicUrl(String objectName) {
    if (_client == null || _bucketName == null) return '';
    
    // 优先使用自定义域名（推荐）
    if (_customDomain != null && _customDomain!.isNotEmpty) {
      Logger.info('使用自定义域名: https://$_customDomain/$objectName', 'R2Storage');
      return 'https://$_customDomain/$objectName';
    }
    
    final endpoint = _client!.endPoint;
    
    // 尝试使用 R2.dev 格式
    if (endpoint.contains('r2.cloudflarestorage.com')) {
      final accountId = endpoint.split('.')[0];
      return 'https://$_bucketName.$accountId.r2.dev/$objectName';
    }
    
    // 回退到标准 S3 格式（需要公开访问权限）
    return 'https://$endpoint/$_bucketName/$objectName';
  }
  
  /// 生成预签名 URL（临时访问链接）
  /// [objectName] 对象名称
  /// [expirySeconds] 过期时间（秒），默认7天
  Future<String?> getPresignedUrl(String objectName, {int expirySeconds = 604800}) async {
    if (!isInitialized) return null;
    
    try {
      // 使用 Minio 客户端生成预签名 URL
      final url = await _client!.presignedGetObject(
        _bucketName!,
        objectName,
        expires: expirySeconds,
      );
      Logger.success('生成预签名URL: $url', 'R2Storage');
      return url;
    } catch (e) {
      Logger.error('生成预签名URL失败', e, null, 'R2Storage');
      return null;
    }
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
      Logger.error('获取文件大小失败', e, null, 'R2Storage');
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
