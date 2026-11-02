export enum UserRole {
  USER = 'USER',
  MANAGER = 'MANAGER',
  BARBER = 'BARBER',
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
  BUY_HIGHLIGHT = 'BUY_HIGHLIGHT',
  BOOKING_PAYMENT = 'BOOKING_PAYMENT',
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


