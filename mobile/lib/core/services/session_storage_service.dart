import 'session_storage_stub.dart'
    if (dart.library.js_interop) 'session_storage_web.dart'
    if (dart.library.io) 'session_storage_io.dart';

/// Dịch vụ lưu trữ phiên đăng nhập (JWT Token + User JSON) bền vững khi Reload trình duyệt (Web localStorage)
/// hoặc khởi động lại ứng dụng (Mobile/Desktop File).
class SessionStorageService {
  static const String _tokenKey = 'barbersmart_access_token';
  static const String _userKey = 'barbersmart_current_user';

  const SessionStorageService();

  void saveSession({
    required String? token,
    required String userJson,
  }) {
    if (token != null && token.isNotEmpty) {
      platformWriteStorage(_tokenKey, token);
    }
    platformWriteStorage(_userKey, userJson);
  }

  String? readToken() => platformReadStorage(_tokenKey);

  String? readUserJson() => platformReadStorage(_userKey);

  void clearSession() {
    platformRemoveStorage(_tokenKey);
    platformRemoveStorage(_userKey);
  }
}
