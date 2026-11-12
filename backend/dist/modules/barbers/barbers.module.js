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
exports.BarbersModule = exports.BarbersController = exports.BarbersService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const auth_guards_1 = require("../../common/auth.guards");
const entities_1 = require("../../database/entities");
const notifications_module_1 = require("../notifications/notifications.module");
const realtime_module_1 = require("../realtime/realtime.module");
let BarbersService = class BarbersService {
    constructor(barberRepo, userRepo, shopRepo, bookingRepo, notiRepo, notificationsService, realtimeGateway) {
        this.barberRepo = barberRepo;
        this.userRepo = userRepo;
        this.shopRepo = shopRepo;
        this.bookingRepo = bookingRepo;
        this.notiRepo = notiRepo;
        this.notificationsService = notificationsService;
        this.realtimeGateway = realtimeGateway;
    }
    async searchCandidates(query) {
        const q = query?.trim();
        if (!q)
            return [];
        const users = await this.userRepo.find({
            where: [{ email: (0, typeorm_2.ILike)(`%${q}%`) }, { phone: (0, typeorm_2.ILike)(`%${q}%`) }],
            take: 10,
        });
        return users.map((u) => ({
            id: u.id,
            fullName: u.fullName,
            email: u.email,
            phone: u.phone,
            role: u.role,
            avatarUrl: u.avatarUrl ?? '',
        }));
    }
    async inviteBarber(managerId, emailOrPhone, baseSalary = 6500000) {
        const shop = await this.shopRepo.findOne({ where: { ownerId: managerId } });
        if (!shop) {
            throw new common_1.ForbiddenException('Bạn chưa sở hữu quán nào');
        }
        const q = emailOrPhone.trim().toLowerCase();
        const candidate = await this.userRepo.findOne({
            where: [{ email: q }, { phone: emailOrPhone.trim() }],
        });
        if (!candidate) {
            throw new common_1.NotFoundException('Không tìm thấy tài khoản với Email hoặc Số điện thoại này');
        }
        if (candidate.id === managerId ||
            candidate.role === entities_1.UserRole.MANAGER ||
            candidate.role === entities_1.UserRole.ADMIN) {
            throw new common_1.BadRequestException('Quản lý hoặc Admin không được phép kiêm nhiệm làm Barber');
        }
        const existingBarber = await this.barberRepo.findOne({
            where: { userId: candidate.id },
        });
        if (existingBarber) {
            throw new common_1.ConflictException(existingBarber.shopId === shop.id
                ? 'Thợ này đã thuộc quán của bạn'
                : 'Người dùng này hiện đã là Barber thuộc một quán khác!');
        }
        const validSalary = baseSalary && baseSalary > 0 ? Math.round(baseSalary) : 6500000;
        await this.notificationsService.createAndPush({
            recipientId: candidate.id,
            title: `Lời mời làm Barber tại ${shop.name}`,
            body: `Quản lý quán "${shop.name}" mời bạn gia nhập đội ngũ Barber với lương cứng ${validSalary.toLocaleString('vi-VN')}đ + 10% hoa hồng. Hãy nhấn Chấp nhận hoặc Từ chối.`,
            type: entities_1.NotificationType.BARBER_INVITE,
            metadata: {
                shopId: shop.id,
                shopName: shop.name,
                baseSalary: validSalary,
            },
        });
        return {
            message: `Đã gửi lời mời làm Barber tới ${candidate.fullName}`,
        };
    }
    async respondInvitation(userId, notificationId, accept) {
        const noti = await this.notiRepo.findOne({
            where: { id: notificationId, recipientId: userId },
        });
        if (!noti || noti.type !== entities_1.NotificationType.BARBER_INVITE) {
            throw new common_1.NotFoundException('Không tìm thấy lời mời hợp lệ');
        }
        noti.isRead = true;
        noti.metadata = {
            ...(noti.metadata ?? {}),
            responded: true,
            accepted: accept,
        };
        await this.notiRepo.save(noti);
        const shopId = noti.metadata?.shopId;
        const shop = shopId
            ? await this.shopRepo.findOne({ where: { id: shopId } })
            : null;
        const user = await this.userRepo.findOneOrFail({ where: { id: userId } });
        if (!accept) {
            if (shop) {
                await this.notificationsService.createAndPush({
                    recipientId: shop.ownerId,
                    title: 'Ứng viên từ chối lời mời Barber',
                    body: `${user.fullName} đã từ chối lời mời làm Barber tại ${shop.name}.`,
                    type: entities_1.NotificationType.SYSTEM,
                    metadata: { shopId: shop.id },
                });
            }
            return { accepted: false };
        }
        if (user.role === entities_1.UserRole.MANAGER || user.role === entities_1.UserRole.ADMIN) {
            throw new common_1.BadRequestException('Manager/Admin không được tự làm Barber');
        }
        const existing = await this.barberRepo.findOne({ where: { userId } });
        if (existing) {
            throw new common_1.ConflictException('Bạn đã thuộc một quán cắt tóc khác');
        }
        const baseSalary = Number(noti.metadata?.baseSalary) || 6500000;
        const newBarber = await this.barberRepo.save(this.barberRepo.create({
            userId,
            shopId,
            baseSalary,
            isActive: true,
            joinedAt: new Date(),
        }));
        user.role = entities_1.UserRole.BARBER;
        await this.userRepo.save(user);
        if (shop) {
            await this.notificationsService.createAndPush({
                recipientId: shop.ownerId,
                title: 'Barber mới đã gia nhập quán!',
                body: `${user.fullName} đã chấp nhận lời mời làm Barber tại ${shop.name}.`,
                type: entities_1.NotificationType.SYSTEM,
                metadata: { shopId: shop.id, barberId: newBarber.id },
            });
        }
        this.realtimeGateway.emitUserRoleUpdated(userId, {
            newRole: entities_1.UserRole.BARBER,
            workingShopId: shopId,
            barberId: newBarber.id,
        });
        return { accepted: true, role: entities_1.UserRole.BARBER, shopId };
    }
    async updateBaseSalary(managerId, barberId, baseSalary) {
        const barber = await this.barberRepo.findOne({
            where: { id: barberId },
            relations: ['shop', 'user'],
        });
        if (!barber || barber.shop.ownerId !== managerId) {
            throw new common_1.ForbiddenException('Không có quyền cập nhật lương Barber này');
        }
        barber.baseSalary = baseSalary;
        return this.barberRepo.save(barber);
    }
    async removeBarber(managerId, barberId) {
        const barber = await this.barberRepo.findOne({
            where: { id: barberId },
            relations: ['shop', 'user'],
        });
        if (!barber || barber.shop.ownerId !== managerId) {
            throw new common_1.ForbiddenException('Không có quyền xoá Barber này');
        }
        const barberUserId = barber.userId;
        const shopName = barber.shop.name;
        await this.barberRepo.delete(barber.id);
        await this.userRepo.update(barberUserId, { role: entities_1.UserRole.USER });
        await this.notificationsService.createAndPush({
            recipientId: barberUserId,
            title: `Thông báo từ quán ${shopName}`,
            body: `Quản lý quán "${shopName}" đã kết thúc hợp tác Barber với tài khoản của bạn.`,
            type: entities_1.NotificationType.SYSTEM,
            metadata: { shopId: barber.shopId },
        });
        this.realtimeGateway.emitUserRoleUpdated(barberUserId, {
            newRole: entities_1.UserRole.USER,
        });
        return { deleted: true, barberId };
    }
    async getMonthlyHeatmap(userId, year, month) {
        const barber = await this.barberRepo.findOne({ where: { userId } });
        if (!barber)
            throw new common_1.NotFoundException('Chưa có hồ sơ Barber');
        const bookings = await this.bookingRepo.find({
            where: { barberId: barber.id },
        });
        const prefix = `${year}-${String(month).padStart(2, '0')}-`;
        const heatmap = {};
        for (const bk of bookings) {
            if (bk.status === entities_1.BookingStatus.CANCELLED)
                continue;
            if (bk.bookingDate.startsWith(prefix)) {
                const day = Number(bk.bookingDate.split('-')[2]);
                heatmap[day] = (heatmap[day] ?? 0) + 1;
            }
        }
        return heatmap;
    }
    async getDayTimeline(userId, date) {
        const barber = await this.barberRepo.findOne({ where: { userId } });
        if (!barber)
            throw new common_1.NotFoundException('Chưa có hồ sơ Barber');
        const list = await this.bookingRepo.find({
            where: { barberId: barber.id, bookingDate: date },
            relations: ['customer'],
            order: { startMinutes: 'ASC' },
        });
        return list
            .filter((b) => b.status !== entities_1.BookingStatus.CANCELLED)
            .map((b) => ({
            id: b.id,
            customerName: b.customer.fullName,
            customerPhone: b.customer.phone,
            bookingDate: b.bookingDate,
            startMinutes: b.startMinutes,
            endMinutes: b.endMinutes,
            totalPrice: b.totalPrice,
            services: b.servicesSnapshot,
            status: b.status,
            isPaid: b.isPaid,
            paymentMethod: b.paymentMethod,
        }));
    }
    async getMyIncome(userId) {
        const barber = await this.barberRepo.findOne({
            where: { userId },
            relations: ['shop'],
        });
        if (!barber)
            throw new common_1.NotFoundException('Chưa có hồ sơ Barber');
        const completed = await this.bookingRepo.find({
            where: { barberId: barber.id, status: entities_1.BookingStatus.COMPLETED },
        });
        const completedRevenue = completed.reduce((s, b) => s + b.totalPrice, 0);
        const commissionAmount = Math.round(completedRevenue * 0.1);
        return {
            barberId: barber.id,
            shop: barber.shop,
            isActive: barber.isActive,
            baseSalary: barber.baseSalary,
            completedBookingsCount: completed.length,
            completedRevenue,
            commissionRate: 0.1,
            commissionAmount,
            totalIncome: barber.baseSalary + commissionAmount,
            expectedPaydayNote: 'Ngày nhận lương dự kiến: Mùng 1 hàng tháng',
        };
    }
};
exports.BarbersService = BarbersService;
exports.BarbersService = BarbersService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(entities_1.BarberEntity)),
    __param(1, (0, typeorm_1.InjectRepository)(entities_1.UserEntity)),
    __param(2, (0, typeorm_1.InjectRepository)(entities_1.ShopEntity)),
    __param(3, (0, typeorm_1.InjectRepository)(entities_1.BookingEntity)),
    __param(4, (0, typeorm_1.InjectRepository)(entities_1.NotificationEntity)),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        notifications_module_1.NotificationsService,
        realtime_module_1.RealtimeGateway])
], BarbersService);
let BarbersController = class BarbersController {
    constructor(service) {
        this.service = service;
    }
    searchCandidates(q) {
        return this.service.searchCandidates(q);
    }
    invite(user, body) {
        return this.service.inviteBarber(user.id, body.emailOrPhone, body.baseSalary);
    }
    respondInvite(user, notificationId, body) {
        return this.service.respondInvitation(user.id, notificationId, body.accept);
    }
    updateSalary(user, id, body) {
        return this.service.updateBaseSalary(user.id, id, body.baseSalary);
    }
    removeBarber(user, id) {
        return this.service.removeBarber(user.id, id);
    }
    getMyProfile(user) {
        return this.service.getMyIncome(user.id);
    }
    getHeatmap(user, year, month) {
        return this.service.getMonthlyHeatmap(user.id, Number(year), Number(month));
    }
    getTimeline(user, date) {
        return this.service.getDayTimeline(user.id, date);
    }
    getIncome(user) {
        return this.service.getMyIncome(user.id);
    }
};
exports.BarbersController = BarbersController;
__decorate([
    (0, common_1.Get)('search-candidates'),
    __param(0, (0, common_1.Query)('q')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], BarbersController.prototype, "searchCandidates", null);
__decorate([
    (0, common_1.Post)('invite'),
    __param(0, (0, auth_guards_1.CurrentUser)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [entities_1.UserEntity, Object]),
    __metadata("design:returntype", void 0)
], BarbersController.prototype, "invite", null);
__decorate([
    (0, common_1.Post)('invitations/:notificationId/respond'),
    __param(0, (0, auth_guards_1.CurrentUser)()),
    __param(1, (0, common_1.Param)('notificationId')),
    __param(2, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [entities_1.UserEntity, String, Object]),
    __metadata("design:returntype", void 0)
], BarbersController.prototype, "respondInvite", null);
__decorate([
    (0, common_1.Patch)(':id/salary'),
    __param(0, (0, auth_guards_1.CurrentUser)()),
    __param(1, (0, common_1.Param)('id')),
    __param(2, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [entities_1.UserEntity, String, Object]),
    __metadata("design:returntype", void 0)
], BarbersController.prototype, "updateSalary", null);
__decorate([
    (0, common_1.Delete)(':id'),
    __param(0, (0, auth_guards_1.CurrentUser)()),
    __param(1, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [entities_1.UserEntity, String]),
    __metadata("design:returntype", void 0)
], BarbersController.prototype, "removeBarber", null);
__decorate([
    (0, common_1.Get)('me/profile'),
    __param(0, (0, auth_guards_1.CurrentUser)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [entities_1.UserEntity]),
    __metadata("design:returntype", void 0)
], BarbersController.prototype, "getMyProfile", null);
__decorate([
    (0, common_1.Get)('me/heatmap'),
    __param(0, (0, auth_guards_1.CurrentUser)()),
    __param(1, (0, common_1.Query)('year')),
    __param(2, (0, common_1.Query)('month')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [entities_1.UserEntity, String, String]),
    __metadata("design:returntype", void 0)
], BarbersController.prototype, "getHeatmap", null);
__decorate([
    (0, common_1.Get)('me/timeline'),
    __param(0, (0, auth_guards_1.CurrentUser)()),
    __param(1, (0, common_1.Query)('date')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [entities_1.UserEntity, String]),
    __metadata("design:returntype", void 0)
], BarbersController.prototype, "getTimeline", null);
__decorate([
    (0, common_1.Get)('me/income'),
    __param(0, (0, auth_guards_1.CurrentUser)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [entities_1.UserEntity]),
    __metadata("design:returntype", void 0)
], BarbersController.prototype, "getIncome", null);
exports.BarbersController = BarbersController = __decorate([
    (0, common_1.Controller)('barbers'),
    (0, common_1.UseGuards)(auth_guards_1.JwtAuthGuard),
    __metadata("design:paramtypes", [BarbersService])
], BarbersController);
let BarbersModule = class BarbersModule {
};
exports.BarbersModule = BarbersModule;
exports.BarbersModule = BarbersModule = __decorate([
    (0, common_1.Module)({
        imports: [
            typeorm_1.TypeOrmModule.forFeature([
                entities_1.BarberEntity,
                entities_1.UserEntity,
                entities_1.ShopEntity,
                entities_1.BookingEntity,
                entities_1.NotificationEntity,
            ]),
        ],
        controllers: [BarbersController],
        providers: [BarbersService],
        exports: [BarbersService],
    })
], BarbersModule);
//# sourceMappingURL=barbers.module.js.map