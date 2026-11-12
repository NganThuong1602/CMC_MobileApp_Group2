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
exports.BarberEntity = void 0;
const typeorm_1 = require("typeorm");
const user_entity_1 = require("./user.entity");
const shop_entity_1 = require("./shop.entity");
let BarberEntity = class BarberEntity {
};
exports.BarberEntity = BarberEntity;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], BarberEntity.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'user_id', unique: true }),
    __metadata("design:type", String)
], BarberEntity.prototype, "userId", void 0);
__decorate([
    (0, typeorm_1.OneToOne)(() => user_entity_1.UserEntity, (user) => user.barberProfile, { onDelete: 'CASCADE' }),
    (0, typeorm_1.JoinColumn)({ name: 'user_id' }),
    __metadata("design:type", user_entity_1.UserEntity)
], BarberEntity.prototype, "user", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'shop_id' }),
    __metadata("design:type", String)
], BarberEntity.prototype, "shopId", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => shop_entity_1.ShopEntity, (shop) => shop.barbers, { onDelete: 'CASCADE' }),
    (0, typeorm_1.JoinColumn)({ name: 'shop_id' }),
    __metadata("design:type", shop_entity_1.ShopEntity)
], BarberEntity.prototype, "shop", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'base_salary', type: 'int', default: 0 }),
    __metadata("design:type", Number)
], BarberEntity.prototype, "baseSalary", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'is_active', default: true }),
    __metadata("design:type", Boolean)
], BarberEntity.prototype, "isActive", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'text', default: '' }),
    __metadata("design:type", String)
], BarberEntity.prototype, "bio", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'float', default: 5.0 }),
    __metadata("design:type", Number)
], BarberEntity.prototype, "rating", void 0);
__decorate([
    (0, typeorm_1.Column)({
        name: 'joined_at',
        type: 'timestamptz',
        default: () => 'CURRENT_TIMESTAMP',
    }),
    __metadata("design:type", Date)
], BarberEntity.prototype, "joinedAt", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ name: 'created_at', type: 'timestamptz' }),
    __metadata("design:type", Date)
], BarberEntity.prototype, "createdAt", void 0);
exports.BarberEntity = BarberEntity = __decorate([
    (0, typeorm_1.Entity)('barbers')
], BarberEntity);
//# sourceMappingURL=barber.entity.js.map