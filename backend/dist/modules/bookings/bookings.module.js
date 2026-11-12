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
var BookingsService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.BookingsModule = exports.BookingsController = exports.BookingsService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const auth_guards_1 = require("../../common/auth.guards");
const entities_1 = require("../../database/entities");
const notifications_module_1 = require("../notifications/notifications.module");
let BookingsService = BookingsService_1 = class BookingsService {
    constructor(bookingRepo, shopRepo, barberRepo, serviceRepo, discountRepo, notificationsService) {
        this.bookingRepo = bookingRepo;
        this.shopRepo = shopRepo;
        this.barberRepo = barberRepo;
        this.serviceRepo = serviceRepo;
        this.discountRepo = discountRepo;
        this.notificationsService = notificationsService;
    }
    parseHhMm(hhMm, fallbackMinutes) {
        const parts = hhMm?.split(':') ?? [];
        if (parts.length !== 2)
            return fallbackMinutes;
        const h = Number(parts[0]);
        const m = Number(parts[1]);
        if (Number.isNaN(h) || Number.isNaN(m))
            return fallbackMinutes;
        return h * 60 + m;
    }
    formatHhMm(mins) {
        const h = String(Math.floor(mins / 60)).padStart(2, '0');
        const m = String(mins % 60).padStart(2, '0');
        return `${h}:${m}`;
    }
    async getActiveCooperationDiscount(shop) {
        if (!shop.isCooperation || !shop.isActive)
            return 0;
        const now = new Date();
        const discounts = await this.discountRepo.find({ where: { isActive: true } });
        let best = 0;
        for (const d of discounts) {
            if (new Date(d.startAt) <= now && now <= new Date(d.endAt)) {
                if (d.discountPercent > best) {
                    best = d.discountPercent;
                }
            }
        }
        return Math.min(90, Math.max(0, best));
    }
    computeShiftAllocation(params) {
        const { shift, shiftStart, shiftEnd, durationMinutes, activeBookings } = params;
        const shiftBookings = activeBookings.filter((b) => {
            if (b.shift)
                return b.shift === shift;
            return shift === entities_1.BookingShift.MORNING
                ? b.endMinutes <= BookingsService_1.MORNING_END
                : b.startMinutes >= BookingsService_1.AFTERNOON_START;
        });
        const maxEnd = shiftBookings.length === 0
            ? null
            : Math.max(...shiftBookings.map((b) => b.endMinutes));
        const startMinutes = maxEnd === null
            ? shiftStart
            : Math.max(shiftStart, maxEnd + BookingsService_1.GAP_MINUTES);
        const endMinutes = startMinutes + durationMinutes;
        const isAvailable = shiftStart < shiftEnd && durationMinutes > 0 && endMinutes <= shiftEnd;
        let disabledReason = null;
        if (!isAvailable) {
            disabledReason = `Ca này không còn đủ ${durationMinutes} phút trống trước ${this.formatHhMm(shiftEnd)}`;
        }
        return {
            shift,
            label: shift === entities_1.BookingShift.MORNING ? 'Ca sáng' : 'Ca chiều',
            shiftRange: `${this.formatHhMm(shiftStart)} - ${this.formatHhMm(shiftEnd)}`,
            startMinutes,
            endMinutes,
            assignedRange: isAvailable
                ? `${this.formatHhMm(startMinutes)} - ${this.formatHhMm(endMinutes)}`
                : null,
            bookedCount: shiftBookings.length,
            isAvailable,
            disabledReason,
        };
    }
    async getAvailableSlots(params) {
        const shop = await this.shopRepo.findOne({ where: { id: params.shopId } });
        if (!shop)
            throw new common_1.NotFoundException('Không tìm thấy quán');
        const openMin = this.parseHhMm(shop.openTime, 8 * 60 + 30);
        const closeMin = this.parseHhMm(shop.closeTime, 20 * 60 + 30);
        const duration = Math.max(params.durationMinutes || 15, 10);
        const activeBookings = await this.bookingRepo.find({
            where: {
                barberId: params.barberId,
                bookingDate: params.date,
                status: (0, typeorm_2.Not)(entities_1.BookingStatus.CANCELLED),
            },
        });
        const morningStart = Math.min(openMin, BookingsService_1.MORNING_END);
        const afternoonEnd = Math.max(closeMin, BookingsService_1.AFTERNOON_START);
        const morning = this.computeShiftAllocation({
            shift: entities_1.BookingShift.MORNING,
            shiftStart: morningStart,
            shiftEnd: BookingsService_1.MORNING_END,
            durationMinutes: duration,
            activeBookings,
        });
        const afternoon = this.computeShiftAllocation({
            shift: entities_1.BookingShift.AFTERNOON,
            shiftStart: BookingsService_1.AFTERNOON_START,
            shiftEnd: afternoonEnd,
            durationMinutes: duration,
            activeBookings,
        });
        return {
            date: params.date,
            durationMinutes: duration,
            gapMinutes: BookingsService_1.GAP_MINUTES,
            morningRange: morning.shiftRange,
            afternoonRange: afternoon.shiftRange,
            morning,
            afternoon,
        };
    }
    async createBooking(customerId, dto) {
        if (!dto.serviceIds || dto.serviceIds.length === 0) {
            throw new common_1.BadRequestException('Vui lòng chọn ít nhất 1 dịch vụ');
        }
        const shop = await this.shopRepo.findOne({ where: { id: dto.shopId } });
        if (!shop)
            throw new common_1.NotFoundException('Không tìm thấy quán');
        const barber = await this.barberRepo.findOne({
            where: { id: dto.barberId, shopId: dto.shopId },
        });
        if (!barber)
            throw new common_1.NotFoundException('Không tìm thấy Barber tại quán này');
        const services = await this.serviceRepo.find({
            where: { id: (0, typeorm_2.In)(dto.serviceIds), shopId: dto.shopId },
        });
        if (services.length === 0) {
            throw new common_1.BadRequestException('Danh sách dịch vụ không hợp lệ');
        }
        const totalDurationMinutes = services.reduce((sum, s) => sum + s.durationMinutes, 0);
        const discountPercent = await this.getActiveCooperationDiscount(shop);
        const rawTotalPrice = services.reduce((sum, s) => sum + s.price, 0);
        const totalPrice = discountPercent > 0
            ? Math.max(0, Math.round((rawTotalPrice * (100 - discountPercent)) / 100))
            : rawTotalPrice;
        const targetShift = dto.shift ??
            (dto.startMinutes !== undefined &&
                dto.startMinutes >= BookingsService_1.AFTERNOON_START
                ? entities_1.BookingShift.AFTERNOON
                : entities_1.BookingShift.MORNING);
        const openMin = this.parseHhMm(shop.openTime, 8 * 60 + 30);
        const closeMin = this.parseHhMm(shop.closeTime, 20 * 60 + 30);
        const shiftStart = targetShift === entities_1.BookingShift.MORNING
            ? Math.min(openMin, BookingsService_1.MORNING_END)
            : BookingsService_1.AFTERNOON_START;
        const shiftEnd = targetShift === entities_1.BookingShift.MORNING
            ? BookingsService_1.MORNING_END
            : Math.max(closeMin, BookingsService_1.AFTERNOON_START);
        const existing = await this.bookingRepo.find({
            where: {
                barberId: dto.barberId,
                bookingDate: dto.bookingDate,
                status: (0, typeorm_2.Not)(entities_1.BookingStatus.CANCELLED),
            },
        });
        const allocation = this.computeShiftAllocation({
            shift: targetShift,
            shiftStart,
            shiftEnd,
            durationMinutes: totalDurationMinutes,
            activeBookings: existing,
        });
        if (!allocation.isAvailable) {
            throw new common_1.ConflictException(allocation.disabledReason ??
                'Ca làm việc đã đầy lịch. Vui lòng chọn ca hoặc ngày khác!');
        }
        const start = allocation.startMinutes;
        const end = allocation.endMinutes;
        const status = dto.paymentMethod === entities_1.PaymentMethod.SEPAY_QR
            ? entities_1.BookingStatus.PENDING
            : entities_1.BookingStatus.CONFIRMED;
        const saved = await this.bookingRepo.save(this.bookingRepo.create({
            shopId: shop.id,
            barberId: barber.id,
            customerId,
            bookingDate: dto.bookingDate,
            startMinutes: start,
            endMinutes: end,
            shift: targetShift,
            totalDurationMinutes,
            totalPrice,
            servicesSnapshot: services.map((s) => ({
                id: s.id,
                name: s.name,
                price: discountPercent > 0
                    ? Math.max(0, Math.round((s.price * (100 - discountPercent)) / 100))
                    : s.price,
                durationMinutes: s.durationMinutes,
            })),
            paymentMethod: dto.paymentMethod,
            isPaid: false,
            status,
        }));
        await this.notificationsService.createAndPush({
            recipientId: barber.userId,
            title: `Lịch đặt mới (${allocation.label}: ${this.formatHhMm(start)} - ${this.formatHhMm(end)})`,
            body: `Bạn có khách đặt lịch ngày ${dto.bookingDate} tại ${shop.name}.`,
            type: entities_1.NotificationType.BOOKING,
            metadata: { bookingId: saved.id },
        });
        return saved;
    }
    async getMyBookings(customerId) {
        return this.bookingRepo.find({
            where: { customerId },
            relations: ['shop', 'barber', 'barber.user'],
            order: { createdAt: 'DESC' },
        });
    }
    async cancelBooking(bookingId, customerId) {
        const bk = await this.bookingRepo.findOne({ where: { id: bookingId } });
        if (!bk)
            throw new common_1.NotFoundException('Không tìm thấy lịch đặt');
        if (bk.customerId !== customerId) {
            throw new common_1.ForbiddenException('Bạn không có quyền hủy lịch này');
        }
        if (bk.status === entities_1.BookingStatus.COMPLETED) {
            throw new common_1.BadRequestException('Lịch đã hoàn tất không thể hủy');
        }
        bk.status = entities_1.BookingStatus.CANCELLED;
        return this.bookingRepo.save(bk);
    }
    async confirmPaidByBarber(bookingId, barberUserId) {
        const barber = await this.barberRepo.findOne({
            where: { userId: barberUserId },
        });
        if (!barber)
            throw new common_1.ForbiddenException('Chỉ Barber mới có quyền xác nhận');
        const bk = await this.bookingRepo.findOne({ where: { id: bookingId } });
        if (!bk || bk.barberId !== barber.id) {
            throw new common_1.NotFoundException('Không tìm thấy lịch hẹn thuộc về bạn');
        }
        bk.isPaid = true;
        bk.status = entities_1.BookingStatus.COMPLETED;
        bk.completedAt = new Date();
        return this.bookingRepo.save(bk);
    }
};
exports.BookingsService = BookingsService;
BookingsService.GAP_MINUTES = 5;
BookingsService.MORNING_END = 12 * 60;
BookingsService.AFTERNOON_START = 13 * 60 + 30;
exports.BookingsService = BookingsService = BookingsService_1 = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(entities_1.BookingEntity)),
    __param(1, (0, typeorm_1.InjectRepository)(entities_1.ShopEntity)),
    __param(2, (0, typeorm_1.InjectRepository)(entities_1.BarberEntity)),
    __param(3, (0, typeorm_1.InjectRepository)(entities_1.ServiceEntity)),
    __param(4, (0, typeorm_1.InjectRepository)(entities_1.DiscountCodeEntity)),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        notifications_module_1.NotificationsService])
], BookingsService);
let BookingsController = class BookingsController {
    constructor(service) {
        this.service = service;
    }
    getSlots(shopId, barberId, date, durationMinutes) {
        return this.service.getAvailableSlots({
            shopId,
            barberId,
            date,
            durationMinutes: Number(durationMinutes || 30),
        });
    }
    create(user, dto) {
        return this.service.createBooking(user.id, dto);
    }
    getMine(user) {
        return this.service.getMyBookings(user.id);
    }
    cancel(id, user) {
        return this.service.cancelBooking(id, user.id);
    }
    confirmPaid(id, user) {
        return this.service.confirmPaidByBarber(id, user.id);
    }
};
exports.BookingsController = BookingsController;
__decorate([
    (0, common_1.Get)('slots'),
    __param(0, (0, common_1.Query)('shopId')),
    __param(1, (0, common_1.Query)('barberId')),
    __param(2, (0, common_1.Query)('date')),
    __param(3, (0, common_1.Query)('durationMinutes')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String, String, String]),
    __metadata("design:returntype", void 0)
], BookingsController.prototype, "getSlots", null);
__decorate([
    (0, common_1.Post)(),
    (0, common_1.UseGuards)(auth_guards_1.JwtAuthGuard),
    __param(0, (0, auth_guards_1.CurrentUser)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [entities_1.UserEntity, Object]),
    __metadata("design:returntype", void 0)
], BookingsController.prototype, "create", null);
__decorate([
    (0, common_1.Get)('me'),
    (0, common_1.UseGuards)(auth_guards_1.JwtAuthGuard),
    __param(0, (0, auth_guards_1.CurrentUser)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [entities_1.UserEntity]),
    __metadata("design:returntype", void 0)
], BookingsController.prototype, "getMine", null);
__decorate([
    (0, common_1.Patch)(':id/cancel'),
    (0, common_1.UseGuards)(auth_guards_1.JwtAuthGuard),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, auth_guards_1.CurrentUser)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, entities_1.UserEntity]),
    __metadata("design:returntype", void 0)
], BookingsController.prototype, "cancel", null);
__decorate([
    (0, common_1.Post)(':id/confirm-paid'),
    (0, common_1.UseGuards)(auth_guards_1.JwtAuthGuard),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, auth_guards_1.CurrentUser)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, entities_1.UserEntity]),
    __metadata("design:returntype", void 0)
], BookingsController.prototype, "confirmPaid", null);
exports.BookingsController = BookingsController = __decorate([
    (0, common_1.Controller)('bookings'),
    __metadata("design:paramtypes", [BookingsService])
], BookingsController);
let BookingsModule = class BookingsModule {
};
exports.BookingsModule = BookingsModule;
exports.BookingsModule = BookingsModule = __decorate([
    (0, common_1.Module)({
        imports: [
            typeorm_1.TypeOrmModule.forFeature([
                entities_1.BookingEntity,
                entities_1.ShopEntity,
                entities_1.BarberEntity,
                entities_1.ServiceEntity,
                entities_1.DiscountCodeEntity,
            ]),
        ],
        controllers: [BookingsController],
        providers: [BookingsService],
        exports: [BookingsService],
    })
], BookingsModule);
//# sourceMappingURL=bookings.module.js.map