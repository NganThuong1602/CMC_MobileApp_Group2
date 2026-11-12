class AppConstants {
  AppConstants._();

  static const String appName = 'BARBERSMART';
  static const String appTagline =
      'Đặt lịch cắt tóc chuyên nghiệp & nhanh chóng';

  /// =========================================================================
  /// CẤU HÌNH SERVER URL (TẬP TRUNG TẠI MỘT NƠI DUY NHẤT)
  /// =========================================================================
  /// 1. Hiện tại khi đang phát triển / test SePay Webhook:
  ///    Mặc định trỏ về URL Ngrok của bạn: https://upgrade-tarot-kitten.ngrok-free.dev
  ///
  /// 2. Khi đăng app lên Google Play Store (CH Play):
  ///    Cách 1: Chỉ cần thay đổi giá trị của [_defaultServerUrl] thành domain Production thật của bạn (VD: https://api.barbersmart.vn).
  ///    Cách 2: Build APK/AAB bằng lệnh mà không cần sửa code:
  ///            flutter build appbundle --release --dart-define=SERVER_URL=https://api.barbersmart.vn
  /// =========================================================================
  static const String _defaultServerUrl =
      'https://upgrade-tarot-kitten.ngrok-free.dev';

  static const String serverUrl = String.fromEnvironment(
    'SERVER_URL',
    defaultValue: _defaultServerUrl,
  );

  static String get apiBaseUrl => '$serverUrl/api/v1';
  static String get socketUrl => '$serverUrl/realtime';

  // OpenStreetMap Tile Server (Không dùng Google Maps)
  static const String osmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String osmUserAgentPackage = 'vn.barbersmart.mobile';

  // Tọa độ dự phòng khi thiết bị tắt GPS (Vạn Phúc, Hà Đông, Hà Nội)
  static const double defaultLat = 20.9768;
  static const double defaultLng = 105.7724;

  // Avatar mặc định xám trống (kiểu Facebook Mystery Person) cho tài khoản mới
  static const String defaultAvatarUrl =
      'https://www.gravatar.com/avatar/00000000000000000000000000000000?d=mp&f=y';

  // Cấu hình Thanh toán SePay & VietQR động
  static const int shopRegistrationFeeVnd = 100000;
  static const String sepayBankCode = 'ICB';
  static const String platformBankName = 'VietinBank';
  static const String platformBankAccount = '101886339075';
  static const String platformBankOwner = 'BARBERSMART PLATFORM';

  // Cấu hình Nghiệp vụ Đặt lịch theo Ca sáng / Ca chiều
  static const int bookingGapMinutes = 5; // Mỗi khách cách nhau 5 phút
  static const int morningShiftEndMinutes = 12 * 60; // 12:00 (720p)
  static const int afternoonShiftStartMinutes = 13 * 60 + 30; // 13:30 (810p)
  static const int slotIntervalMinutes = 15;
  static const int lunchStartMinutes = morningShiftEndMinutes;
  static const int lunchEndMinutes = afternoonShiftStartMinutes;
  static const int slotLockTtlMinutes = 5;

  // Cấu hình Hoa hồng Barber & Mạng xã hội
  static const double barberCommissionRate = 0.10; // 10% khi COMPLETED
  static const String expectedPaydayText =
      'Ngày nhận lương dự kiến: Mùng 1 hàng tháng';
  static const int maxPostImages = 5;
  static const String demoOtpCode = '123456';
}
