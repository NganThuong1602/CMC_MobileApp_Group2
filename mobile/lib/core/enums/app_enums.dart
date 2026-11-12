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

enum ShopPackagePlan {
  memberMonthly(
    'MEMBER_MONTHLY',
    'Gói Thành viên — 1 tháng',
    500000,
    30,
    false,
    'Mở và quản lý gian hàng trên BarberSmart, nhận đặt lịch & tư vấn khách hàng trong 1 tháng.',
  ),
  memberYearly(
    'MEMBER_YEARLY',
    'Gói Thành viên — 1 năm',
    5000000,
    365,
    false,
    'Toàn bộ quyền lợi Thành viên trong 1 năm (365 ngày), tiết kiệm 2 tháng chi phí.',
  ),
  coopMonthly(
    'COOP_MONTHLY',
    'Gói Hợp tác — 1 tháng',
    300000,
    30,
    true,
    'Tự động đẩy quán lên Nổi bật ở đầu Trang chủ & tự động áp dụng Mã giảm giá từ Admin trong 1 tháng.',
  ),
  coopYearly(
    'COOP_YEARLY',
    'Gói Hợp tác — 1 năm',
    3000000,
    365,
    true,
    'Đẩy quán lên Nổi bật ở đầu Trang chủ suốt 365 ngày & tham gia toàn bộ chiến dịch Mã giảm giá từ Admin.',
  );

  final String apiValue;
  final String label;
  final int price;
  final int durationDays;
  final bool isCooperation;
  final String benefitDescription;

  const ShopPackagePlan(
    this.apiValue,
    this.label,
    this.price,
    this.durationDays,
    this.isCooperation,
    this.benefitDescription,
  );

  static ShopPackagePlan? fromApi(String? raw) {
    switch (raw?.toUpperCase()) {
      case 'MEMBER_MONTHLY':
        return ShopPackagePlan.memberMonthly;
      case 'MEMBER_YEARLY':
        return ShopPackagePlan.memberYearly;
      case 'COOP_MONTHLY':
        return ShopPackagePlan.coopMonthly;
      case 'COOP_YEARLY':
        return ShopPackagePlan.coopYearly;
      default:
        return null;
    }
  }
}

enum BookingShift {
  morning('MORNING', 'Ca sáng'),
  afternoon('AFTERNOON', 'Ca chiều');

  final String apiValue;
  final String label;
  const BookingShift(this.apiValue, this.label);

  static BookingShift? fromApi(String? raw) {
    switch (raw?.toUpperCase()) {
      case 'MORNING':
        return BookingShift.morning;
      case 'AFTERNOON':
        return BookingShift.afternoon;
      default:
        return null;
    }
  }
}

enum NotificationType {
  bookingCreated,
  paymentConfirmed,
  barberInvitation,
  chatMessage,
  shopApproval,
  system,
}
