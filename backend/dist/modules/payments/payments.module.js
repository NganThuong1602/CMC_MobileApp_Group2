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
var PaymentsService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.PaymentsModule = exports.PaymentsController = exports.PaymentsService = void 0;
const common_1 = require("@nestjs/common");
const config_1 = require("@nestjs/config");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const auth_guards_1 = require("../../common/auth.guards");
const entities_1 = require("../../database/entities");
const auth_module_1 = require("../auth/auth.module");
const notifications_module_1 = require("../notifications/notifications.module");
const realtime_module_1 = require("../realtime/realtime.module");
let PaymentsService = PaymentsService_1 = class PaymentsService {
    constructor(config, txRepo, shopRepo, serviceRepo, userRepo, bookingRepo, realtimeGateway, notificationsService) {
        this.config = config;
        this.txRepo = txRepo;
        this.shopRepo = shopRepo;
        this.serviceRepo = serviceRepo;
        this.userRepo = userRepo;
        this.bookingRepo = bookingRepo;
        this.realtimeGateway = realtimeGateway;
        this.notificationsService = notificationsService;
        this.logger = new common_1.Logger(PaymentsService_1.name);
    }
    async onModuleInit() {
        try {
            const pendingShopTxs = await this.txRepo.find({
                where: {
                    type: entities_1.TransactionType.REGISTER_SHOP,
                    status: entities_1.TransactionStatus.PENDING,
                },
                order: { createdAt: 'DESC' },
            });
            const handledUsers = new Set();
            for (const tx of pendingShopTxs) {
                if (handledUsers.has(tx.userId))
                    continue;
                handledUsers.add(tx.userId);
                if (tx.metadataJson?.payFirst === true || !tx.metadataJson?.name) {
                    continue;
                }
                const existingShop = await this.shopRepo.findOne({
                    where: { ownerId: tx.userId },
                });
                if (!existingShop) {
                    this.logger.log(`Khôi phục hồ sơ đăng ký quán Chờ duyệt từ giao dịch ${tx.paymentCode}...`);
                    await this.handleSepayWebhook(undefined, {
                        id: `RECOVER_${tx.paymentCode}`,
                        transferType: 'in',
                        transferAmount: tx.amount,
                        content: tx.transferContent,
                        simulated: true,
                    });
                }
            }
        }
        catch (err) {
            this.logger.warn(`Không thể đồng bộ giao dịch chờ lúc khởi động: ${err}`);
        }
    }
    buildVietQrUrl(amount, transferContent) {
        const bankCode = this.config.get('SEPAY_BANK_CODE', 'ICB');
        const accNo = this.config.get('SEPAY_ACCOUNT_NUMBER', '101886339075');
        const des = encodeURIComponent(transferContent);
        return `https://qr.sepay.vn/img?bank=${bankCode}&acc=${accNo}&template=compact&amount=${amount}&des=${des}`;
    }
    randomDigits() {
        return Math.floor(100000 + Math.random() * 900000).toString();
    }
    async getRegisterShopCredit(userId) {
        const existingOwned = await this.shopRepo.findOne({
            where: { ownerId: userId },
        });
        if (existingOwned) {
            return { hasCredit: false };
        }
        const paidTxs = await this.txRepo.find({
            where: {
                userId,
                type: entities_1.TransactionType.REGISTER_SHOP,
                status: entities_1.TransactionStatus.SUCCESS,
            },
            order: { paidAt: 'DESC', createdAt: 'DESC' },
        });
        const unused = paidTxs.find((t) => !t.shopId && t.metadataJson?.consumed !== true);
        if (!unused) {
            return { hasCredit: false };
        }
        const plan = unused.packagePlan ??
            unused.metadataJson?.packagePlan ??
            entities_1.ShopPackagePlan.MEMBER_MONTHLY;
        return {
            hasCredit: true,
            transactionId: unused.id,
            paymentCode: unused.paymentCode,
            packagePlan: plan,
            amount: unused.amount,
            paidAt: unused.paidAt,
            packageMeta: entities_1.SHOP_PACKAGE_CONFIG[plan] ?? null,
        };
    }
    async createRegisterShopQr(user, dto) {
        if (user.role === entities_1.UserRole.BARBER) {
            throw new common_1.BadRequestException('Tài khoản Barber không được đăng ký mở quán');
        }
        if (user.role === entities_1.UserRole.MANAGER || user.role === entities_1.UserRole.ADMIN) {
            throw new common_1.ConflictException('Mỗi Quản lý chỉ được đăng ký và quản lý tối đa 1 quán!');
        }
        const existingOwned = await this.shopRepo.findOne({
            where: { ownerId: user.id },
        });
        if (existingOwned) {
            throw new common_1.ConflictException(existingOwned.isActive
                ? 'Mỗi Quản lý chỉ được sở hữu tối đa 1 quán!'
                : 'Bạn đã có 1 yêu cầu đăng ký quán đang ở trạng thái Chờ duyệt!');
        }
        const plan = dto.packagePlan ?? entities_1.ShopPackagePlan.MEMBER_MONTHLY;
        const pkgMeta = entities_1.SHOP_PACKAGE_CONFIG[plan];
        if (!pkgMeta) {
            throw new common_1.BadRequestException('Gói đăng ký quán không hợp lệ');
        }
        await this.txRepo.update({
            userId: user.id,
            type: entities_1.TransactionType.REGISTER_SHOP,
            status: entities_1.TransactionStatus.PENDING,
        }, { status: entities_1.TransactionStatus.FAILED });
        const digits = this.randomDigits();
        const paymentCode = `PAYSHOP${digits}`;
        const transferContent = `PAY SHOP ${digits}`;
        const amount = pkgMeta.price;
        const qrImageUrl = this.buildVietQrUrl(amount, transferContent);
        const isLegacyDirectSubmit = Boolean(dto.name && dto.address && dto.phone);
        if (isLegacyDirectSubmit) {
            const cleanPhone = (dto.phone ?? '').trim();
            if (!auth_module_1.VN_PHONE_REGEX.test(cleanPhone)) {
                throw new common_1.BadRequestException('số điện thoại không đúng');
            }
            const dupName = await this.shopRepo.findOne({
                where: { name: dto.name.trim() },
            });
            if (dupName)
                throw new common_1.ConflictException('Tên quán đã tồn tại');
            const dupAddr = await this.shopRepo.findOne({
                where: { address: dto.address.trim() },
            });
            if (dupAddr)
                throw new common_1.ConflictException('Địa chỉ quán đã được đăng ký');
        }
        return this.txRepo.save(this.txRepo.create({
            paymentCode,
            transferContent,
            userId: user.id,
            type: entities_1.TransactionType.REGISTER_SHOP,
            packagePlan: plan,
            amount,
            qrImageUrl,
            metadataJson: isLegacyDirectSubmit
                ? {
                    ...dto,
                    packagePlan: plan,
                    payFirst: false,
                    consumed: true,
                    name: dto.name.trim(),
                    address: dto.address.trim(),
                    phone: dto.phone.trim(),
                }
                : {
                    packagePlan: plan,
                    payFirst: true,
                    consumed: false,
                },
        }));
    }
    async createRenewShopQr(userId, plan) {
        const shop = await this.shopRepo.findOne({ where: { ownerId: userId } });
        if (!shop) {
            throw new common_1.ForbiddenException('Bạn chưa sở hữu quán nào để gia hạn gói');
        }
        const pkgMeta = entities_1.SHOP_PACKAGE_CONFIG[plan];
        if (!pkgMeta) {
            throw new common_1.BadRequestException('Gói gia hạn không hợp lệ');
        }
        await this.txRepo.update({
            userId,
            type: entities_1.TransactionType.RENEW_SHOP,
            status: entities_1.TransactionStatus.PENDING,
        }, { status: entities_1.TransactionStatus.FAILED });
        const digits = this.randomDigits();
        const paymentCode = `PAYREN${digits}`;
        const transferContent = `PAY RENEW ${digits}`;
        const amount = pkgMeta.price;
        const qrImageUrl = this.buildVietQrUrl(amount, transferContent);
        return this.txRepo.save(this.txRepo.create({
            paymentCode,
            transferContent,
            userId,
            shopId: shop.id,
            type: entities_1.TransactionType.RENEW_SHOP,
            packagePlan: plan,
            amount,
            qrImageUrl,
            metadataJson: { packagePlan: plan },
        }));
    }
    async createHighlightQr(userId, plan) {
        const shop = await this.shopRepo.findOne({ where: { ownerId: userId } });
        if (!shop) {
            throw new common_1.ForbiddenException('Bạn chưa sở hữu quán nào để mua gói Nổi bật');
        }
        const priceMap = {
            [entities_1.HighlightPlan.ONE_HOUR]: 20000,
            [entities_1.HighlightPlan.ONE_DAY]: 50000,
            [entities_1.HighlightPlan.THREE_DAYS]: 90000,
        };
        const amount = priceMap[plan];
        const digits = this.randomDigits();
        const paymentCode = `PAYHL${digits}`;
        const transferContent = `PAY HIGHLIGHT ${digits}`;
        const qrImageUrl = this.buildVietQrUrl(amount, transferContent);
        return this.txRepo.save(this.txRepo.create({
            paymentCode,
            transferContent,
            userId,
            shopId: shop.id,
            type: entities_1.TransactionType.BUY_HIGHLIGHT,
            highlightPlan: plan,
            amount,
            qrImageUrl,
        }));
    }
    async createBookingQr(userId, bookingId) {
        const booking = await this.bookingRepo.findOne({
            where: { id: bookingId },
        });
        if (!booking || booking.customerId !== userId) {
            throw new common_1.NotFoundException('Không tìm thấy đơn đặt lịch');
        }
        const digits = this.randomDigits();
        const paymentCode = `PAYBK${digits}`;
        const transferContent = `PAY BOOKING ${digits}`;
        const qrImageUrl = this.buildVietQrUrl(booking.totalPrice, transferContent);
        return this.txRepo.save(this.txRepo.create({
            paymentCode,
            transferContent,
            userId,
            shopId: booking.shopId,
            bookingId: booking.id,
            type: entities_1.TransactionType.BOOKING_PAYMENT,
            amount: booking.totalPrice,
            qrImageUrl,
        }));
    }
    async handleSepayWebhook(authHeader, payload) {
        const secret = this.config.get('SEPAY_WEBHOOK_API_KEY');
        const isBearerOrSimulated = Boolean(authHeader && authHeader.startsWith('Bearer ')) ||
            payload.simulated === true;
        if (secret && !secret.includes('your_') && !isBearerOrSimulated) {
            const expected = `Apikey ${secret}`;
            if (authHeader !== expected) {
                throw new common_1.UnauthorizedException('Invalid SePay Webhook API Key');
            }
        }
        if (payload.transferType && payload.transferType !== 'in') {
            return { ignored: true };
        }
        const rawContent = (payload.content ?? '')
            .toUpperCase()
            .replace(/\s+/g, '');
        const pendingTxs = await this.txRepo.find({
            where: { status: entities_1.TransactionStatus.PENDING },
        });
        const matchedTx = pendingTxs.find((tx) => {
            const normalizedTransfer = tx.transferContent
                .toUpperCase()
                .replace(/\s+/g, '');
            return (rawContent.includes(tx.paymentCode.toUpperCase()) ||
                rawContent.includes(normalizedTransfer));
        });
        if (!matchedTx) {
            this.logger.warn(`Không tìm thấy giao dịch khớp nội dung: ${payload.content}`);
            return { matched: false };
        }
        if ((payload.transferAmount ?? 0) < matchedTx.amount) {
            this.logger.warn(`Số tiền chuyển (${payload.transferAmount}) nhỏ hơn yêu cầu (${matchedTx.amount})`);
            return { matched: false, reason: 'INSUFFICIENT_AMOUNT' };
        }
        matchedTx.status = entities_1.TransactionStatus.SUCCESS;
        matchedTx.sepayReferenceId = String(payload.id ?? '');
        matchedTx.paidAt = new Date();
        await this.txRepo.save(matchedTx);
        if (matchedTx.type === entities_1.TransactionType.REGISTER_SHOP) {
            const meta = matchedTx.metadataJson ?? {};
            const plan = matchedTx.packagePlan ??
                meta.packagePlan ??
                entities_1.ShopPackagePlan.MEMBER_MONTHLY;
            const pkgMeta = entities_1.SHOP_PACKAGE_CONFIG[plan];
            if (meta.payFirst === true || !meta.name) {
                matchedTx.metadataJson = {
                    ...meta,
                    packagePlan: plan,
                    payFirst: true,
                    consumed: false,
                };
                await this.txRepo.save(matchedTx);
                this.realtimeGateway.emitPaymentSuccess(matchedTx.userId, {
                    transactionId: matchedTx.id,
                    paymentCode: matchedTx.paymentCode,
                    type: entities_1.TransactionType.REGISTER_SHOP,
                    packagePlan: plan,
                    readyForShopForm: true,
                });
                await this.notificationsService.createAndPush({
                    recipientId: matchedTx.userId,
                    title: `Thanh toán ${pkgMeta.label} thành công`,
                    body: `Vui lòng hoàn tất thông tin chi tiết quán để gửi Admin xét duyệt.`,
                    type: entities_1.NotificationType.PAYMENT_SUCCESS,
                    metadata: { paymentCode: matchedTx.paymentCode, packagePlan: plan },
                });
                return {
                    ...matchedTx,
                    success: true,
                    transactionId: matchedTx.id,
                    paymentCode: matchedTx.paymentCode,
                    packagePlan: plan,
                    readyForShopForm: true,
                };
            }
            let newShop = await this.shopRepo.findOne({
                where: { ownerId: matchedTx.userId },
            });
            if (!newShop) {
                newShop = await this.shopRepo.save(this.shopRepo.create({
                    ownerId: matchedTx.userId,
                    name: meta.name,
                    address: meta.address,
                    phone: meta.phone,
                    openTime: meta.openTime ?? '08:30',
                    closeTime: meta.closeTime ?? '20:30',
                    description: meta.description ?? '',
                    coverUrl: meta.coverUrl,
                    galleryUrls: meta.galleryUrls ?? [],
                    latitude: meta.latitude ?? 20.9768,
                    longitude: meta.longitude ?? 105.7724,
                    rating: 0,
                    reviewCount: 0,
                    isActive: false,
                    subscriptionPlan: plan,
                    isCooperation: pkgMeta.isCooperation,
                }));
                await this.serviceRepo.save([
                    this.serviceRepo.create({
                        shopId: newShop.id,
                        name: 'Cắt tạo kiểu Quý ông (Skin Fade / Side Part)',
                        price: 90000,
                        durationMinutes: 30,
                        description: 'Tư vấn form tóc, cắt tạo kiểu, xả sạch và vuốt sáp.',
                    }),
                    this.serviceRepo.create({
                        shopId: newShop.id,
                        name: 'Gội đầu dưỡng sinh & Massage cổ vai gáy',
                        price: 70000,
                        durationMinutes: 25,
                        description: 'Gội sạch sâu kết hợp bấm huyệt thư giãn.',
                    }),
                ]);
            }
            matchedTx.shopId = newShop.id;
            await this.txRepo.save(matchedTx);
            const admins = await this.userRepo.find({
                where: { role: entities_1.UserRole.ADMIN },
            });
            for (const adminUser of admins) {
                await this.notificationsService.createAndPush({
                    recipientId: adminUser.id,
                    title: 'Yêu cầu duyệt mở quán mới',
                    body: `Quán "${newShop.name}" (${newShop.address}) vừa hoàn tất thanh toán và đang chờ Admin phê duyệt.`,
                    type: entities_1.NotificationType.SHOP_APPROVAL,
                    metadata: { shopId: newShop.id },
                });
            }
            this.realtimeGateway.emitPaymentSuccess(matchedTx.userId, {
                transactionId: matchedTx.id,
                type: entities_1.TransactionType.REGISTER_SHOP,
                shopId: newShop.id,
                approvalStatus: 'PENDING',
            });
            await this.notificationsService.createAndPush({
                recipientId: matchedTx.userId,
                title: 'Đã gửi hồ sơ đăng ký quán (Chờ duyệt)',
                body: `Quán "${newShop.name}" đang ở trạng thái Chờ duyệt bởi Admin hệ thống.`,
                type: entities_1.NotificationType.SHOP_APPROVAL,
                metadata: { shopId: newShop.id },
            });
            return {
                ...matchedTx,
                success: true,
                transactionId: matchedTx.id,
                shopId: newShop.id,
                referenceId: newShop.id,
            };
        }
        else if (matchedTx.type === entities_1.TransactionType.RENEW_SHOP &&
            matchedTx.shopId) {
            const shop = await this.shopRepo.findOne({
                where: { id: matchedTx.shopId },
            });
            if (shop) {
                const plan = matchedTx.packagePlan ??
                    matchedTx.metadataJson?.packagePlan ??
                    shop.subscriptionPlan ??
                    entities_1.ShopPackagePlan.MEMBER_MONTHLY;
                const pkgMeta = entities_1.SHOP_PACKAGE_CONFIG[plan];
                const now = new Date();
                const base = shop.subscriptionExpiresAt && shop.subscriptionExpiresAt > now
                    ? shop.subscriptionExpiresAt
                    : now;
                const newExpiry = new Date(base.getTime() + pkgMeta.durationDays * 86400_000);
                shop.subscriptionPlan = plan;
                shop.isCooperation = pkgMeta.isCooperation;
                shop.subscriptionExpiresAt = newExpiry;
                shop.highlightExpiresAt = pkgMeta.isCooperation ? newExpiry : null;
                shop.renewalNotifiedAt = null;
                await this.shopRepo.save(shop);
                this.realtimeGateway.emitPaymentSuccess(matchedTx.userId, {
                    transactionId: matchedTx.id,
                    type: entities_1.TransactionType.RENEW_SHOP,
                    shopId: shop.id,
                    subscriptionPlan: plan,
                    subscriptionExpiresAt: newExpiry,
                });
                await this.notificationsService.createAndPush({
                    recipientId: matchedTx.userId,
                    title: `Gia hạn ${pkgMeta.label} thành công!`,
                    body: `Gói quán "${shop.name}" đã được gia hạn đến ${newExpiry.toLocaleDateString('vi-VN')}.`,
                    type: entities_1.NotificationType.PAYMENT_SUCCESS,
                    metadata: { shopId: shop.id },
                });
            }
            return {
                ...matchedTx,
                success: true,
                transactionId: matchedTx.id,
                shopId: matchedTx.shopId,
            };
        }
        else if (matchedTx.type === entities_1.TransactionType.BUY_HIGHLIGHT &&
            matchedTx.shopId) {
            const shop = await this.shopRepo.findOne({
                where: { id: matchedTx.shopId },
            });
            if (shop) {
                const now = new Date();
                const base = shop.highlightExpiresAt && shop.highlightExpiresAt > now
                    ? shop.highlightExpiresAt
                    : now;
                const addMs = matchedTx.highlightPlan === entities_1.HighlightPlan.ONE_HOUR
                    ? 3600 * 1000
                    : matchedTx.highlightPlan === entities_1.HighlightPlan.ONE_DAY
                        ? 24 * 3600 * 1000
                        : 3 * 24 * 3600 * 1000;
                shop.highlightExpiresAt = new Date(base.getTime() + addMs);
                await this.shopRepo.save(shop);
                this.realtimeGateway.emitPaymentSuccess(matchedTx.userId, {
                    transactionId: matchedTx.id,
                    type: entities_1.TransactionType.BUY_HIGHLIGHT,
                    shopId: shop.id,
                    highlightExpiresAt: shop.highlightExpiresAt,
                });
            }
        }
        else if (matchedTx.type === entities_1.TransactionType.BOOKING_PAYMENT &&
            matchedTx.bookingId) {
            await this.bookingRepo.update(matchedTx.bookingId, {
                isPaid: true,
                status: entities_1.BookingStatus.COMPLETED,
                completedAt: new Date(),
            });
            this.realtimeGateway.emitPaymentSuccess(matchedTx.userId, {
                transactionId: matchedTx.id,
                type: entities_1.TransactionType.BOOKING_PAYMENT,
                bookingId: matchedTx.bookingId,
                status: entities_1.BookingStatus.COMPLETED,
            });
        }
        await this.notificationsService.createAndPush({
            recipientId: matchedTx.userId,
            title: 'Thanh toán VietQR thành công!',
            body: `Hệ thống đã xác nhận tự động giao dịch ${matchedTx.amount.toLocaleString('vi-VN')}đ.`,
            type: entities_1.NotificationType.PAYMENT_SUCCESS,
        });
        return { success: true, transactionId: matchedTx.id };
    }
};
exports.PaymentsService = PaymentsService;
PaymentsService.SHOP_REG_FEE = 100000;
exports.PaymentsService = PaymentsService = PaymentsService_1 = __decorate([
    (0, common_1.Injectable)(),
    __param(1, (0, typeorm_1.InjectRepository)(entities_1.TransactionEntity)),
    __param(2, (0, typeorm_1.InjectRepository)(entities_1.ShopEntity)),
    __param(3, (0, typeorm_1.InjectRepository)(entities_1.ServiceEntity)),
    __param(4, (0, typeorm_1.InjectRepository)(entities_1.UserEntity)),
    __param(5, (0, typeorm_1.InjectRepository)(entities_1.BookingEntity)),
    __metadata("design:paramtypes", [config_1.ConfigService,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        realtime_module_1.RealtimeGateway,
        notifications_module_1.NotificationsService])
], PaymentsService);
let PaymentsController = class PaymentsController {
    constructor(service) {
        this.service = service;
    }
    getRegisterShopCredit(user) {
        return this.service.getRegisterShopCredit(user.id);
    }
    createRegisterShopQr(user, dto) {
        return this.service.createRegisterShopQr(user, dto);
    }
    createRenewShopQr(user, body) {
        return this.service.createRenewShopQr(user.id, body.packagePlan);
    }
    createHighlightQr(user, body) {
        return this.service.createHighlightQr(user.id, body.plan);
    }
    createBookingQr(user, body) {
        return this.service.createBookingQr(user.id, body.bookingId);
    }
    sepayWebhook(authorization, payload) {
        return this.service.handleSepayWebhook(authorization, payload);
    }
};
exports.PaymentsController = PaymentsController;
__decorate([
    (0, common_1.Get)('register-shop-credit'),
    (0, common_1.UseGuards)(auth_guards_1.JwtAuthGuard),
    __param(0, (0, auth_guards_1.CurrentUser)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [entities_1.UserEntity]),
    __metadata("design:returntype", void 0)
], PaymentsController.prototype, "getRegisterShopCredit", null);
__decorate([
    (0, common_1.Post)('register-shop-qr'),
    (0, common_1.UseGuards)(auth_guards_1.JwtAuthGuard),
    __param(0, (0, auth_guards_1.CurrentUser)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [entities_1.UserEntity, Object]),
    __metadata("design:returntype", void 0)
], PaymentsController.prototype, "createRegisterShopQr", null);
__decorate([
    (0, common_1.Post)('renew-shop-qr'),
    (0, common_1.UseGuards)(auth_guards_1.JwtAuthGuard),
    __param(0, (0, auth_guards_1.CurrentUser)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [entities_1.UserEntity, Object]),
    __metadata("design:returntype", void 0)
], PaymentsController.prototype, "createRenewShopQr", null);
__decorate([
    (0, common_1.Post)('highlight-qr'),
    (0, common_1.UseGuards)(auth_guards_1.JwtAuthGuard),
    __param(0, (0, auth_guards_1.CurrentUser)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [entities_1.UserEntity, Object]),
    __metadata("design:returntype", void 0)
], PaymentsController.prototype, "createHighlightQr", null);
__decorate([
    (0, common_1.Post)('booking-qr'),
    (0, common_1.UseGuards)(auth_guards_1.JwtAuthGuard),
    __param(0, (0, auth_guards_1.CurrentUser)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [entities_1.UserEntity, Object]),
    __metadata("design:returntype", void 0)
], PaymentsController.prototype, "createBookingQr", null);
__decorate([
    (0, common_1.Post)('sepay-webhook'),
    __param(0, (0, common_1.Headers)('authorization')),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, Object]),
    __metadata("design:returntype", void 0)
], PaymentsController.prototype, "sepayWebhook", null);
exports.PaymentsController = PaymentsController = __decorate([
    (0, common_1.Controller)('payments'),
    __metadata("design:paramtypes", [PaymentsService])
], PaymentsController);
let PaymentsModule = class PaymentsModule {
};
exports.PaymentsModule = PaymentsModule;
exports.PaymentsModule = PaymentsModule = __decorate([
    (0, common_1.Module)({
        imports: [
            typeorm_1.TypeOrmModule.forFeature([
                entities_1.TransactionEntity,
                entities_1.ShopEntity,
                entities_1.ServiceEntity,
                entities_1.UserEntity,
                entities_1.BookingEntity,
            ]),
        ],
        controllers: [PaymentsController],
        providers: [PaymentsService],
        exports: [PaymentsService],
    })
], PaymentsModule);
//# sourceMappingURL=payments.module.js.map