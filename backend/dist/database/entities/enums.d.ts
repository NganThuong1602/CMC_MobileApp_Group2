export declare enum UserRole {
    USER = "USER",
    MANAGER = "MANAGER",
    BARBER = "BARBER",
    ADMIN = "ADMIN"
}
export declare enum Gender {
    MALE = "MALE",
    FEMALE = "FEMALE",
    OTHER = "OTHER"
}
export declare enum OtpPurpose {
    REGISTER = "REGISTER",
    RESET_PASSWORD = "RESET_PASSWORD"
}
export declare enum BookingStatus {
    PENDING = "PENDING",
    CONFIRMED = "CONFIRMED",
    COMPLETED = "COMPLETED",
    CANCELLED = "CANCELLED"
}
export declare enum PaymentMethod {
    CASH_AT_SHOP = "CASH_AT_SHOP",
    SEPAY_QR = "SEPAY_QR"
}
export declare enum TransactionType {
    REGISTER_SHOP = "REGISTER_SHOP",
    RENEW_SHOP = "RENEW_SHOP",
    BUY_HIGHLIGHT = "BUY_HIGHLIGHT",
    BOOKING_PAYMENT = "BOOKING_PAYMENT"
}
export declare enum ShopPackagePlan {
    MEMBER_MONTHLY = "MEMBER_MONTHLY",
    MEMBER_YEARLY = "MEMBER_YEARLY",
    COOP_MONTHLY = "COOP_MONTHLY",
    COOP_YEARLY = "COOP_YEARLY"
}
export interface ShopPackageMeta {
    plan: ShopPackagePlan;
    label: string;
    price: number;
    durationDays: number;
    isCooperation: boolean;
    description: string;
}
export declare const SHOP_PACKAGE_CONFIG: Record<ShopPackagePlan, ShopPackageMeta>;
export declare enum BookingShift {
    MORNING = "MORNING",
    AFTERNOON = "AFTERNOON"
}
export declare enum TransactionStatus {
    PENDING = "PENDING",
    SUCCESS = "SUCCESS",
    FAILED = "FAILED"
}
export declare enum HighlightPlan {
    ONE_HOUR = "ONE_HOUR",
    ONE_DAY = "ONE_DAY",
    THREE_DAYS = "THREE_DAYS"
}
export declare enum NotificationType {
    BOOKING = "BOOKING",
    BARBER_INVITE = "BARBER_INVITE",
    PAYMENT_SUCCESS = "PAYMENT_SUCCESS",
    CHAT_MESSAGE = "CHAT_MESSAGE",
    SHOP_APPROVAL = "SHOP_APPROVAL",
    SYSTEM = "SYSTEM"
}
export declare const DEFAULT_AVATAR_URL = "https://www.gravatar.com/avatar/00000000000000000000000000000000?d=mp&f=y";
export declare const DEFAULT_LOCATION_LAT = 20.9768;
export declare const DEFAULT_LOCATION_LNG = 105.7724;
