import 'package:dio/dio.dart';
import '../utils/logger.dart';

/// Dio 客户端单例
/// 提供统一的网络请求配置和拦截器
class DioClient {
  static final DioClient _instance = DioClient._internal();
  late final Dio dio;

  factory DioClient() => _instance;

  // 用于测试的getter
  Dio get dioInstance => dio;

  DioClient._internal() {
    dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Accept': 'application/json',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      },
    ));

    // 添加响应拦截器
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        Logger.debug('发送请求: ${options.uri}', 'DioClient');
        return handler.next(options);
      },
      onResponse: (response, handler) {
        Logger.debug('收到响应: ${response.statusCode}', 'DioClient');
        return handler.next(response);
      },
      onError: (DioException e, handler) {
        Logger.error('网络请求错误', e, null, 'DioClient');
        return handler.next(e);
      },
    ));
  }

  /// GET 请求
  Future<Response> get(
    String url,
    {
      Map<String, dynamic>? queryParameters,
      Options? options,
      int retryCount = 3,
      Duration retryDelay = const Duration(milliseconds: 1000),
    }
  ) async {
    int attempts = 0;
    while (attempts < retryCount) {
      try {
        attempts++;
        return await dio.get(
          url,
          queryParameters: queryParameters,
          options: options,
        );
      } catch (e) {
        if (e is DioException) {
          // 只对网络错误进行重试
          if (e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout ||
              e.type == DioExceptionType.sendTimeout ||
              e.type == DioExceptionType.unknown) {
            if (attempts < retryCount) {
              Logger.warning('网络请求失败，正在重试 ($attempts/$retryCount)...', 'DioClient');
              await Future.delayed(retryDelay);
              continue;
            }
          }
        }
        rethrow;
      }
    }
    // 理论上不会到达这里，但为了类型安全
    throw Exception('网络请求失败');
  }

  /// POST 请求
  Future<Response> post(
    String url,
    {
      dynamic data,
      Map<String, dynamic>? queryParameters,
      Options? options,
      int retryCount = 3,
      Duration retryDelay = const Duration(milliseconds: 1000),
    }
  ) async {
    int attempts = 0;
    while (attempts < retryCount) {
      try {
        attempts++;
        return await dio.post(
          url,
          data: data,
          queryParameters: queryParameters,
          options: options,
        );
      } catch (e) {
        if (e is DioException) {
          // 只对网络错误进行重试
          if (e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout ||
              e.type == DioExceptionType.sendTimeout ||
              e.type == DioExceptionType.unknown) {
            if (attempts < retryCount) {
              Logger.warning('网络请求失败，正在重试 ($attempts/$retryCount)...', 'DioClient');
              await Future.delayed(retryDelay);
              continue;
            }
          }
        }
        rethrow;
      }
    }
    // 理论上不会到达这里，但为了类型安全
    throw Exception('网络请求失败');
  }
}
