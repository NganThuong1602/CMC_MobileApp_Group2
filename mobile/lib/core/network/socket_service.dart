import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../constants/app_constants.dart';

/// Quản lý kết nối Socket.IO Realtime với NestJS:
/// - Nhận sự kiện `payment.success` ngay khi SePay bắn Webhook (không chờ duyệt tay).
/// - Nhận sự kiện `user.role_updated` khi nâng cấp Role Manager / Barber.
/// - Phục vụ Group Chat tư vấn trực tiếp (`chat.join_room`, `chat.send_message`, `chat.new_message`).
class SocketService {
  io.Socket? _socket;

  final _paymentSuccessCtrl =
      StreamController<Map<String, dynamic>>.broadcast();
  final _newMessageCtrl = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onPaymentSuccess =>
      _paymentSuccessCtrl.stream;
  Stream<Map<String, dynamic>> get onNewChatMessage => _newMessageCtrl.stream;

  void connect(String userId) {
    disconnect();
    final socket = io.io(
      AppConstants.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setExtraHeaders({'ngrok-skip-browser-warning': 'true'})
          .setQuery({'userId': userId})
          .disableAutoConnect()
          .build(),
    );

    socket.on('payment.success', (data) {
      if (data is Map) {
        _paymentSuccessCtrl.add(Map<String, dynamic>.from(data));
      }
    });

    socket.on('chat.new_message', (data) {
      if (data is Map) {
        _newMessageCtrl.add(Map<String, dynamic>.from(data));
      }
    });

    socket.connect();
    _socket = socket;
  }

  void joinChatRoom(String roomId) {
    _socket?.emit('chat.join_room', {'roomId': roomId});
  }

  void sendChatMessage({
    required String roomId,
    required String senderId,
    required String content,
  }) {
    _socket?.emit('chat.send_message', {
      'roomId': roomId,
      'senderId': senderId,
      'content': content,
    });
  }

  /// Phục vụ giả lập tín hiệu SePay Webhook ngay trên môi trường Offline/Local Demo.
  void emitSimulatedPaymentSuccess(Map<String, dynamic> payload) {
    _paymentSuccessCtrl.add(payload);
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}
