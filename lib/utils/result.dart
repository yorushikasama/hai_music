/// 结果类，用于处理操作成功或失败的情况
/// 替代直接返回 null 或空列表，提供更明确的错误信息
sealed class Result<T> {
  const Result();

  /// 获取成功时的值，失败时返回 null
  T? get value => switch (this) {
    Success<T>(value: final v) => v,
    Failure<T>() => null,
  };

  /// 获取失败时的错误信息，成功时返回 null
  String? get errorMessage => switch (this) {
    Success<T>() => null,
    Failure<T>(message: final m) => m,
  };

  /// 是否成功
  bool get isSuccess => this is Success<T>;

  /// 是否失败
  bool get isFailure => this is Failure<T>;

  /// 映射成功值
  Result<R> map<R>(R Function(T value) transform) {
    return switch (this) {
      Success<T>(value: final v) => Success(transform(v)),
      Failure<T>(message: final m, error: final e) => Failure(m, error: e),
    };
  }

  /// 处理成功和失败两种情况
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

/// 成功结果
class Success<T> extends Result<T> {
  @override
  final T value;

  const Success(this.value);

  @override
  String toString() => 'Success($value)';
}

/// 失败结果
class Failure<T> extends Result<T> {
  final String message;
  final Object? error;

  const Failure(this.message, {this.error});

  @override
  String toString() => 'Failure: $message${error != null ? ' ($error)' : ''}';
}
