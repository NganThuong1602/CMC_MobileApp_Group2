import '../error/failures.dart';

/// Kiểu trả về chuẩn Clean Architecture cho Repository & UseCase (thay thế Either).
class Result<T> {
  final T? data;
  final Failure? failure;

  const Result._({this.data, this.failure});

  factory Result.success(T data) => Result._(data: data);
  factory Result.failure(Failure failure) => Result._(failure: failure);

  bool get isSuccess => failure == null;
  bool get isFailure => failure != null;

  R fold<R>({
    required R Function(Failure failure) onFailure,
    required R Function(T data) onSuccess,
  }) {
    if (failure != null) {
      return onFailure(failure!);
    }
    return onSuccess(data as T);
  }
}

