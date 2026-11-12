import {
  BadRequestException,
  Body,
  ConflictException,
  Controller,
  Delete,
  ForbiddenException,
  Get,
  Injectable,
  Logger,
  Module,
  NotFoundException,
  OnModuleDestroy,
  OnModuleInit,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { InjectRepository, TypeOrmModule } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';
import { CurrentUser, JwtAuthGuard } from '../../common/auth.guards';
import {
  BarberEntity,
  BookingEntity,
  BookingStatus,
  DiscountCodeEntity,
  NotificationType,
  ReviewEntity,
  ServiceEntity,
  SHOP_PACKAGE_CONFIG,
  ShopEntity,
  ShopPackagePlan,
  TransactionEntity,
  TransactionStatus,
  TransactionType,
  UserEntity,
  UserRole,
} from '../../database/entities';
import { VN_PHONE_REGEX } from '../auth/auth.module';
import { NotificationsService } from '../notifications/notifications.module';
import { RealtimeGateway } from '../realtime/realtime.module';

@Injectable()
export class ShopsService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(ShopsService.name);
  private expiryTimer: NodeJS.Timeout | null = null;

  constructor(
    @InjectRepository(ShopEntity)
    private readonly shopRepo: Repository<ShopEntity>,
    @InjectRepository(ServiceEntity)
    private readonly serviceRepo: Repository<ServiceEntity>,
    @InjectRepository(BarberEntity)
    private readonly barberRepo: Repository<BarberEntity>,
    @InjectRepository(ReviewEntity)
    private readonly reviewRepo: Repository<ReviewEntity>,
    @InjectRepository(BookingEntity)
    private readonly bookingRepo: Repository<BookingEntity>,
    @InjectRepository(UserEntity)
    private readonly userRepo: Repository<UserEntity>,
    @InjectRepository(TransactionEntity)
    private readonly txRepo: Repository<TransactionEntity>,
    @InjectRepository(DiscountCodeEntity)
    private readonly discountRepo: Repository<DiscountCodeEntity>,
    private readonly notificationsService: NotificationsService,
    private readonly realtimeGateway: RealtimeGateway,
  ) {}

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
        if (!shop.subscriptionExpiresAt) continue;
        const remainingMs = shop.subscriptionExpiresAt.getTime() - now.getTime();
        if (remainingMs <= 0) {
          await this.deleteShopAndNotify(
            shop,
            `Quán "${shop.name}" đã tự động xoá do hết hạn gói`,
            `Gói đăng ký của quán "${shop.name}" đã hết hạn và chưa được gia hạn đúng thời gian quy định. Hệ thống đã gỡ quán và đưa tài khoản về Khách hàng.`,
            NotificationType.SYSTEM,
            { shopId: shop.id, reason: 'SUBSCRIPTION_EXPIRED' },
          );
          this.logger.warn(`Auto-deleted expired shop ${shop.name} (${shop.id})`);
        } else if (remainingMs <= sevenDaysMs && !shop.renewalNotifiedAt) {
          const daysLeft = Math.max(1, Math.ceil(remainingMs / (24 * 60 * 60 * 1000)));
          await this.shopRepo.update(shop.id, { renewalNotifiedAt: now });
          const expStr = shop.subscriptionExpiresAt.toLocaleDateString('vi-VN');
          await this.notificationsService.createAndPush({
            recipientId: shop.ownerId,
            title: `Gói quán "${shop.name}" sắp hết hạn (còn ${daysLeft} ngày)`,
            body: `Gói đăng ký quán sẽ hết hạn vào ngày ${expStr}. Vui lòng vào Quản lý quán -> Gia hạn gói trước hạn để tránh quán bị tự động xoá.`,
            type: NotificationType.SYSTEM,
            metadata: { shopId: shop.id, action: 'RENEW_SUBSCRIPTION' },
          });
        }
      }
    } catch (err) {
      this.logger.error('Lỗi kiểm tra hết hạn gói quán', err as Error);
    }
  }

  private async getActiveBestDiscount(): Promise<DiscountCodeEntity | null> {
    const now = new Date();
    const list = await this.discountRepo.find({
      where: { isActive: true },
      order: { discountPercent: 'DESC', createdAt: 'DESC' },
    });
    return (
      list.find((d) => new Date(d.startAt) <= now && now <= new Date(d.endAt)) ??
      null
    );
  }

  private async computeRatingStatsMap(
    shopIds: string[],
  ): Promise<Map<string, { rating: number; reviewCount: number }>> {
    const map = new Map<string, { sum: number; count: number }>();
    if (shopIds.length > 0) {
      const reviews = await this.reviewRepo.find({
        where: { shopId: In(shopIds) },
      });
      for (const r of reviews) {
        const cur = map.get(r.shopId) ?? { sum: 0, count: 0 };
        cur.sum += r.rating;
        cur.count += 1;
        map.set(r.shopId, cur);
      }
    }
    const result = new Map<string, { rating: number; reviewCount: number }>();
    for (const id of shopIds) {
      const entry = map.get(id);
      if (!entry || entry.count === 0) {
        result.set(id, { rating: 0, reviewCount: 0 });
      } else {
        result.set(id, {
          rating: Number((entry.sum / entry.count).toFixed(1)),
          reviewCount: entry.count,
        });
      }
    }
    return result;
  }

  private isShopHighlighted(shop: ShopEntity): boolean {
    if (shop.isCooperation) return true;
    return (
      shop.highlightExpiresAt != null &&
      new Date(shop.highlightExpiresAt) > new Date()
    );
  }

  private enrichShop<T extends Record<string, any> = Record<string, any>>(
    shop: ShopEntity,
    ratingStats: { rating: number; reviewCount: number },
    activeDiscount: DiscountCodeEntity | null,
    extra?: T,
  ) {
    const highlighted = this.isShopHighlighted(shop);
    const hasCoopDiscount =
      shop.isCooperation && shop.isActive && activeDiscount != null;
    const packageMeta = shop.subscriptionPlan
      ? SHOP_PACKAGE_CONFIG[shop.subscriptionPlan] ?? null
      : null;

    return {
      ...shop,
      rating: ratingStats.rating,
      reviewCount: ratingStats.reviewCount,
      isHighlighted: highlighted,
      activeDiscountPercent: hasCoopDiscount
        ? activeDiscount!.discountPercent
        : 0,
      activeDiscountName: hasCoopDiscount ? activeDiscount!.name : '',
      activeDiscountCode: hasCoopDiscount ? activeDiscount!.code ?? '' : '',
      activeDiscountEndAt: hasCoopDiscount ? activeDiscount!.endAt : null,
      packageLabel: packageMeta?.label ?? '',
      packagePrice: packageMeta?.price ?? 0,
      ...(extra ?? ({} as T)),
    };
  }

  private haversineKm(
    lat1: number,
    lon1: number,
    lat2: number,
    lon2: number,
  ): number {
    const toRad = (deg: number) => (deg * Math.PI) / 180;
    const R = 6371;
    const dLat = toRad(lat2 - lat1);
    const dLon = toRad(lon2 - lon1);
    const a =
      Math.sin(dLat / 2) ** 2 +
      Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
    return Number(
      (R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))).toFixed(1),
    );
  }

  async findNearby(params: {
    search?: string;
    lat?: number;
    lng?: number;
    minRating?: number;
    onlyHighlighted?: boolean;
  }) {
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
        if (params.onlyHighlighted && !s.isHighlighted) return false;
        if (params.minRating && params.minRating > 0) {
          if (s.reviewCount === 0 || s.rating < params.minRating) return false;
        }
        if (!q) return true;
        return (
          s.name.toLowerCase().includes(q) ||
          s.address.toLowerCase().includes(q)
        );
      })
      .sort((a, b) => {
        const hDiff = Number(b.isHighlighted) - Number(a.isHighlighted);
        if (hDiff !== 0) return hDiff;
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
    return highlighted.map((s) =>
      this.enrichShop(
        s,
        ratingMap.get(s.id) ?? { rating: 0, reviewCount: 0 },
        activeDiscount,
      ),
    );
  }

  async findByOwner(ownerId: string) {
    const shop = await this.shopRepo.findOne({ where: { ownerId } });
    if (!shop) return null;
    return this.findDetail(shop.id);
  }

  async findDetail(shopId: string) {
    const shop = await this.shopRepo.findOne({
      where: { id: shopId },
      relations: ['owner'],
    });
    if (!shop) throw new NotFoundException('Không tìm thấy quán');

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
    const avgRating =
      reviewCount === 0
        ? 0
        : Number(
            (reviews.reduce((sum, r) => sum + r.rating, 0) / reviewCount).toFixed(
              1,
            ),
          );

    const enriched = this.enrichShop(
      shop,
      { rating: avgRating, reviewCount },
      activeDiscount,
      {
        ownerName: shop.owner?.fullName ?? '',
        ownerPhone: shop.owner?.phone ?? '',
        ownerEmail: shop.owner?.email ?? '',
      },
    );

    const pct = enriched.activeDiscountPercent;

    return {
      ...enriched,
      services: services.map((sv) => ({
        ...sv,
        discountedPrice:
          pct > 0
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

  /**
   * Bước 2 Đăng ký quán (chỉ thực hiện sau khi thanh toán gói qua SePay thành công):
   * Kiểm tra giao dịch `REGISTER_SHOP` ở trạng thái `SUCCESS`, tạo quán (`isActive: false`),
   * gắn gói đã mua và gửi thông báo duyệt mở quán tới toàn bộ Admin.
   */
  async registerShopWithPaidPackage(
    ownerId: string,
    dto: {
      paymentCode?: string;
      name: string;
      address: string;
      phone: string;
      openTime: string;
      closeTime: string;
      description?: string;
      coverUrl?: string;
      latitude?: number;
      longitude?: number;
    },
  ) {
    const user = await this.userRepo.findOne({ where: { id: ownerId } });
    if (!user) throw new NotFoundException('Không tìm thấy tài khoản');
    if (user.role === UserRole.ADMIN) {
      throw new ForbiddenException('Tài khoản Admin không được đăng ký quán');
    }

    const existingOwned = await this.shopRepo.findOne({ where: { ownerId } });
    if (existingOwned) {
      throw new ConflictException(
        'Mỗi tài khoản chỉ được đăng ký tối đa 1 quán!',
      );
    }

    const paidTxs = await this.txRepo.find({
      where: {
        userId: ownerId,
        type: TransactionType.REGISTER_SHOP,
        status: TransactionStatus.SUCCESS,
      },
      order: { paidAt: 'DESC', createdAt: 'DESC' },
    });

    const validTx = dto.paymentCode
      ? paidTxs.find(
          (t) =>
            t.paymentCode === dto.paymentCode &&
            t.metadataJson?.consumed !== true &&
            !t.shopId,
        )
      : paidTxs.find((t) => t.metadataJson?.consumed !== true && !t.shopId);

    if (!validTx) {
      throw new BadRequestException(
        'Bạn cần hoàn tất thanh toán gói đăng ký quán qua SePay trước khi gửi thông tin quán!',
      );
    }

    const cleanName = dto.name?.trim() ?? '';
    const cleanAddress = dto.address?.trim() ?? '';
    const cleanPhone = dto.phone?.trim() ?? '';
    if (!cleanName || !cleanAddress) {
      throw new BadRequestException('Vui lòng nhập đầy đủ Tên quán và Địa chỉ');
    }
    if (!VN_PHONE_REGEX.test(cleanPhone)) {
      throw new BadRequestException('số điện thoại không đúng');
    }

    const allShops = await this.shopRepo.find();
    const dupName = allShops.find(
      (s) => s.name.trim().toLowerCase() === cleanName.toLowerCase(),
    );
    if (dupName) {
      throw new ConflictException(
        `Tên quán "${cleanName}" đã tồn tại trên hệ thống!`,
      );
    }
    const dupAddress = allShops.find(
      (s) => s.address.trim().toLowerCase() === cleanAddress.toLowerCase(),
    );
    if (dupAddress) {
      throw new ConflictException(
        `Địa chỉ "${cleanAddress}" đã được sử dụng cho một quán khác!`,
      );
    }

    const plan =
      validTx.packagePlan ??
      (validTx.metadataJson?.packagePlan as ShopPackagePlan | undefined) ??
      ShopPackagePlan.MEMBER_MONTHLY;
    const meta = SHOP_PACKAGE_CONFIG[plan] ?? SHOP_PACKAGE_CONFIG[ShopPackagePlan.MEMBER_MONTHLY];

    const shop = await this.shopRepo.save(
      this.shopRepo.create({
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
      }),
    );

    validTx.shopId = shop.id;
    validTx.metadataJson = {
      ...(validTx.metadataJson ?? {}),
      consumed: true,
      shopId: shop.id,
    };
    await this.txRepo.save(validTx);

    const admins = await this.userRepo.find({
      where: { role: UserRole.ADMIN },
    });
    for (const admin of admins) {
      await this.notificationsService.createAndPush({
        recipientId: admin.id,
        title: 'Yêu cầu duyệt mở quán mới',
        body: `"${shop.name}" (${meta.label}) đã thanh toán thành công và đang chờ bạn phê duyệt.`,
        type: NotificationType.SHOP_APPROVAL,
        metadata: { shopId: shop.id, pendingApproval: true },
      });
    }

    await this.notificationsService.createAndPush({
      recipientId: ownerId,
      title: `Hồ sơ quán "${shop.name}" đã gửi Admin duyệt`,
      body: `Quán đã đăng ký ${meta.label} và đang chờ Admin hệ thống phê duyệt.`,
      type: NotificationType.SHOP_APPROVAL,
      metadata: { shopId: shop.id, pendingApproval: true },
    });

    return this.findDetail(shop.id);
  }

  /**
   * Admin: Lấy danh sách các quán đang ở trạng thái "Chờ duyệt" (`isActive: false`).
   * Trả về đầy đủ thông tin quán, chủ quán, gói đã thanh toán & mã giao dịch để Admin kiểm tra.
   */
  async findAdminPendingShops(adminUser: UserEntity) {
    if (adminUser.role !== UserRole.ADMIN) {
      throw new ForbiddenException('Chỉ Admin mới có quyền xem danh sách duyệt quán');
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
              shopId: In(list.map((s) => s.id)),
              type: TransactionType.REGISTER_SHOP,
            },
            order: { createdAt: 'DESC' },
          })
        : Promise.resolve([]),
    ]);

    return list.map((s) => {
      const tx = regTxs.find((t) => t.shopId === s.id);
      return this.enrichShop(
        s,
        ratingMap.get(s.id) ?? { rating: 0, reviewCount: 0 },
        activeDiscount,
        {
          ownerName: s.owner?.fullName ?? '',
          ownerPhone: s.owner?.phone ?? '',
          ownerEmail: s.owner?.email ?? '',
          paymentCode: tx?.paymentCode ?? '',
          paymentAmount: tx?.amount ?? 0,
          paidAt: tx?.paidAt ?? null,
        },
      );
    });
  }

  /**
   * Admin: Lấy danh sách tất cả các quán đang hoạt động (`isActive: true`).
   */
  async findAdminActiveShops(adminUser: UserEntity) {
    if (adminUser.role !== UserRole.ADMIN) {
      throw new ForbiddenException('Chỉ Admin mới có quyền quản lý danh sách quán');
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
    return list.map((s) =>
      this.enrichShop(
        s,
        ratingMap.get(s.id) ?? { rating: 0, reviewCount: 0 },
        activeDiscount,
        {
          ownerName: s.owner?.fullName ?? '',
          ownerPhone: s.owner?.phone ?? '',
          ownerEmail: s.owner?.email ?? '',
        },
      ),
    );
  }

  /**
   * Admin: Phê duyệt yêu cầu mở quán -> kích hoạt quán (`isActive = true`),
   * kích hoạt thời hạn gói (30 hoặc 365 ngày) & Nổi bật nếu là gói Hợp tác,
   * nâng cấp chủ quán lên `MANAGER`, và gửi thông báo thật.
   */
  async approveShopByAdmin(adminUser: UserEntity, shopId: string) {
    if (adminUser.role !== UserRole.ADMIN) {
      throw new ForbiddenException('Chỉ Admin mới có quyền duyệt quán');
    }
    const shop = await this.shopRepo.findOne({
      where: { id: shopId },
      relations: ['owner'],
    });
    if (!shop) {
      throw new NotFoundException('Không tìm thấy quán cần duyệt');
    }

    const plan = shop.subscriptionPlan ?? ShopPackagePlan.MEMBER_MONTHLY;
    const meta = SHOP_PACKAGE_CONFIG[plan] ?? SHOP_PACKAGE_CONFIG[ShopPackagePlan.MEMBER_MONTHLY];
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
    if (owner && owner.role !== UserRole.ADMIN) {
      owner.role = UserRole.MANAGER;
      await this.userRepo.save(owner);
      this.realtimeGateway.emitUserRoleUpdated(owner.id, {
        newRole: UserRole.MANAGER,
        ownedShopId: shop.id,
      });
    }

    await this.notificationsService.createAndPush({
      recipientId: shop.ownerId,
      title: 'Quán của bạn đã được Admin phê duyệt!',
      body: `Chúc mừng! Quán "${shop.name}" (${meta.label}) đã được Admin duyệt hoạt động.`,
      type: NotificationType.SHOP_APPROVAL,
      metadata: { shopId: shop.id, approved: true },
    });

    return this.findDetail(shop.id);
  }

  private async deleteShopAndNotify(
    shop: ShopEntity,
    title: string,
    body: string,
    type: NotificationType,
    metadata?: Record<string, any>,
  ) {
    const ownerId = shop.ownerId;
    const shopId = shop.id;

    const shopBarbers = await this.barberRepo.find({ where: { shopId } });
    for (const b of shopBarbers) {
      await this.userRepo.update(b.userId, { role: UserRole.USER });
      this.realtimeGateway.emitUserRoleUpdated(b.userId, {
        newRole: UserRole.USER,
      });
    }

    await this.shopRepo.delete(shopId);

    const owner = await this.userRepo.findOne({ where: { id: ownerId } });
    if (owner && owner.role === UserRole.MANAGER) {
      owner.role = UserRole.USER;
      await this.userRepo.save(owner);
      this.realtimeGateway.emitUserRoleUpdated(owner.id, {
        newRole: UserRole.USER,
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

  /**
   * Admin: Từ chối yêu cầu mở quán hoặc Xoá một quán đang hoạt động khỏi hệ thống.
   */
  async deleteShopByAdmin(adminUser: UserEntity, shopId: string) {
    if (adminUser.role !== UserRole.ADMIN) {
      throw new ForbiddenException('Chỉ Admin mới có quyền xoá hoặc từ chối quán');
    }
    const shop = await this.shopRepo.findOne({
      where: { id: shopId },
      relations: ['owner'],
    });
    if (!shop) {
      throw new NotFoundException('Không tìm thấy quán');
    }

    const wasActive = shop.isActive;
    const shopName = shop.name;

    await this.deleteShopAndNotify(
      shop,
      wasActive
        ? `Quán "${shopName}" đã bị xoá khỏi hệ thống`
        : `Yêu cầu mở quán "${shopName}" đã bị từ chối`,
      wasActive
        ? `Admin hệ thống đã gỡ quán "${shopName}". Tài khoản của bạn đã chuyển về vai trò Khách hàng.`
        : `Yêu cầu đăng ký mở quán "${shopName}" chưa được Admin phê duyệt. Bạn có thể kiểm tra thông tin và đăng ký lại.`,
      NotificationType.SHOP_APPROVAL,
      { shopId, approved: false },
    );

    return { deleted: true, id: shopId };
  }

  async updateShop(shopId: string, ownerId: string, dto: Partial<ShopEntity>) {
    const shop = await this.shopRepo.findOne({ where: { id: shopId } });
    if (!shop) throw new NotFoundException('Không tìm thấy quán');
    if (shop.ownerId !== ownerId) {
      throw new ForbiddenException('Bạn không phải Quản lý của quán này');
    }

    if (dto.phone !== undefined) {
      const cleanPhone = dto.phone.trim();
      if (!VN_PHONE_REGEX.test(cleanPhone)) {
        throw new BadRequestException('số điện thoại không đúng');
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

  async createService(
    shopId: string,
    ownerId: string,
    dto: {
      name: string;
      price: number;
      durationMinutes: number;
      description?: string;
    },
  ) {
    const shop = await this.shopRepo.findOne({ where: { id: shopId } });
    if (!shop || shop.ownerId !== ownerId) {
      throw new ForbiddenException(
        'Không có quyền quản lý dịch vụ của quán này',
      );
    }
    return this.serviceRepo.save(
      this.serviceRepo.create({
        shopId,
        name: dto.name,
        price: dto.price,
        durationMinutes: dto.durationMinutes,
        description: dto.description ?? '',
      }),
    );
  }

  async updateService(
    serviceId: string,
    ownerId: string,
    dto: {
      name?: string;
      price?: number;
      durationMinutes?: number;
      description?: string;
    },
  ) {
    const srv = await this.serviceRepo.findOne({
      where: { id: serviceId },
      relations: ['shop'],
    });
    if (!srv || srv.shop.ownerId !== ownerId) {
      throw new ForbiddenException('Không có quyền chỉnh sửa dịch vụ');
    }
    Object.assign(srv, {
      name: dto.name !== undefined ? dto.name.trim() : srv.name,
      price: dto.price !== undefined ? dto.price : srv.price,
      durationMinutes:
        dto.durationMinutes !== undefined
          ? dto.durationMinutes
          : srv.durationMinutes,
      description:
        dto.description !== undefined ? dto.description : srv.description,
    });
    return this.serviceRepo.save(srv);
  }

  async deleteService(serviceId: string, ownerId: string) {
    const srv = await this.serviceRepo.findOne({
      where: { id: serviceId },
      relations: ['shop'],
    });
    if (!srv || srv.shop.ownerId !== ownerId) {
      throw new ForbiddenException('Không có quyền xoá dịch vụ');
    }
    await this.serviceRepo.delete(serviceId);
    return { deleted: true };
  }

  /**
   * Thống kê Doanh thu quán & Bảng lương Barber:
   * Chỉ tính các Booking có trạng thái COMPLETED.
   */
  async getPayrollAndRevenue(shopId: string, ownerId: string) {
    const shop = await this.shopRepo.findOne({ where: { id: shopId } });
    if (!shop || shop.ownerId !== ownerId) {
      throw new ForbiddenException('Không có quyền xem doanh thu quán này');
    }

    const completedBookings = await this.bookingRepo.find({
      where: { shopId, status: BookingStatus.COMPLETED },
    });

    const totalRevenue = completedBookings.reduce(
      (sum, b) => sum + b.totalPrice,
      0,
    );

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
}

@Controller('shops')
export class ShopsController {
  constructor(private readonly shopsService: ShopsService) {}

  @Get('nearby')
  findNearby(
    @Query('search') search?: string,
    @Query('lat') lat?: string,
    @Query('lng') lng?: string,
    @Query('minRating') minRating?: string,
    @Query('onlyHighlighted') onlyHighlighted?: string,
  ) {
    return this.shopsService.findNearby({
      search,
      lat: lat ? Number(lat) : undefined,
      lng: lng ? Number(lng) : undefined,
      minRating: minRating ? Number(minRating) : undefined,
      onlyHighlighted: onlyHighlighted === 'true',
    });
  }

  @Get()
  findAll(
    @Query('search') search?: string,
    @Query('lat') lat?: string,
    @Query('lng') lng?: string,
    @Query('minRating') minRating?: string,
    @Query('onlyHighlighted') onlyHighlighted?: string,
  ) {
    return this.findNearby(search, lat, lng, minRating, onlyHighlighted);
  }

  @Get('highlights')
  findHighlighted() {
    return this.shopsService.findHighlighted();
  }

  @Post('register')
  @UseGuards(JwtAuthGuard)
  registerShop(
    @CurrentUser() user: UserEntity,
    @Body()
    dto: {
      paymentCode?: string;
      name: string;
      address: string;
      phone: string;
      openTime: string;
      closeTime: string;
      description?: string;
      coverUrl?: string;
      latitude?: number;
      longitude?: number;
    },
  ) {
    return this.shopsService.registerShopWithPaidPackage(user.id, dto);
  }

  @Get('admin/pending')
  @UseGuards(JwtAuthGuard)
  findAdminPending(@CurrentUser() user: UserEntity) {
    return this.shopsService.findAdminPendingShops(user);
  }

  @Get('admin/all')
  @UseGuards(JwtAuthGuard)
  findAdminAll(@CurrentUser() user: UserEntity) {
    return this.shopsService.findAdminActiveShops(user);
  }

  @Patch(':id/approve')
  @UseGuards(JwtAuthGuard)
  approveShop(@Param('id') id: string, @CurrentUser() user: UserEntity) {
    return this.shopsService.approveShopByAdmin(user, id);
  }

  @Delete(':id/admin')
  @UseGuards(JwtAuthGuard)
  deleteShopByAdmin(@Param('id') id: string, @CurrentUser() user: UserEntity) {
    return this.shopsService.deleteShopByAdmin(user, id);
  }

  @Get('me/owned')
  @UseGuards(JwtAuthGuard)
  findMyShop(@CurrentUser() user: UserEntity) {
    return this.shopsService.findByOwner(user.id);
  }

  @Get(':id')
  findDetail(@Param('id') id: string) {
    return this.shopsService.findDetail(id);
  }

  @Patch(':id')
  @UseGuards(JwtAuthGuard)
  updateShop(
    @Param('id') id: string,
    @CurrentUser() user: UserEntity,
    @Body() dto: Partial<ShopEntity>,
  ) {
    return this.shopsService.updateShop(id, user.id, dto);
  }

  @Post(':id/services')
  @UseGuards(JwtAuthGuard)
  createService(
    @Param('id') id: string,
    @CurrentUser() user: UserEntity,
    @Body()
    dto: {
      name: string;
      price: number;
      durationMinutes: number;
      description?: string;
    },
  ) {
    return this.shopsService.createService(id, user.id, dto);
  }

  @Patch('services/:serviceId')
  @UseGuards(JwtAuthGuard)
  updateService(
    @Param('serviceId') serviceId: string,
    @CurrentUser() user: UserEntity,
    @Body()
    dto: {
      name?: string;
      price?: number;
      durationMinutes?: number;
      description?: string;
    },
  ) {
    return this.shopsService.updateService(serviceId, user.id, dto);
  }

  @Delete('services/:serviceId')
  @UseGuards(JwtAuthGuard)
  deleteService(
    @Param('serviceId') serviceId: string,
    @CurrentUser() user: UserEntity,
  ) {
    return this.shopsService.deleteService(serviceId, user.id);
  }

  @Get(':id/payroll')
  @UseGuards(JwtAuthGuard)
  getPayroll(@Param('id') id: string, @CurrentUser() user: UserEntity) {
    return this.shopsService.getPayrollAndRevenue(id, user.id);
  }
}

@Module({
  imports: [
    TypeOrmModule.forFeature([
      ShopEntity,
      ServiceEntity,
      BarberEntity,
      ReviewEntity,
      BookingEntity,
      UserEntity,
      TransactionEntity,
      DiscountCodeEntity,
    ]),
  ],
  controllers: [ShopsController],
  providers: [ShopsService],
  exports: [ShopsService],
})
export class ShopsModule {}
