"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.DEFAULT_LOCATION_LNG = exports.DEFAULT_LOCATION_LAT = exports.DEFAULT_AVATAR_URL = exports.NotificationType = exports.HighlightPlan = exports.TransactionStatus = exports.BookingShift = exports.SHOP_PACKAGE_CONFIG = exports.ShopPackagePlan = exports.TransactionType = exports.PaymentMethod = exports.BookingStatus = exports.OtpPurpose = exports.Gender = exports.UserRole = void 0;
var UserRole;
(function (UserRole) {
    UserRole["USER"] = "USER";
    UserRole["MANAGER"] = "MANAGER";
    UserRole["BARBER"] = "BARBER";
    UserRole["ADMIN"] = "ADMIN";
})(UserRole || (exports.UserRole = UserRole = {}));
var Gender;
(function (Gender) {
    Gender["MALE"] = "MALE";
    Gender["FEMALE"] = "FEMALE";
    Gender["OTHER"] = "OTHER";
})(Gender || (exports.Gender = Gender = {}));
var OtpPurpose;
(function (OtpPurpose) {
    OtpPurpose["REGISTER"] = "REGISTER";
    OtpPurpose["RESET_PASSWORD"] = "RESET_PASSWORD";
})(OtpPurpose || (exports.OtpPurpose = OtpPurpose = {}));
var BookingStatus;
(function (BookingStatus) {
    BookingStatus["PENDING"] = "PENDING";
    BookingStatus["CONFIRMED"] = "CONFIRMED";
    BookingStatus["COMPLETED"] = "COMPLETED";
    BookingStatus["CANCELLED"] = "CANCELLED";
})(BookingStatus || (exports.BookingStatus = BookingStatus = {}));
var PaymentMethod;
(function (PaymentMethod) {
    PaymentMethod["CASH_AT_SHOP"] = "CASH_AT_SHOP";
    PaymentMethod["SEPAY_QR"] = "SEPAY_QR";
})(PaymentMethod || (exports.PaymentMethod = PaymentMethod = {}));
var TransactionType;
(function (TransactionType) {
    TransactionType["REGISTER_SHOP"] = "REGISTER_SHOP";
    TransactionType["RENEW_SHOP"] = "RENEW_SHOP";
    TransactionType["BUY_HIGHLIGHT"] = "BUY_HIGHLIGHT";
    TransactionType["BOOKING_PAYMENT"] = "BOOKING_PAYMENT";
})(TransactionType || (exports.TransactionType = TransactionType = {}));
var ShopPackagePlan;
(function (ShopPackagePlan) {
    ShopPackagePlan["MEMBER_MONTHLY"] = "MEMBER_MONTHLY";
    ShopPackagePlan["MEMBER_YEARLY"] = "MEMBER_YEARLY";
    ShopPackagePlan["COOP_MONTHLY"] = "COOP_MONTHLY";
    ShopPackagePlan["COOP_YEARLY"] = "COOP_YEARLY";
})(ShopPackagePlan || (exports.ShopPackagePlan = ShopPackagePlan = {}));
exports.SHOP_PACKAGE_CONFIG = {
    [ShopPackagePlan.MEMBER_MONTHLY]: {
        plan: ShopPackagePlan.MEMBER_MONTHLY,
        label: 'Gói Thành viên — 1 tháng',
        price: 500000,
        durationDays: 30,
        isCooperation: false,
        description: 'Mở và quản lý gian hàng trên BarberSmart, nhận đặt lịch & tư vấn khách hàng trong 1 tháng.',
    },
    [ShopPackagePlan.MEMBER_YEARLY]: {
        plan: ShopPackagePlan.MEMBER_YEARLY,
        label: 'Gói Thành viên — 1 năm',
        price: 5000000,
        durationDays: 365,
        isCooperation: false,
        description: 'Toàn bộ quyền lợi Thành viên trong 1 năm (365 ngày), tiết kiệm 2 tháng chi phí.',
    },
    [ShopPackagePlan.COOP_MONTHLY]: {
        plan: ShopPackagePlan.COOP_MONTHLY,
        label: 'Gói Hợp tác — 1 tháng',
        price: 300000,
        durationDays: 30,
        isCooperation: true,
        description: 'Hợp tác ưu đãi: Tự động đẩy quán lên Nổi bật ở đầu Trang chủ & tự động áp dụng Mã giảm giá từ Admin trong 1 tháng.',
    },
    [ShopPackagePlan.COOP_YEARLY]: {
        plan: ShopPackagePlan.COOP_YEARLY,
        label: 'Gói Hợp tác — 1 năm',
        price: 3000000,
        durationDays: 365,
        isCooperation: true,
        description: 'Hợp tác trọn năm: Đẩy quán lên Nổi bật ở đầu Trang chủ suốt 365 ngày & tham gia toàn bộ chiến dịch Mã giảm giá từ Admin.',
    },
};
var BookingShift;
(function (BookingShift) {
    BookingShift["MORNING"] = "MORNING";
    BookingShift["AFTERNOON"] = "AFTERNOON";
})(BookingShift || (exports.BookingShift = BookingShift = {}));
var TransactionStatus;
(function (TransactionStatus) {
    TransactionStatus["PENDING"] = "PENDING";
    TransactionStatus["SUCCESS"] = "SUCCESS";
    TransactionStatus["FAILED"] = "FAILED";
})(TransactionStatus || (exports.TransactionStatus = TransactionStatus = {}));
var HighlightPlan;
(function (HighlightPlan) {
    HighlightPlan["ONE_HOUR"] = "ONE_HOUR";
    HighlightPlan["ONE_DAY"] = "ONE_DAY";
    HighlightPlan["THREE_DAYS"] = "THREE_DAYS";
})(HighlightPlan || (exports.HighlightPlan = HighlightPlan = {}));
var NotificationType;
(function (NotificationType) {
    NotificationType["BOOKING"] = "BOOKING";
    NotificationType["BARBER_INVITE"] = "BARBER_INVITE";
    NotificationType["PAYMENT_SUCCESS"] = "PAYMENT_SUCCESS";
    NotificationType["CHAT_MESSAGE"] = "CHAT_MESSAGE";
    NotificationType["SHOP_APPROVAL"] = "SHOP_APPROVAL";
    NotificationType["SYSTEM"] = "SYSTEM";
})(NotificationType || (exports.NotificationType = NotificationType = {}));
exports.DEFAULT_AVATAR_URL = 'https://www.gravatar.com/avatar/00000000000000000000000000000000?d=mp&f=y';
exports.DEFAULT_LOCATION_LAT = 20.9768;
exports.DEFAULT_LOCATION_LNG = 105.7724;
//# sourceMappingURL=enums.js.map