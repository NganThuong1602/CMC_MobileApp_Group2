"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.BookingEntity = void 0;
const typeorm_1 = require("typeorm");
const enums_1 = require("./enums");
const shop_entity_1 = require("./shop.entity");
const barber_entity_1 = require("./barber.entity");
const user_entity_1 = require("./user.entity");
let BookingEntity = class BookingEntity {
};
exports.BookingEntity = BookingEntity;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], BookingEntity.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'shop_id' }),
    __metadata("design:type", String)
], BookingEntity.prototype, "shopId", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => shop_entity_1.ShopEntity, { onDelete: 'CASCADE' }),
    (0, typeorm_1.JoinColumn)({ name: 'shop_id' }),
    __metadata("design:type", shop_entity_1.ShopEntity)
], BookingEntity.prototype, "shop", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'barber_id' }),
    __metadata("design:type", String)
], BookingEntity.prototype, "barberId", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => barber_entity_1.BarberEntity, { onDelete: 'CASCADE' }),
    (0, typeorm_1.JoinColumn)({ name: 'barber_id' }),
    __metadata("design:type", barber_entity_1.BarberEntity)
], BookingEntity.prototype, "barber", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'customer_id' }),
    __metadata("design:type", String)
], BookingEntity.prototype, "customerId", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => user_entity_1.UserEntity, { onDelete: 'CASCADE' }),
    (0, typeorm_1.JoinColumn)({ name: 'customer_id' }),
    __metadata("design:type", user_entity_1.UserEntity)
], BookingEntity.prototype, "customer", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'booking_date', type: 'date' }),
    __metadata("design:type", String)
], BookingEntity.prototype, "bookingDate", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'start_minutes', type: 'int' }),
    __metadata("design:type", Number)
], BookingEntity.prototype, "startMinutes", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'end_minutes', type: 'int' }),
    __metadata("design:type", Number)
], BookingEntity.prototype, "endMinutes", void 0);
__decorate([
    (0, typeorm_1.Column)({
        type: 'enum',
        enum: enums_1.BookingShift,
        nullable: true,
    }),
    __metadata("design:type", Object)
], BookingEntity.prototype, "shift", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'total_duration_minutes', type: 'int' }),
    __metadata("design:type", Number)
], BookingEntity.prototype, "totalDurationMinutes", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'total_price', type: 'int' }),
    __metadata("design:type", Number)
], BookingEntity.prototype, "totalPrice", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'services_snapshot', type: 'jsonb', default: () => "'[]'" }),
    __metadata("design:type", Array)
], BookingEntity.prototype, "servicesSnapshot", void 0);
__decorate([
    (0, typeorm_1.Column)({
        name: 'payment_method',
        type: 'enum',
        enum: enums_1.PaymentMethod,
        default: enums_1.PaymentMethod.CASH_AT_SHOP,
    }),
    __metadata("design:type", String)
], BookingEntity.prototype, "paymentMethod", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'is_paid', default: false }),
    __metadata("design:type", Boolean)
], BookingEntity.prototype, "isPaid", void 0);
__decorate([
    (0, typeorm_1.Column)({
        type: 'enum',
        enum: enums_1.BookingStatus,
        default: enums_1.BookingStatus.CONFIRMED,
    }),
    __metadata("design:type", String)
], BookingEntity.prototype, "status", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'completed_at', type: 'timestamptz', nullable: true }),
    __metadata("design:type", Object)
], BookingEntity.prototype, "completedAt", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ name: 'created_at', type: 'timestamptz' }),
    __metadata("design:type", Date)
], BookingEntity.prototype, "createdAt", void 0);
exports.BookingEntity = BookingEntity = __decorate([
    (0, typeorm_1.Entity)('bookings'),
    (0, typeorm_1.Index)(['barberId', 'bookingDate'])
], BookingEntity);
//# sourceMappingURL=booking.entity.js.map