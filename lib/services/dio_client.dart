import 'package:dio/dio.dart';

/// Dio 客户端单例
/// 提供统一的网络请求配置和拦截器
class DioClient {
  static final DioClient _instance = DioClient._internal();
  late final Dio dio;

  factory DioClient() => _instance;

  DioClient._internal() {
    dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Accept': 'application/json',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      },
    ));

    // 添加拦截器(仅在debug模式下打印日志)
    // dio.interceptors.add(InterceptorsWrapper(
    //   onRequest: (options, handler) {
    //     return handler.next(options);
    //   },
    //   onResponse: (response, handler) {
    //     return handler.next(response);
    //   },
    //   onError: (error, handler) {
    //     return handler.next(error);
    //   },
    // ));
  }

  /// GET 请求
  Future<Response> get(
    String url, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await dio.get(
        url,
        queryParameters: queryParameters,
        options: options,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// POST 请求
  Future<Response> post(
    String url, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await dio.post(
        url,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } catch (e) {
      rethrow;
    }
  }
}
