import 'package:dio/dio.dart';
import '../../utils/logger.dart';

/// HTTP 客户端封装
///
/// 基于 Dio 的全局单例 HTTP 客户端，提供统一的网络请求能力。
/// 内置指数退避重试(默认3次)、超时配置(连接10s/收发30s)和错误拦截。
/// 所有需要网络请求的服务都应通过此类获取 Dio 实例。
class DioClient {
  static final DioClient _instance = DioClient._internal();
  late final Dio dio;

  factory DioClient() => _instance;

  DioClient._internal() {
    dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {
        'Accept': 'application/json',
        'User-Agent': 'HaiMusic/2.0 (Flutter; Mobile)',
      },
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        return handler.next(options);
      },
      onResponse: (response, handler) {
        return handler.next(response);
      },
      onError: (DioException e, handler) {
        Logger.error('网络请求错误', e, null, 'DioClient');
        return handler.next(e);
      },
    ));
  }

  Future<Response<dynamic>> get(
    String url, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    int retryCount = 3,
    Duration retryDelay = const Duration(milliseconds: 1000),
  }) async {
    return _requestWithRetry(
      () => dio.get(url, queryParameters: queryParameters, options: options),
      retryCount: retryCount,
      retryDelay: retryDelay,
    );
  }

  Future<Response<dynamic>> _requestWithRetry(
    Future<Response<dynamic>> Function() request, {
    int retryCount = 3,
    Duration retryDelay = const Duration(milliseconds: 1000),
  }) async {
    int attempts = 0;
    DioException? lastException;
    while (attempts < retryCount) {
      try {
        attempts++;
        return await request();
      } on DioException catch (e) {
        lastException = e;
        if (shouldNotRetry(e)) {
          rethrow;
        }

        if (isRetryableError(e) && attempts < retryCount) {
          final rawDelay = retryDelay * (1 << (attempts - 1));
          final delay = rawDelay > const Duration(seconds: 30)
              ? const Duration(seconds: 30)
              : rawDelay;
          Logger.warning(
            '网络请求失败，${delay.inMilliseconds}ms 后重试 ($attempts/$retryCount)...',
            'DioClient',
          );
          await Future<void>.delayed(delay);
          continue;
        }
        rethrow;
      }
    }
    throw lastException ?? DioException(requestOptions: RequestOptions(), error: '网络请求失败（已重试 $retryCount 次）');
  }

  bool isRetryableError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        return true;
      case DioExceptionType.badCertificate:
      case DioExceptionType.badResponse:
      case DioExceptionType.cancel:
        return false;
    }
  }

  bool shouldNotRetry(DioException e) {
    if (e.type == DioExceptionType.badResponse && e.response != null) {
      final statusCode = e.response!.statusCode;
      if (statusCode != null && statusCode >= 400 && statusCode < 500) {
        return true;
      }
    }
    return false;
  }
}
