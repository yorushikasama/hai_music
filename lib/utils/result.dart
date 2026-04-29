/// 统一结果类型，用于处理操作成功或失败的情况
///
/// 替代直接返回 null 或空列表，提供更明确的错误信息。
/// 所有 Service 层异步方法应优先使用此类型作为返回值，
/// 使调用者能够区分"无数据"和"操作失败"。
///
/// 使用示例：
/// ```dart
/// Future<Result<List<Song>>> searchSongs(String query) async {
///   try {
///     final songs = await _fetchSongs(query);
///     return Success(songs);
///   } catch (e) {
///     return Failure('搜索失败', error: e, code: ErrorCode.network);
///   }
/// }
///
/// // 调用方
/// final result = await service.searchSongs('hello');
/// result.when(
///   success: (songs) => updateUI(songs),
///   failure: (msg, error) => showError(msg),
/// );
/// ```
sealed class Result<T> {
  const Result();

  T? get value => switch (this) {
        Success<T>(value: final v) => v,
        Failure<T>() => null,
      };

  String? get errorMessage => switch (this) {
        Success<T>() => null,
        Failure<T>(message: final m) => m,
      };

  Object? get error => switch (this) {
        Success<T>() => null,
        Failure<T>(error: final e) => e,
      };

  ErrorCode? get errorCode => switch (this) {
        Success<T>() => null,
        Failure<T>(code: final c) => c,
      };

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  R when<R>({
    required R Function(T value) success,
    required R Function(String message, Object? error) failure,
  }) {
    return switch (this) {
      Success<T>(value: final v) => success(v),
      Failure<T>(message: final m, error: final e) => failure(m, e),
    };
  }
}

class Success<T> extends Result<T> {
  @override
  final T value;

  const Success(this.value);

  @override
  String toString() => 'Success($value)';
}

class Failure<T> extends Result<T> {
  final String message;
  @override
  final Object? error;
  final ErrorCode? code;

  const Failure(this.message, {this.error, this.code});

  @override
  String toString() =>
      'Failure: $message${error != null ? ' ($error)' : ''}${code != null ? ' [$code]' : ''}';
}

/// 错误码枚举，用于区分不同类型的失败原因
///
/// 调用者可根据错误码决定不同的处理策略：
/// - [network] 网络错误 → 提示用户检查网络连接
/// - [notFound] 资源不存在 → 隐藏相关UI
/// - [paymentRequired] 付费内容 → 提示购买
enum ErrorCode {
  network,
  notFound,
  paymentRequired,
}
