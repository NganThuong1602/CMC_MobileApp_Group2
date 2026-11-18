import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Handler chạy nền khi ứng dụng Android ở trạng thái background/terminated.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (_) {}
}

/// Quản lý vòng đời Firebase Cloud Messaging (FCM) trên Android:
/// - Khởi tạo Firebase từ `google-services.json` (bỏ qua an toàn trên Web/Desktop).
/// - Xin quyền thông báo (Android 13+), lấy và đồng bộ FCM Token lên Backend.
/// - Phát sự kiện khi nhận Push Notification lúc mở app hoặc khi người dùng bấm mở thông báo.
class FcmService {
  bool _initialized = false;
  String? _currentToken;
  RemoteMessage? _pendingInitialMessage;
  Future<void> Function(String token, String platform)? _tokenSyncHandler;

  final _foregroundMessageCtrl = StreamController<RemoteMessage>.broadcast();
  final _notificationTapCtrl = StreamController<RemoteMessage>.broadcast();

  Stream<RemoteMessage> get onForegroundMessage =>
      _foregroundMessageCtrl.stream;
  Stream<RemoteMessage> get onNotificationTap => _notificationTapCtrl.stream;

  /// Trả về và xóa thông báo đã kích hoạt mở app từ trạng thái đóng hoàn toàn.
  RemoteMessage? consumePendingInitialMessage() {
    final msg = _pendingInitialMessage;
    _pendingInitialMessage = null;
    return msg;
  }

  bool get isSupportedPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> initialize({
    required Future<void> Function(String token, String platform)
        onTokenSync,
  }) async {
    _tokenSyncHandler = onTokenSync;
    if (!isSupportedPlatform || _initialized) return;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      messaging.onRegistered.listen((newToken) {
        final trimmed = newToken.trim();
        if (trimmed.isEmpty) return;
        _currentToken = trimmed;
        unawaited(_dispatchToken(trimmed));
      });

      FirebaseMessaging.onMessage.listen((message) {
        if (!_foregroundMessageCtrl.isClosed) {
          _foregroundMessageCtrl.add(message);
        }
      });

      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        if (!_notificationTapCtrl.isClosed) {
          _notificationTapCtrl.add(message);
        }
      });

      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        _pendingInitialMessage = initialMessage;
      }

      _initialized = true;
      await syncCurrentToken();
    } catch (e) {
      debugPrint('FCM init skipped: $e');
    }
  }

  /// Lấy FCM token hiện tại và đồng bộ lên Backend nếu user đã đăng nhập.
  Future<void> syncCurrentToken() async {
    if (!isSupportedPlatform || !_initialized) return;
    try {
      if (_currentToken != null && _currentToken!.isNotEmpty) {
        await _dispatchToken(_currentToken!);
        return;
      }
      await FirebaseMessaging.instance.register();
    } catch (e) {
      debugPrint('FCM sync token skipped: $e');
    }
  }

  /// Xóa token cục bộ khi đăng xuất để tránh nhận thông báo của tài khoản cũ.
  Future<void> clearTokenOnLogout() async {
    _currentToken = null;
    if (!isSupportedPlatform || !_initialized) return;
    try {
      await FirebaseMessaging.instance.unregister();
    } catch (_) {}
  }

  Future<void> _dispatchToken(String token) async {
    final handler = _tokenSyncHandler;
    if (handler == null) return;
    try {
      await handler(token, 'android');
    } catch (_) {}
  }
}
