/// Base contract cho các UseCase trong tầng Domain.
/// [Type] là kiểu dữ liệu trả về, [Params] là tham số đầu vào.
abstract class UseCase<Type, Params> {
  Future<Type> call(Params params);
}

/// Dùng khi UseCase không cần tham số đầu vào.
class NoParams {
  const NoParams();
}

