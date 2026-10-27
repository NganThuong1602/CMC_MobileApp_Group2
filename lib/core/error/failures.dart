/// Base class cho tất cả các lỗi ở tầng Domain & Presentation.
abstract class Failure {
  final String message;

  const Failure(this.message);
}

class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Lỗi kết nối máy chủ']);
}

class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Lỗi đọc/ghi dữ liệu cục bộ']);
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Không có kết nối mạng']);
}

