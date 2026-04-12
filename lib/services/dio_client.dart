import 'package:dio/dio.dart';
import '../utils/logger.dart';

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
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      },
    ));

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
    while (attempts < retryCount) {
      try {
        attempts++;
        return await request();
      } on DioException catch (e) {
        if (shouldNotRetry(e)) {
          rethrow;
        }

        if (isRetryableError(e) && attempts < retryCount) {
          final delay = retryDelay * (1 << (attempts - 1));
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
    throw DioException(requestOptions: RequestOptions(), error: '网络请求失败（已重试 $retryCount 次）');
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
