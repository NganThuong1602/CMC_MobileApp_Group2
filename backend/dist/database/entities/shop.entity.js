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
exports.ShopEntity = void 0;
const typeorm_1 = require("typeorm");
const user_entity_1 = require("./user.entity");
const barber_entity_1 = require("./barber.entity");
const service_entity_1 = require("./service.entity");
const enums_1 = require("./enums");
let ShopEntity = class ShopEntity {
};
exports.ShopEntity = ShopEntity;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], ShopEntity.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'owner_id', unique: true }),
    __metadata("design:type", String)
], ShopEntity.prototype, "ownerId", void 0);
__decorate([
    (0, typeorm_1.OneToOne)(() => user_entity_1.UserEntity, (user) => user.managedShop, { onDelete: 'CASCADE' }),
    (0, typeorm_1.JoinColumn)({ name: 'owner_id' }),
    __metadata("design:type", user_entity_1.UserEntity)
], ShopEntity.prototype, "owner", void 0);
__decorate([
    (0, typeorm_1.Column)({ unique: true, length: 180 }),
    __metadata("design:type", String)
], ShopEntity.prototype, "name", void 0);
__decorate([
    (0, typeorm_1.Column)({ unique: true, length: 255 }),
    __metadata("design:type", String)
], ShopEntity.prototype, "address", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'avatar_url', nullable: true }),
    __metadata("design:type", String)
], ShopEntity.prototype, "avatarUrl", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'cover_url', nullable: true }),
    __metadata("design:type", String)
], ShopEntity.prototype, "coverUrl", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'gallery_urls', type: 'jsonb', default: () => "'[]'" }),
    __metadata("design:type", Array)
], ShopEntity.prototype, "galleryUrls", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'open_time', length: 10, default: '08:30' }),
    __metadata("design:type", String)
], ShopEntity.prototype, "openTime", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'close_time', length: 10, default: '20:30' }),
    __metadata("design:type", String)
], ShopEntity.prototype, "closeTime", void 0);
__decorate([
    (0, typeorm_1.Column)({ length: 25 }),
    __metadata("design:type", String)
], ShopEntity.prototype, "phone", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'text', default: '' }),
    __metadata("design:type", String)
], ShopEntity.prototype, "description", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'double precision', default: 20.9768 }),
    __metadata("design:type", Number)
], ShopEntity.prototype, "latitude", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'double precision', default: 105.7724 }),
    __metadata("design:type", Number)
], ShopEntity.prototype, "longitude", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'float', default: 0.0 }),
    __metadata("design:type", Number)
], ShopEntity.prototype, "rating", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'review_count', type: 'int', default: 0 }),
    __metadata("design:type", Number)
], ShopEntity.prototype, "reviewCount", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'is_active', default: true }),
    __metadata("design:type", Boolean)
], ShopEntity.prototype, "isActive", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'highlight_expires_at', type: 'timestamptz', nullable: true }),
    __metadata("design:type", Object)
], ShopEntity.prototype, "highlightExpiresAt", void 0);
__decorate([
    (0, typeorm_1.Column)({
        name: 'subscription_plan',
        type: 'enum',
        enum: enums_1.ShopPackagePlan,
        nullable: true,
    }),
    __metadata("design:type", Object)
], ShopEntity.prototype, "subscriptionPlan", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'is_cooperation', default: false }),
    __metadata("design:type", Boolean)
], ShopEntity.prototype, "isCooperation", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'subscription_expires_at', type: 'timestamptz', nullable: true }),
    __metadata("design:type", Object)
], ShopEntity.prototype, "subscriptionExpiresAt", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'renewal_notified_at', type: 'timestamptz', nullable: true }),
    __metadata("design:type", Object)
], ShopEntity.prototype, "renewalNotifiedAt", void 0);
__decorate([
    (0, typeorm_1.OneToMany)(() => barber_entity_1.BarberEntity, (barber) => barber.shop),
    __metadata("design:type", Array)
], ShopEntity.prototype, "barbers", void 0);
__decorate([
    (0, typeorm_1.OneToMany)(() => service_entity_1.ServiceEntity, (service) => service.shop),
    __metadata("design:type", Array)
], ShopEntity.prototype, "services", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ name: 'created_at', type: 'timestamptz' }),
    __metadata("design:type", Date)
], ShopEntity.prototype, "createdAt", void 0);
__decorate([
    (0, typeorm_1.UpdateDateColumn)({ name: 'updated_at', type: 'timestamptz' }),
    __metadata("design:type", Date)
], ShopEntity.prototype, "updatedAt", void 0);
exports.ShopEntity = ShopEntity = __decorate([
    (0, typeorm_1.Entity)('shops')
], ShopEntity);
//# sourceMappingURL=shop.entity.js.map