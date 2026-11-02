/// Base contract cho các UseCase trong tầng Domain.
/// [T] là kiểu dữ liệu trả về, [Params] là tham số đầu vào.
abstract class UseCase<T, Params> {
  Future<T> call(Params params);
}

/// Dùng khi UseCase không cần tham số đầu vào.
class NoParams {
  const NoParams();
}
