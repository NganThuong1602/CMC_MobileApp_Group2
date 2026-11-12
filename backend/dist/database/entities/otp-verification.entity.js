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
exports.OtpVerificationEntity = void 0;
const typeorm_1 = require("typeorm");
const enums_1 = require("./enums");
let OtpVerificationEntity = class OtpVerificationEntity {
};
exports.OtpVerificationEntity = OtpVerificationEntity;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], OtpVerificationEntity.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Index)(),
    (0, typeorm_1.Column)({ length: 180 }),
    __metadata("design:type", String)
], OtpVerificationEntity.prototype, "email", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'otp_code', length: 6 }),
    __metadata("design:type", String)
], OtpVerificationEntity.prototype, "otpCode", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'enum', enum: enums_1.OtpPurpose }),
    __metadata("design:type", String)
], OtpVerificationEntity.prototype, "purpose", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'payload_json', type: 'jsonb', nullable: true }),
    __metadata("design:type", Object)
], OtpVerificationEntity.prototype, "payloadJson", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'expires_at', type: 'timestamptz' }),
    __metadata("design:type", Date)
], OtpVerificationEntity.prototype, "expiresAt", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'is_used', default: false }),
    __metadata("design:type", Boolean)
], OtpVerificationEntity.prototype, "isUsed", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ name: 'created_at', type: 'timestamptz' }),
    __metadata("design:type", Date)
], OtpVerificationEntity.prototype, "createdAt", void 0);
exports.OtpVerificationEntity = OtpVerificationEntity = __decorate([
    (0, typeorm_1.Entity)('otp_verifications')
], OtpVerificationEntity);
//# sourceMappingURL=otp-verification.entity.js.map