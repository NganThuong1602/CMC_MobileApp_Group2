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
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.DiscountsModule = exports.DiscountsController = exports.DiscountsService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const auth_guards_1 = require("../../common/auth.guards");
const entities_1 = require("../../database/entities");
let DiscountsService = class DiscountsService {
    constructor(discountRepo) {
        this.discountRepo = discountRepo;
    }
    async findAll() {
        return this.discountRepo.find({
            order: { createdAt: 'DESC' },
        });
    }
    async findActiveNow() {
        const now = new Date();
        const list = await this.discountRepo.find({
            where: { isActive: true },
            order: { discountPercent: 'DESC', createdAt: 'DESC' },
        });
        return list.filter((d) => new Date(d.startAt) <= now && now <= new Date(d.endAt));
    }
    async getBestActiveDiscount() {
        const active = await this.findActiveNow();
        return active.length > 0 ? active[0] : null;
    }
    async createByAdmin(adminUser, dto) {
        if (adminUser.role !== entities_1.UserRole.ADMIN) {
            throw new common_1.ForbiddenException('Chỉ Admin mới có quyền thêm mã giảm giá');
        }
        const cleanName = dto.name?.trim() ?? '';
        if (!cleanName) {
            throw new common_1.BadRequestException('Vui lòng nhập tên hoặc mô tả mã giảm giá');
        }
        const pct = Math.round(Number(dto.discountPercent));
        if (Number.isNaN(pct) || pct < 1 || pct > 90) {
            throw new common_1.BadRequestException('Phần trăm giảm giá phải từ 1% đến 90%');
        }
        const start = new Date(dto.startAt);
        const end = new Date(dto.endAt);
        if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) {
            throw new common_1.BadRequestException('Thời gian bắt đầu / kết thúc không hợp lệ');
        }
        if (end <= start) {
            throw new common_1.BadRequestException('Thời gian kết thúc phải sau thời gian bắt đầu');
        }
        const cleanCode = dto.code?.trim().toUpperCase() || undefined;
        return this.discountRepo.save(this.discountRepo.create({
            name: cleanName,
            code: cleanCode,
            discountPercent: pct,
            startAt: start,
            endAt: end,
            isActive: true,
        }));
    }
    async deleteByAdmin(adminUser, id) {
        if (adminUser.role !== entities_1.UserRole.ADMIN) {
            throw new common_1.ForbiddenException('Chỉ Admin mới có quyền xoá mã giảm giá');
        }
        const existing = await this.discountRepo.findOne({ where: { id } });
        if (!existing) {
            throw new common_1.NotFoundException('Không tìm thấy mã giảm giá');
        }
        await this.discountRepo.delete(id);
        return { deleted: true, id };
    }
};
exports.DiscountsService = DiscountsService;
exports.DiscountsService = DiscountsService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(entities_1.DiscountCodeEntity)),
    __metadata("design:paramtypes", [typeorm_2.Repository])
], DiscountsService);
let DiscountsController = class DiscountsController {
    constructor(service) {
        this.service = service;
    }
    findAll() {
        return this.service.findAll();
    }
    findActive() {
        return this.service.findActiveNow();
    }
    create(user, dto) {
        return this.service.createByAdmin(user, dto);
    }
    remove(user, id) {
        return this.service.deleteByAdmin(user, id);
    }
};
exports.DiscountsController = DiscountsController;
__decorate([
    (0, common_1.Get)(),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", void 0)
], DiscountsController.prototype, "findAll", null);
__decorate([
    (0, common_1.Get)('active'),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", void 0)
], DiscountsController.prototype, "findActive", null);
__decorate([
    (0, common_1.Post)('admin'),
    (0, common_1.UseGuards)(auth_guards_1.JwtAuthGuard),
    __param(0, (0, auth_guards_1.CurrentUser)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [entities_1.UserEntity, Object]),
    __metadata("design:returntype", void 0)
], DiscountsController.prototype, "create", null);
__decorate([
    (0, common_1.Delete)(':id'),
    (0, common_1.UseGuards)(auth_guards_1.JwtAuthGuard),
    __param(0, (0, auth_guards_1.CurrentUser)()),
    __param(1, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [entities_1.UserEntity, String]),
    __metadata("design:returntype", void 0)
], DiscountsController.prototype, "remove", null);
exports.DiscountsController = DiscountsController = __decorate([
    (0, common_1.Controller)('discounts'),
    __metadata("design:paramtypes", [DiscountsService])
], DiscountsController);
let DiscountsModule = class DiscountsModule {
};
exports.DiscountsModule = DiscountsModule;
exports.DiscountsModule = DiscountsModule = __decorate([
    (0, common_1.Module)({
        imports: [typeorm_1.TypeOrmModule.forFeature([entities_1.DiscountCodeEntity])],
        controllers: [DiscountsController],
        providers: [DiscountsService],
        exports: [DiscountsService],
    })
], DiscountsModule);
//# sourceMappingURL=discounts.module.js.map