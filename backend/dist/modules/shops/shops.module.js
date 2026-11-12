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
var ShopsService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.ShopsModule = exports.ShopsController = exports.ShopsService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const auth_guards_1 = require("../../common/auth.guards");
const entities_1 = require("../../database/entities");
const auth_module_1 = require("../auth/auth.module");
const notifications_module_1 = require("../notifications/notifications.module");
const realtime_module_1 = require("../realtime/realtime.module");
let ShopsService = ShopsService_1 = class ShopsService {
    constructor(shopRepo, serviceRepo, barberRepo, reviewRepo, bookingRepo, userRepo, txRepo, discountRepo, notificationsService, realtimeGateway) {
        this.shopRepo = shopRepo;
        this.serviceRepo = serviceRepo;
        this.barberRepo = barberRepo;
        this.reviewRepo = reviewRepo;
        this.bookingRepo = bookingRepo;
        this.userRepo = userRepo;
        this.txRepo = txRepo;
        this.discountRepo = discountRepo;
        this.notificationsService = notificationsService;
        this.realtimeGateway = realtimeGateway;
        this.logger = new common_1.Logger(ShopsService_1.name);
        this.expiryTimer = null;
    }
    onModuleInit() {
        void this.checkSubscriptionExpiries();
        this.expiryTimer = setInterval(() => {
            void this.checkSubscriptionExpiries();
        }, 10 * 60 * 1000);
        if (this.expiryTimer.unref) {
            this.expiryTimer.unref();
        }
    }
    onModuleDestroy() {
        if (this.expiryTimer) {
            clearInterval(this.expiryTimer);
            this.expiryTimer = null;
        }
    }
    async checkSubscriptionExpiries() {
        try {
            const activeShops = await this.shopRepo.find({
                where: { isActive: true },
                relations: ['owner'],
            });
            const now = new Date();
            const sevenDaysMs = 7 * 24 * 60 * 60 * 1000;
            for (const shop of activeShops) {
                if (!shop.subscriptionExpiresAt)
                    continue;
                const remainingMs = shop.subscriptionExpiresAt.getTime() - now.getTime();
                if (remainingMs <= 0) {
                    await this.deleteShopAndNotify(shop, `Quán "${shop.name}" đã tự động xoá do hết hạn gói`, `Gói đăng ký của quán "${shop.name}" đã hết hạn và chưa được gia hạn đúng thời gian quy định. Hệ thống đã gỡ quán và đưa tài khoản về Khách hàng.`, entities_1.NotificationType.SYSTEM, { shopId: shop.id, reason: 'SUBSCRIPTION_EXPIRED' });
                    this.logger.warn(`Auto-deleted expired shop ${shop.name} (${shop.id})`);
                }
                else if (remainingMs <= sevenDaysMs && !shop.renewalNotifiedAt) {
                    const daysLeft = Math.max(1, Math.ceil(remainingMs / (24 * 60 * 60 * 1000)));
                    await this.shopRepo.update(shop.id, { renewalNotifiedAt: now });
                    const expStr = shop.subscriptionExpiresAt.toLocaleDateString('vi-VN');
                    await this.notificationsService.createAndPush({
                        recipientId: shop.ownerId,
                        title: `Gói quán "${shop.name}" sắp hết hạn (còn ${daysLeft} ngày)`,
                        body: `Gói đăng ký quán sẽ hết hạn vào ngày ${expStr}. Vui lòng vào Quản lý quán -> Gia hạn gói trước hạn để tránh quán bị tự động xoá.`,
                        type: entities_1.NotificationType.SYSTEM,
                        metadata: { shopId: shop.id, action: 'RENEW_SUBSCRIPTION' },
                    });
                }
            }
        }
        catch (err) {
            this.logger.error('Lỗi kiểm tra hết hạn gói quán', err);
        }
    }
    async getActiveBestDiscount() {
        const now = new Date();
        const list = await this.discountRepo.find({
            where: { isActive: true },
            order: { discountPercent: 'DESC', createdAt: 'DESC' },
        });
        return (list.find((d) => new Date(d.startAt) <= now && now <= new Date(d.endAt)) ??
            null);
    }
    async computeRatingStatsMap(shopIds) {
        const map = new Map();
        if (shopIds.length > 0) {
            const reviews = await this.reviewRepo.find({
                where: { shopId: (0, typeorm_2.In)(shopIds) },
            });
            for (const r of reviews) {
                const cur = map.get(r.shopId) ?? { sum: 0, count: 0 };
                cur.sum += r.rating;
                cur.count += 1;
                map.set(r.shopId, cur);
            }
        }
        const result = new Map();
        for (const id of shopIds) {
            const entry = map.get(id);
            if (!entry || entry.count === 0) {
                result.set(id, { rating: 0, reviewCount: 0 });
            }
            else {
                result.set(id, {
                    rating: Number((entry.sum / entry.count).toFixed(1)),
                    reviewCount: entry.count,
                });
            }
        }
        return result;
    }
    isShopHighlighted(shop) {
        if (shop.isCooperation)
            return true;
        return (shop.highlightExpiresAt != null &&
            new Date(shop.highlightExpiresAt) > new Date());
    }
    enrichShop(shop, ratingStats, activeDiscount, extra) {
        const highlighted = this.isShopHighlighted(shop);
        const hasCoopDiscount = shop.isCooperation && shop.isActive && activeDiscount != null;
        const packageMeta = shop.subscriptionPlan
            ? entities_1.SHOP_PACKAGE_CONFIG[shop.subscriptionPlan] ?? null
            : null;
        return {
            ...shop,
            rating: ratingStats.rating,
            reviewCount: ratingStats.reviewCount,
            isHighlighted: highlighted,
            activeDiscountPercent: hasCoopDiscount
                ? activeDiscount.discountPercent
                : 0,
            activeDiscountName: hasCoopDiscount ? activeDiscount.name : '',
            activeDiscountCode: hasCoopDiscount ? activeDiscount.code ?? '' : '',
            activeDiscountEndAt: hasCoopDiscount ? activeDiscount.endAt : null,
            packageLabel: packageMeta?.label ?? '',
            packagePrice: packageMeta?.price ?? 0,
            ...(extra ?? {}),
        };
    }
    haversineKm(lat1, lon1, lat2, lon2) {
        const toRad = (deg) => (deg * Math.PI) / 180;
        const R = 6371;
        const dLat = toRad(lat2 - lat1);
        const dLon = toRad(lon2 - lon1);
        const a = Math.sin(dLat / 2) ** 2 +
            Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
        return Number((R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))).toFixed(1));
    }
    async findNearby(params) {
        const shops = await this.shopRepo.find({ where: { isActive: true } });
        const q = params.search?.trim().toLowerCase() ?? '';
        const userLat = params.lat ?? 20.9768;
        const userLng = params.lng ?? 105.7724;
        const [ratingMap, activeDiscount] = await Promise.all([
            this.computeRatingStatsMap(shops.map((s) => s.id)),
            this.getActiveBestDiscount(),
        ]);
        return shops
            .map((s) => {
            const stats = ratingMap.get(s.id) ?? { rating: 0, reviewCount: 0 };
            return this.enrichShop(s, stats, activeDiscount, {
                distanceKm: this.haversineKm(userLat, userLng, s.latitude, s.longitude),
            });
        })
            .filter((s) => {
            if (params.onlyHighlighted && !s.isHighlighted)
                return false;
            if (params.minRating && params.minRating > 0) {
                if (s.reviewCount === 0 || s.rating < params.minRating)
                    return false;
            }
            if (!q)
                return true;
            return (s.name.toLowerCase().includes(q) ||
                s.address.toLowerCase().includes(q));
        })
            .sort((a, b) => {
            const hDiff = Number(b.isHighlighted) - Number(a.isHighlighted);
            if (hDiff !== 0)
                return hDiff;
            return a.distanceKm - b.distanceKm;
        });
    }
    async findHighlighted() {
        const shops = await this.shopRepo.find({ where: { isActive: true } });
        const highlighted = shops.filter((s) => this.isShopHighlighted(s));
        const [ratingMap, activeDiscount] = await Promise.all([
            this.computeRatingStatsMap(highlighted.map((s) => s.id)),
            this.getActiveBestDiscount(),
        ]);
        return highlighted.map((s) => this.enrichShop(s, ratingMap.get(s.id) ?? { rating: 0, reviewCount: 0 }, activeDiscount));
    }
    async findByOwner(ownerId) {
        const shop = await this.shopRepo.findOne({ where: { ownerId } });
        if (!shop)
            return null;
        return this.findDetail(shop.id);
    }
    async findDetail(shopId) {
        const shop = await this.shopRepo.findOne({
            where: { id: shopId },
            relations: ['owner'],
        });
        if (!shop)
            throw new common_1.NotFoundException('Không tìm thấy quán');
        const [services, barbers, reviews, activeDiscount] = await Promise.all([
            this.serviceRepo.find({ where: { shopId, isActive: true } }),
            this.barberRepo.find({ where: { shopId }, relations: ['user'] }),
            this.reviewRepo.find({
                where: { shopId },
                relations: ['customer'],
                order: { createdAt: 'DESC' },
            }),
            this.getActiveBestDiscount(),
        ]);
        const reviewCount = reviews.length;
        const avgRating = reviewCount === 0
            ? 0
            : Number((reviews.reduce((sum, r) => sum + r.rating, 0) / reviewCount).toFixed(1));
        const enriched = this.enrichShop(shop, { rating: avgRating, reviewCount }, activeDiscount, {
            ownerName: shop.owner?.fullName ?? '',
            ownerPhone: shop.owner?.phone ?? '',
            ownerEmail: shop.owner?.email ?? '',
        });
        const pct = enriched.activeDiscountPercent;
        return {
            ...enriched,
            services: services.map((sv) => ({
                ...sv,
                discountedPrice: pct > 0
                    ? Math.max(0, Math.round((sv.price * (100 - pct)) / 100))
                    : sv.price,
            })),
            barbers: barbers.map((b) => ({
                id: b.id,
                userId: b.userId,
                fullName: b.user.fullName,
                email: b.user.email,
                phone: b.user.phone,
                avatarUrl: b.user.avatarUrl ?? '',
                baseSalary: b.baseSalary,
                isActive: b.isActive,
                bio: b.bio,
                rating: b.rating,
            })),
            reviews: reviews.map((r) => ({
                id: r.id,
                customerId: r.customerId,
                customerName: r.customer.fullName,
                customerAvatar: r.customer.avatarUrl ?? '',
                rating: r.rating,
                comment: r.comment,
                createdAt: r.createdAt,
            })),
        };
    }
    async registerShopWithPaidPackage(ownerId, dto) {
        const user = await this.userRepo.findOne({ where: { id: ownerId } });
        if (!user)
            throw new common_1.NotFoundException('Không tìm thấy tài khoản');
        if (user.role === entities_1.UserRole.ADMIN) {
            throw new common_1.ForbiddenException('Tài khoản Admin không được đăng ký quán');
        }
        const existingOwned = await this.shopRepo.findOne({ where: { ownerId } });
        if (existingOwned) {
            throw new common_1.ConflictException('Mỗi tài khoản chỉ được đăng ký tối đa 1 quán!');
        }
        const paidTxs = await this.txRepo.find({
            where: {
                userId: ownerId,
                type: entities_1.TransactionType.REGISTER_SHOP,
                status: entities_1.TransactionStatus.SUCCESS,
            },
            order: { paidAt: 'DESC', createdAt: 'DESC' },
        });
        const validTx = dto.paymentCode
            ? paidTxs.find((t) => t.paymentCode === dto.paymentCode &&
                t.metadataJson?.consumed !== true &&
                !t.shopId)
            : paidTxs.find((t) => t.metadataJson?.consumed !== true && !t.shopId);
        if (!validTx) {
            throw new common_1.BadRequestException('Bạn cần hoàn tất thanh toán gói đăng ký quán qua SePay trước khi gửi thông tin quán!');
        }
        const cleanName = dto.name?.trim() ?? '';
        const cleanAddress = dto.address?.trim() ?? '';
        const cleanPhone = dto.phone?.trim() ?? '';
        if (!cleanName || !cleanAddress) {
            throw new common_1.BadRequestException('Vui lòng nhập đầy đủ Tên quán và Địa chỉ');
        }
        if (!auth_module_1.VN_PHONE_REGEX.test(cleanPhone)) {
            throw new common_1.BadRequestException('số điện thoại không đúng');
        }
        const allShops = await this.shopRepo.find();
        const dupName = allShops.find((s) => s.name.trim().toLowerCase() === cleanName.toLowerCase());
        if (dupName) {
            throw new common_1.ConflictException(`Tên quán "${cleanName}" đã tồn tại trên hệ thống!`);
        }
        const dupAddress = allShops.find((s) => s.address.trim().toLowerCase() === cleanAddress.toLowerCase());
        if (dupAddress) {
            throw new common_1.ConflictException(`Địa chỉ "${cleanAddress}" đã được sử dụng cho một quán khác!`);
        }
        const plan = validTx.packagePlan ??
            validTx.metadataJson?.packagePlan ??
            entities_1.ShopPackagePlan.MEMBER_MONTHLY;
        const meta = entities_1.SHOP_PACKAGE_CONFIG[plan] ?? entities_1.SHOP_PACKAGE_CONFIG[entities_1.ShopPackagePlan.MEMBER_MONTHLY];
        const shop = await this.shopRepo.save(this.shopRepo.create({
            ownerId,
            name: cleanName,
            address: cleanAddress,
            phone: cleanPhone,
            openTime: dto.openTime || '08:30',
            closeTime: dto.closeTime || '20:30',
            description: dto.description?.trim() ?? '',
            coverUrl: dto.coverUrl?.trim() || undefined,
            galleryUrls: dto.coverUrl?.trim() ? [dto.coverUrl.trim()] : [],
            latitude: Number(dto.latitude) || 20.9768,
            longitude: Number(dto.longitude) || 105.7724,
            rating: 0,
            reviewCount: 0,
            isActive: false,
            subscriptionPlan: plan,
            isCooperation: meta.isCooperation,
            subscriptionExpiresAt: null,
            highlightExpiresAt: null,
        }));
        validTx.shopId = shop.id;
        validTx.metadataJson = {
            ...(validTx.metadataJson ?? {}),
            consumed: true,
            shopId: shop.id,
        };
        await this.txRepo.save(validTx);
        const admins = await this.userRepo.find({
            where: { role: entities_1.UserRole.ADMIN },
        });
        for (const admin of admins) {
            await this.notificationsService.createAndPush({
                recipientId: admin.id,
                title: 'Yêu cầu duyệt mở quán mới',
                body: `"${shop.name}" (${meta.label}) đã thanh toán thành công và đang chờ bạn phê duyệt.`,
                type: entities_1.NotificationType.SHOP_APPROVAL,
                metadata: { shopId: shop.id, pendingApproval: true },
            });
        }
        await this.notificationsService.createAndPush({
            recipientId: ownerId,
            title: `Hồ sơ quán "${shop.name}" đã gửi Admin duyệt`,
            body: `Quán đã đăng ký ${meta.label} và đang chờ Admin hệ thống phê duyệt.`,
            type: entities_1.NotificationType.SHOP_APPROVAL,
            metadata: { shopId: shop.id, pendingApproval: true },
        });
        return this.findDetail(shop.id);
    }
    async findAdminPendingShops(adminUser) {
        if (adminUser.role !== entities_1.UserRole.ADMIN) {
            throw new common_1.ForbiddenException('Chỉ Admin mới có quyền xem danh sách duyệt quán');
        }
        const list = await this.shopRepo.find({
            where: { isActive: false },
            relations: ['owner'],
            order: { createdAt: 'DESC' },
        });
        const [ratingMap, activeDiscount, regTxs] = await Promise.all([
            this.computeRatingStatsMap(list.map((s) => s.id)),
            this.getActiveBestDiscount(),
            list.length > 0
                ? this.txRepo.find({
                    where: {
                        shopId: (0, typeorm_2.In)(list.map((s) => s.id)),
                        type: entities_1.TransactionType.REGISTER_SHOP,
                    },
                    order: { createdAt: 'DESC' },
                })
                : Promise.resolve([]),
        ]);
        return list.map((s) => {
            const tx = regTxs.find((t) => t.shopId === s.id);
            return this.enrichShop(s, ratingMap.get(s.id) ?? { rating: 0, reviewCount: 0 }, activeDiscount, {
                ownerName: s.owner?.fullName ?? '',
                ownerPhone: s.owner?.phone ?? '',
                ownerEmail: s.owner?.email ?? '',
                paymentCode: tx?.paymentCode ?? '',
                paymentAmount: tx?.amount ?? 0,
                paidAt: tx?.paidAt ?? null,
            });
        });
    }
    async findAdminActiveShops(adminUser) {
        if (adminUser.role !== entities_1.UserRole.ADMIN) {
            throw new common_1.ForbiddenException('Chỉ Admin mới có quyền quản lý danh sách quán');
        }
        const list = await this.shopRepo.find({
            where: { isActive: true },
            relations: ['owner'],
            order: { createdAt: 'DESC' },
        });
        const [ratingMap, activeDiscount] = await Promise.all([
            this.computeRatingStatsMap(list.map((s) => s.id)),
            this.getActiveBestDiscount(),
        ]);
        return list.map((s) => this.enrichShop(s, ratingMap.get(s.id) ?? { rating: 0, reviewCount: 0 }, activeDiscount, {
            ownerName: s.owner?.fullName ?? '',
            ownerPhone: s.owner?.phone ?? '',
            ownerEmail: s.owner?.email ?? '',
        }));
    }
    async approveShopByAdmin(adminUser, shopId) {
        if (adminUser.role !== entities_1.UserRole.ADMIN) {
            throw new common_1.ForbiddenException('Chỉ Admin mới có quyền duyệt quán');
        }
        const shop = await this.shopRepo.findOne({
            where: { id: shopId },
            relations: ['owner'],
        });
        if (!shop) {
            throw new common_1.NotFoundException('Không tìm thấy quán cần duyệt');
        }
        const plan = shop.subscriptionPlan ?? entities_1.ShopPackagePlan.MEMBER_MONTHLY;
        const meta = entities_1.SHOP_PACKAGE_CONFIG[plan] ?? entities_1.SHOP_PACKAGE_CONFIG[entities_1.ShopPackagePlan.MEMBER_MONTHLY];
        const now = new Date();
        const expiresAt = new Date(now.getTime() + meta.durationDays * 86400_000);
        shop.isActive = true;
        shop.subscriptionPlan = plan;
        shop.isCooperation = meta.isCooperation;
        shop.subscriptionExpiresAt = expiresAt;
        shop.highlightExpiresAt = meta.isCooperation ? expiresAt : null;
        shop.renewalNotifiedAt = null;
        await this.shopRepo.save(shop);
        const owner = await this.userRepo.findOne({ where: { id: shop.ownerId } });
        if (owner && owner.role !== entities_1.UserRole.ADMIN) {
            owner.role = entities_1.UserRole.MANAGER;
            await this.userRepo.save(owner);
            this.realtimeGateway.emitUserRoleUpdated(owner.id, {
                newRole: entities_1.UserRole.MANAGER,
                ownedShopId: shop.id,
            });
        }
        await this.notificationsService.createAndPush({
            recipientId: shop.ownerId,
            title: 'Quán của bạn đã được Admin phê duyệt!',
            body: `Chúc mừng! Quán "${shop.name}" (${meta.label}) đã được Admin duyệt hoạt động.`,
            type: entities_1.NotificationType.SHOP_APPROVAL,
            metadata: { shopId: shop.id, approved: true },
        });
        return this.findDetail(shop.id);
    }
    async deleteShopAndNotify(shop, title, body, type, metadata) {
        const ownerId = shop.ownerId;
        const shopId = shop.id;
        const shopBarbers = await this.barberRepo.find({ where: { shopId } });
        for (const b of shopBarbers) {
            await this.userRepo.update(b.userId, { role: entities_1.UserRole.USER });
            this.realtimeGateway.emitUserRoleUpdated(b.userId, {
                newRole: entities_1.UserRole.USER,
            });
        }
        await this.shopRepo.delete(shopId);
        const owner = await this.userRepo.findOne({ where: { id: ownerId } });
        if (owner && owner.role === entities_1.UserRole.MANAGER) {
            owner.role = entities_1.UserRole.USER;
            await this.userRepo.save(owner);
            this.realtimeGateway.emitUserRoleUpdated(owner.id, {
                newRole: entities_1.UserRole.USER,
            });
        }
        await this.notificationsService.createAndPush({
            recipientId: ownerId,
            title,
            body,
            type,
            metadata,
        });
    }
    async deleteShopByAdmin(adminUser, shopId) {
        if (adminUser.role !== entities_1.UserRole.ADMIN) {
            throw new common_1.ForbiddenException('Chỉ Admin mới có quyền xoá hoặc từ chối quán');
        }
        const shop = await this.shopRepo.findOne({
            where: { id: shopId },
            relations: ['owner'],
        });
        if (!shop) {
            throw new common_1.NotFoundException('Không tìm thấy quán');
        }
        const wasActive = shop.isActive;
        const shopName = shop.name;
        await this.deleteShopAndNotify(shop, wasActive
            ? `Quán "${shopName}" đã bị xoá khỏi hệ thống`
            : `Yêu cầu mở quán "${shopName}" đã bị từ chối`, wasActive
            ? `Admin hệ thống đã gỡ quán "${shopName}". Tài khoản của bạn đã chuyển về vai trò Khách hàng.`
            : `Yêu cầu đăng ký mở quán "${shopName}" chưa được Admin phê duyệt. Bạn có thể kiểm tra thông tin và đăng ký lại.`, entities_1.NotificationType.SHOP_APPROVAL, { shopId, approved: false });
        return { deleted: true, id: shopId };
    }
    async updateShop(shopId, ownerId, dto) {
        const shop = await this.shopRepo.findOne({ where: { id: shopId } });
        if (!shop)
            throw new common_1.NotFoundException('Không tìm thấy quán');
        if (shop.ownerId !== ownerId) {
            throw new common_1.ForbiddenException('Bạn không phải Quản lý của quán này');
        }
        if (dto.phone !== undefined) {
            const cleanPhone = dto.phone.trim();
            if (!auth_module_1.VN_PHONE_REGEX.test(cleanPhone)) {
                throw new common_1.BadRequestException('số điện thoại không đúng');
            }
            dto.phone = cleanPhone;
        }
        Object.assign(shop, {
            name: dto.name ?? shop.name,
            address: dto.address ?? shop.address,
            openTime: dto.openTime ?? shop.openTime,
            closeTime: dto.closeTime ?? shop.closeTime,
            phone: dto.phone ?? shop.phone,
            description: dto.description ?? shop.description,
            coverUrl: dto.coverUrl ?? shop.coverUrl,
            avatarUrl: dto.avatarUrl ?? shop.avatarUrl,
            galleryUrls: dto.galleryUrls ?? shop.galleryUrls,
        });
        return this.shopRepo.save(shop);
    }
    async createService(shopId, ownerId, dto) {
        const shop = await this.shopRepo.findOne({ where: { id: shopId } });
        if (!shop || shop.ownerId !== ownerId) {
            throw new common_1.ForbiddenException('Không có quyền quản lý dịch vụ của quán này');
        }
        return this.serviceRepo.save(this.serviceRepo.create({
            shopId,
            name: dto.name,
            price: dto.price,
            durationMinutes: dto.durationMinutes,
            description: dto.description ?? '',
        }));
    }
    async updateService(serviceId, ownerId, dto) {
        const srv = await this.serviceRepo.findOne({
            where: { id: serviceId },
            relations: ['shop'],
        });
        if (!srv || srv.shop.ownerId !== ownerId) {
            throw new common_1.ForbiddenException('Không có quyền chỉnh sửa dịch vụ');
        }
        Object.assign(srv, {
            name: dto.name !== undefined ? dto.name.trim() : srv.name,
            price: dto.price !== undefined ? dto.price : srv.price,
            durationMinutes: dto.durationMinutes !== undefined
                ? dto.durationMinutes
                : srv.durationMinutes,
            description: dto.description !== undefined ? dto.description : srv.description,
        });
        return this.serviceRepo.save(srv);
    }
    async deleteService(serviceId, ownerId) {
        const srv = await this.serviceRepo.findOne({
            where: { id: serviceId },
            relations: ['shop'],
        });
        if (!srv || srv.shop.ownerId !== ownerId) {
            throw new common_1.ForbiddenException('Không có quyền xoá dịch vụ');
        }
        await this.serviceRepo.delete(serviceId);
        return { deleted: true };
    }
    async getPayrollAndRevenue(shopId, ownerId) {
        const shop = await this.shopRepo.findOne({ where: { id: shopId } });
        if (!shop || shop.ownerId !== ownerId) {
            throw new common_1.ForbiddenException('Không có quyền xem doanh thu quán này');
        }
        const completedBookings = await this.bookingRepo.find({
            where: { shopId, status: entities_1.BookingStatus.COMPLETED },
        });
        const totalRevenue = completedBookings.reduce((sum, b) => sum + b.totalPrice, 0);
        const barbers = await this.barberRepo.find({
            where: { shopId },
            relations: ['user'],
        });
        const barberPayrolls = barbers.map((barber) => {
            const barberRevenue = completedBookings
                .filter((b) => b.barberId === barber.id)
                .reduce((sum, b) => sum + b.totalPrice, 0);
            const commission = Math.round(barberRevenue * 0.1);
            return {
                barberId: barber.id,
                fullName: barber.user.fullName,
                email: barber.user.email,
                baseSalary: barber.baseSalary,
                bookedCompletedRevenue: barberRevenue,
                commissionAmount: commission,
                totalSalary: barber.baseSalary + commission,
            };
        });
        return {
            shopId,
            totalShopRevenue: totalRevenue,
            completedBookingsCount: completedBookings.length,
            barberPayrolls,
        };
    }
};
exports.ShopsService = ShopsService;
exports.ShopsService = ShopsService = ShopsService_1 = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(entities_1.ShopEntity)),
    __param(1, (0, typeorm_1.InjectRepository)(entities_1.ServiceEntity)),
    __param(2, (0, typeorm_1.InjectRepository)(entities_1.BarberEntity)),
    __param(3, (0, typeorm_1.InjectRepository)(entities_1.ReviewEntity)),
    __param(4, (0, typeorm_1.InjectRepository)(entities_1.BookingEntity)),
    __param(5, (0, typeorm_1.InjectRepository)(entities_1.UserEntity)),
    __param(6, (0, typeorm_1.InjectRepository)(entities_1.TransactionEntity)),
    __param(7, (0, typeorm_1.InjectRepository)(entities_1.DiscountCodeEntity)),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        notifications_module_1.NotificationsService,
        realtime_module_1.RealtimeGateway])
], ShopsService);
let ShopsController = class ShopsController {
    constructor(shopsService) {
        this.shopsService = shopsService;
    }
    findNearby(search, lat, lng, minRating, onlyHighlighted) {
        return this.shopsService.findNearby({
            search,
            lat: lat ? Number(lat) : undefined,
            lng: lng ? Number(lng) : undefined,
            minRating: minRating ? Number(minRating) : undefined,
            onlyHighlighted: onlyHighlighted === 'true',
        });
    }
    findAll(search, lat, lng, minRating, onlyHighlighted) {
        return this.findNearby(search, lat, lng, minRating, onlyHighlighted);
    }
    findHighlighted() {
        return this.shopsService.findHighlighted();
    }
    registerShop(user, dto) {
        return this.shopsService.registerShopWithPaidPackage(user.id, dto);
    }
    findAdminPending(user) {
        return this.shopsService.findAdminPendingShops(user);
    }
    findAdminAll(user) {
        return this.shopsService.findAdminActiveShops(user);
    }
    approveShop(id, user) {
        return this.shopsService.approveShopByAdmin(user, id);
    }
    deleteShopByAdmin(id, user) {
        return this.shopsService.deleteShopByAdmin(user, id);
    }
    findMyShop(user) {
        return this.shopsService.findByOwner(user.id);
    }
    findDetail(id) {
        return this.shopsService.findDetail(id);
    }
    updateShop(id, user, dto) {
        return this.shopsService.updateShop(id, user.id, dto);
    }
    createService(id, user, dto) {
        return this.shopsService.createService(id, user.id, dto);
    }
    updateService(serviceId, user, dto) {
        return this.shopsService.updateService(serviceId, user.id, dto);
    }
    deleteService(serviceId, user) {
        return this.shopsService.deleteService(serviceId, user.id);
    }
    getPayroll(id, user) {
        return this.shopsService.getPayrollAndRevenue(id, user.id);
    }
};
exports.ShopsController = ShopsController;
__decorate([
    (0, common_1.Get)('nearby'),
    __param(0, (0, common_1.Query)('search')),
    __param(1, (0, common_1.Query)('lat')),
    __param(2, (0, common_1.Query)('lng')),
    __param(3, (0, common_1.Query)('minRating')),
    __param(4, (0, common_1.Query)('onlyHighlighted')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String, String, String, String]),
    __metadata("design:returntype", void 0)
], ShopsController.prototype, "findNearby", null);
__decorate([
    (0, common_1.Get)(),
    __param(0, (0, common_1.Query)('search')),
    __param(1, (0, common_1.Query)('lat')),
    __param(2, (0, common_1.Query)('lng')),
    __param(3, (0, common_1.Query)('minRating')),
    __param(4, (0, common_1.Query)('onlyHighlighted')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String, String, String, String]),
    __metadata("design:returntype", void 0)
], ShopsController.prototype, "findAll", null);
__decorate([
    (0, common_1.Get)('highlights'),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", void 0)
], ShopsController.prototype, "findHighlighted", null);
__decorate([
    (0, common_1.Post)('register'),
    (0, common_1.UseGuards)(auth_guards_1.JwtAuthGuard),
    __param(0, (0, auth_guards_1.CurrentUser)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [entities_1.UserEntity, Object]),
    __metadata("design:returntype", void 0)
], ShopsController.prototype, "registerShop", null);
__decorate([
    (0, common_1.Get)('admin/pending'),
    (0, common_1.UseGuards)(auth_guards_1.JwtAuthGuard),
    __param(0, (0, auth_guards_1.CurrentUser)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [entities_1.UserEntity]),
    __metadata("design:returntype", void 0)
], ShopsController.prototype, "findAdminPending", null);
__decorate([
    (0, common_1.Get)('admin/all'),
    (0, common_1.UseGuards)(auth_guards_1.JwtAuthGuard),
    __param(0, (0, auth_guards_1.CurrentUser)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [entities_1.UserEntity]),
    __metadata("design:returntype", void 0)
], ShopsController.prototype, "findAdminAll", null);
__decorate([
    (0, common_1.Patch)(':id/approve'),
    (0, common_1.UseGuards)(auth_guards_1.JwtAuthGuard),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, auth_guards_1.CurrentUser)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, entities_1.UserEntity]),
    __metadata("design:returntype", void 0)
], ShopsController.prototype, "approveShop", null);
__decorate([
    (0, common_1.Delete)(':id/admin'),
    (0, common_1.UseGuards)(auth_guards_1.JwtAuthGuard),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, auth_guards_1.CurrentUser)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, entities_1.UserEntity]),
    __metadata("design:returntype", void 0)
], ShopsController.prototype, "deleteShopByAdmin", null);
__decorate([
    (0, common_1.Get)('me/owned'),
    (0, common_1.UseGuards)(auth_guards_1.JwtAuthGuard),
    __param(0, (0, auth_guards_1.CurrentUser)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [entities_1.UserEntity]),
    __metadata("design:returntype", void 0)
], ShopsController.prototype, "findMyShop", null);
__decorate([
    (0, common_1.Get)(':id'),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], ShopsController.prototype, "findDetail", null);
__decorate([
    (0, common_1.Patch)(':id'),
    (0, common_1.UseGuards)(auth_guards_1.JwtAuthGuard),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, auth_guards_1.CurrentUser)()),
    __param(2, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, entities_1.UserEntity, Object]),
    __metadata("design:returntype", void 0)
], ShopsController.prototype, "updateShop", null);
__decorate([
    (0, common_1.Post)(':id/services'),
    (0, common_1.UseGuards)(auth_guards_1.JwtAuthGuard),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, auth_guards_1.CurrentUser)()),
    __param(2, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, entities_1.UserEntity, Object]),
    __metadata("design:returntype", void 0)
], ShopsController.prototype, "createService", null);
__decorate([
    (0, common_1.Patch)('services/:serviceId'),
    (0, common_1.UseGuards)(auth_guards_1.JwtAuthGuard),
    __param(0, (0, common_1.Param)('serviceId')),
    __param(1, (0, auth_guards_1.CurrentUser)()),
    __param(2, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, entities_1.UserEntity, Object]),
    __metadata("design:returntype", void 0)
], ShopsController.prototype, "updateService", null);
__decorate([
    (0, common_1.Delete)('services/:serviceId'),
    (0, common_1.UseGuards)(auth_guards_1.JwtAuthGuard),
    __param(0, (0, common_1.Param)('serviceId')),
    __param(1, (0, auth_guards_1.CurrentUser)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, entities_1.UserEntity]),
    __metadata("design:returntype", void 0)
], ShopsController.prototype, "deleteService", null);
__decorate([
    (0, common_1.Get)(':id/payroll'),
    (0, common_1.UseGuards)(auth_guards_1.JwtAuthGuard),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, auth_guards_1.CurrentUser)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, entities_1.UserEntity]),
    __metadata("design:returntype", void 0)
], ShopsController.prototype, "getPayroll", null);
exports.ShopsController = ShopsController = __decorate([
    (0, common_1.Controller)('shops'),
    __metadata("design:paramtypes", [ShopsService])
], ShopsController);
let ShopsModule = class ShopsModule {
};
exports.ShopsModule = ShopsModule;
exports.ShopsModule = ShopsModule = __decorate([
    (0, common_1.Module)({
        imports: [
            typeorm_1.TypeOrmModule.forFeature([
                entities_1.ShopEntity,
                entities_1.ServiceEntity,
                entities_1.BarberEntity,
                entities_1.ReviewEntity,
                entities_1.BookingEntity,
                entities_1.UserEntity,
                entities_1.TransactionEntity,
                entities_1.DiscountCodeEntity,
            ]),
        ],
        controllers: [ShopsController],
        providers: [ShopsService],
        exports: [ShopsService],
    })
], ShopsModule);
//# sourceMappingURL=shops.module.js.map