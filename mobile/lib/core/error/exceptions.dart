/// Các Exception được ném ra từ tầng Data (DataSources).
class ServerException implements Exception {
  final String message;
  const ServerException([this.message = 'Server Exception']);
}

class CacheException implements Exception {
  final String message;
  const CacheException([this.message = 'Cache Exception']);
}

class ValidationException implements Exception {
  final String message;
  const ValidationException(this.message);
}

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
}

class ConflictException implements Exception {
  final String message;
  const ConflictException(this.message);
}
