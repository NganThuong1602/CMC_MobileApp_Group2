export enum UserRole {
  USER = 'USER',
  MANAGER = 'MANAGER',
  BARBER = 'BARBER',
  ADMIN = 'ADMIN',
}

export enum Gender {
  MALE = 'MALE',
  FEMALE = 'FEMALE',
  OTHER = 'OTHER',
}

export enum OtpPurpose {
  REGISTER = 'REGISTER',
  RESET_PASSWORD = 'RESET_PASSWORD',
}

export enum BookingStatus {
  PENDING = 'PENDING',
  CONFIRMED = 'CONFIRMED',
  COMPLETED = 'COMPLETED',
  CANCELLED = 'CANCELLED',
}

export enum PaymentMethod {
  CASH_AT_SHOP = 'CASH_AT_SHOP',
  SEPAY_QR = 'SEPAY_QR',
}

export enum TransactionType {
  REGISTER_SHOP = 'REGISTER_SHOP',
  RENEW_SHOP = 'RENEW_SHOP',
  BUY_HIGHLIGHT = 'BUY_HIGHLIGHT',
  BOOKING_PAYMENT = 'BOOKING_PAYMENT',
}

export enum ShopPackagePlan {
  MEMBER_MONTHLY = 'MEMBER_MONTHLY',
  MEMBER_YEARLY = 'MEMBER_YEARLY',
  COOP_MONTHLY = 'COOP_MONTHLY',
  COOP_YEARLY = 'COOP_YEARLY',
}

export interface ShopPackageMeta {
  plan: ShopPackagePlan;
  label: string;
  price: number;
  durationDays: number;
  isCooperation: boolean;
  description: string;
}

export const SHOP_PACKAGE_CONFIG: Record<ShopPackagePlan, ShopPackageMeta> = {
  [ShopPackagePlan.MEMBER_MONTHLY]: {
    plan: ShopPackagePlan.MEMBER_MONTHLY,
    label: 'Gói Thành viên — 1 tháng',
    price: 500000,
    durationDays: 30,
    isCooperation: false,
    description:
      'Mở và quản lý gian hàng trên BarberSmart, nhận đặt lịch & tư vấn khách hàng trong 1 tháng.',
  },
  [ShopPackagePlan.MEMBER_YEARLY]: {
    plan: ShopPackagePlan.MEMBER_YEARLY,
    label: 'Gói Thành viên — 1 năm',
    price: 5000000,
    durationDays: 365,
    isCooperation: false,
    description:
      'Toàn bộ quyền lợi Thành viên trong 1 năm (365 ngày), tiết kiệm 2 tháng chi phí.',
  },
  [ShopPackagePlan.COOP_MONTHLY]: {
    plan: ShopPackagePlan.COOP_MONTHLY,
    label: 'Gói Hợp tác — 1 tháng',
    price: 300000,
    durationDays: 30,
    isCooperation: true,
    description:
      'Hợp tác ưu đãi: Tự động đẩy quán lên Nổi bật ở đầu Trang chủ & tự động áp dụng Mã giảm giá từ Admin trong 1 tháng.',
  },
  [ShopPackagePlan.COOP_YEARLY]: {
    plan: ShopPackagePlan.COOP_YEARLY,
    label: 'Gói Hợp tác — 1 năm',
    price: 3000000,
    durationDays: 365,
    isCooperation: true,
    description:
      'Hợp tác trọn năm: Đẩy quán lên Nổi bật ở đầu Trang chủ suốt 365 ngày & tham gia toàn bộ chiến dịch Mã giảm giá từ Admin.',
  },
};

export enum BookingShift {
  MORNING = 'MORNING',
  AFTERNOON = 'AFTERNOON',
}

export enum TransactionStatus {
  PENDING = 'PENDING',
  SUCCESS = 'SUCCESS',
  FAILED = 'FAILED',
}

export enum HighlightPlan {
  ONE_HOUR = 'ONE_HOUR',
  ONE_DAY = 'ONE_DAY',
  THREE_DAYS = 'THREE_DAYS',
}

export enum NotificationType {
  BOOKING = 'BOOKING',
  BARBER_INVITE = 'BARBER_INVITE',
  PAYMENT_SUCCESS = 'PAYMENT_SUCCESS',
  CHAT_MESSAGE = 'CHAT_MESSAGE',
  SHOP_APPROVAL = 'SHOP_APPROVAL',
  SYSTEM = 'SYSTEM',
}

/**
 * URL Avatar xám trống mặc định (tương tự Facebook Mystery Person)
 * cho bất kỳ tài khoản mới nào chưa tải ảnh đại diện lên.
 */
export const DEFAULT_AVATAR_URL =
  'https://www.gravatar.com/avatar/00000000000000000000000000000000?d=mp&f=y';

/**
 * Tọa độ trung tâm mặc định khu vực Vạn Phúc, Hà Đông, Hà Nội.
 */
export const DEFAULT_LOCATION_LAT = 20.9768;
export const DEFAULT_LOCATION_LNG = 105.7724;
