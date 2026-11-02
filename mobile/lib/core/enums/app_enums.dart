enum UserRole {
  user('Khách hàng'),
  manager('Quản lý'),
  barber('Barber');

  final String label;
  const UserRole(this.label);

  static UserRole fromApi(String? raw) {
    switch (raw?.toUpperCase()) {
      case 'MANAGER':
        return UserRole.manager;
      case 'BARBER':
        return UserRole.barber;
      default:
        return UserRole.user;
    }
  }
}

enum Gender {
  male('Nam'),
  female('Nữ'),
  other('Khác');

  final String label;
  const Gender(this.label);
}

enum BookingStatus {
  pending('Chờ thanh toán QR'),
  confirmed('Đã đặt lịch'),
  completed('Hoàn thành'),
  cancelled('Đã hủy');

  final String label;
  const BookingStatus(this.label);
}

enum PaymentMethod {
  atShop('Thanh toán tại quán'),
  qrCode('Thanh toán bằng QR (SePay)');

  final String label;
  const PaymentMethod(this.label);
}

enum HighlightPackageType {
  oneHour(
    apiCode: 'ONE_HOUR',
    label: 'Gói 1 giờ',
    priceVnd: 20000,
    duration: Duration(hours: 1),
  ),
  oneDay(
    apiCode: 'ONE_DAY',
    label: 'Gói 1 ngày',
    priceVnd: 50000,
    duration: Duration(days: 1),
  ),
  threeDays(
    apiCode: 'THREE_DAYS',
    label: 'Gói 3 ngày',
    priceVnd: 90000,
    duration: Duration(days: 3),
  );

  final String apiCode;
  final String label;
  final int priceVnd;
  final Duration duration;

  const HighlightPackageType({
    required this.apiCode,
    required this.label,
    required this.priceVnd,
    required this.duration,
  });
}

enum NotificationType {
  bookingCreated,
  barberInvitation,
  paymentConfirmed,
  system,
}

