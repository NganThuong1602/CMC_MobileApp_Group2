import 'package:dio/dio.dart';
import '../constants/app_constants.dart';

/// Dio RESTful API Client đính kèm JWT Token tự động khi gọi NestJS Backend.
class ApiClient {
  final Dio dio;
  String? _accessToken;

  ApiClient({String? baseUrl})
      : dio = Dio(
          BaseOptions(
            baseUrl: baseUrl ?? AppConstants.apiBaseUrl,
            connectTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 12),
            headers: {
              'Content-Type': 'application/json',
              // Bỏ qua trang cảnh báo mặc định của Ngrok Free Domain khi gửi request API
              'ngrok-skip-browser-warning': 'true',
            },
          ),
        ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_accessToken != null && _accessToken!.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $_accessToken';
          }
          handler.next(options);
        },
      ),
    );
  }

  void setAccessToken(String? token) {
    _accessToken = token;
  }

  String? get accessToken => _accessToken;
}
