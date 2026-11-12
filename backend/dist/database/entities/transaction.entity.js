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
exports.TransactionEntity = void 0;
const typeorm_1 = require("typeorm");
const enums_1 = require("./enums");
let TransactionEntity = class TransactionEntity {
};
exports.TransactionEntity = TransactionEntity;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], TransactionEntity.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Index)({ unique: true }),
    (0, typeorm_1.Column)({ name: 'payment_code', unique: true, length: 40 }),
    __metadata("design:type", String)
], TransactionEntity.prototype, "paymentCode", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'transfer_content', length: 80 }),
    __metadata("design:type", String)
], TransactionEntity.prototype, "transferContent", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'user_id' }),
    __metadata("design:type", String)
], TransactionEntity.prototype, "userId", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'shop_id', nullable: true }),
    __metadata("design:type", String)
], TransactionEntity.prototype, "shopId", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'booking_id', nullable: true }),
    __metadata("design:type", String)
], TransactionEntity.prototype, "bookingId", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'enum', enum: enums_1.TransactionType }),
    __metadata("design:type", String)
], TransactionEntity.prototype, "type", void 0);
__decorate([
    (0, typeorm_1.Column)({
        name: 'highlight_plan',
        type: 'enum',
        enum: enums_1.HighlightPlan,
        nullable: true,
    }),
    __metadata("design:type", String)
], TransactionEntity.prototype, "highlightPlan", void 0);
__decorate([
    (0, typeorm_1.Column)({
        name: 'package_plan',
        type: 'enum',
        enum: enums_1.ShopPackagePlan,
        nullable: true,
    }),
    __metadata("design:type", String)
], TransactionEntity.prototype, "packagePlan", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'int' }),
    __metadata("design:type", Number)
], TransactionEntity.prototype, "amount", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'qr_image_url', type: 'text' }),
    __metadata("design:type", String)
], TransactionEntity.prototype, "qrImageUrl", void 0);
__decorate([
    (0, typeorm_1.Column)({
        type: 'enum',
        enum: enums_1.TransactionStatus,
        default: enums_1.TransactionStatus.PENDING,
    }),
    __metadata("design:type", String)
], TransactionEntity.prototype, "status", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'sepay_reference_id', nullable: true }),
    __metadata("design:type", String)
], TransactionEntity.prototype, "sepayReferenceId", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'metadata_json', type: 'jsonb', nullable: true }),
    __metadata("design:type", Object)
], TransactionEntity.prototype, "metadataJson", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'paid_at', type: 'timestamptz', nullable: true }),
    __metadata("design:type", Date)
], TransactionEntity.prototype, "paidAt", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ name: 'created_at', type: 'timestamptz' }),
    __metadata("design:type", Date)
], TransactionEntity.prototype, "createdAt", void 0);
exports.TransactionEntity = TransactionEntity = __decorate([
    (0, typeorm_1.Entity)('transactions')
], TransactionEntity);
//# sourceMappingURL=transaction.entity.js.map