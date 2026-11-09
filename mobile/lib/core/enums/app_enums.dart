enum UserRole {
  user('Khách hàng'),
  manager('Quản lý quán'),
  barber('Barber'),
  admin('Admin');

  final String label;
  const UserRole(this.label);

  static UserRole fromApi(String? raw) {
    switch (raw?.toUpperCase()) {
      case 'MANAGER':
        return UserRole.manager;
      case 'BARBER':
        return UserRole.barber;
      case 'ADMIN':
        return UserRole.admin;
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
  pending('Chờ thanh toán'),
  confirmed('Đã đặt lịch'),
  completed('Hoàn thành'),
  cancelled('Đã hủy');

  final String label;
  const BookingStatus(this.label);
}

enum PaymentMethod {
  atShop('Thanh toán tại quán'),
  qrCode('Thanh toán bằng QR Code');

  final String label;
  const PaymentMethod(this.label);
}

enum HighlightPackageType {
  oneHour('1 Giờ', 20000, Duration(hours: 1)),
  oneDay('1 Ngày', 50000, Duration(days: 1)),
  threeDays('3 Ngày', 90000, Duration(days: 3));

  final String label;
  final int price;
  final Duration duration;
  const HighlightPackageType(this.label, this.price, this.duration);

  int get priceVnd => price;
}

enum NotificationType {
  bookingCreated,
  paymentConfirmed,
  barberInvitation,
  chatMessage,
  shopApproval,
  system,
}
