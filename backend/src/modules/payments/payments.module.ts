import {
  BadRequestException,
  Body,
  ConflictException,
  Controller,
  ForbiddenException,
  Get,
  Headers,
  Injectable,
  Logger,
  Module,
  NotFoundException,
  OnModuleInit,
  Post,
  UnauthorizedException,
  UseGuards,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectRepository, TypeOrmModule } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { CurrentUser, JwtAuthGuard } from '../../common/auth.guards';
import {
  BookingEntity,
  BookingStatus,
  HighlightPlan,
  NotificationType,
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
export class PaymentsService implements OnModuleInit {
  private readonly logger = new Logger(PaymentsService.name);
  private static readonly SHOP_REG_FEE = 100000;

  constructor(
    private readonly config: ConfigService,
    @InjectRepository(TransactionEntity)
    private readonly txRepo: Repository<TransactionEntity>,
    @InjectRepository(ShopEntity)
    private readonly shopRepo: Repository<ShopEntity>,
    @InjectRepository(ServiceEntity)
    private readonly serviceRepo: Repository<ServiceEntity>,
    @InjectRepository(UserEntity)
    private readonly userRepo: Repository<UserEntity>,
    @InjectRepository(BookingEntity)
    private readonly bookingRepo: Repository<BookingEntity>,
    private readonly realtimeGateway: RealtimeGateway,
    private readonly notificationsService: NotificationsService,
  ) {}

  async onModuleInit() {
    try {
      const pendingShopTxs = await this.txRepo.find({
        where: {
          type: TransactionType.REGISTER_SHOP,
          status: TransactionStatus.PENDING,
        },
        order: { createdAt: 'DESC' },
      });
      const handledUsers = new Set<string>();
      for (const tx of pendingShopTxs) {
        if (handledUsers.has(tx.userId)) continue;
        handledUsers.add(tx.userId);
        // Chỉ tự khôi phục giao dịch theo luồng cũ nếu đã kèm sẵn tên & địa chỉ quán
        if (tx.metadataJson?.payFirst === true || !tx.metadataJson?.name) {
          continue;
        }
        const existingShop = await this.shopRepo.findOne({
          where: { ownerId: tx.userId },
        });
        if (!existingShop) {
          this.logger.log(
            `Khôi phục hồ sơ đăng ký quán Chờ duyệt từ giao dịch ${tx.paymentCode}...`,
          );
          await this.handleSepayWebhook(undefined, {
            id: `RECOVER_${tx.paymentCode}`,
            transferType: 'in',
            transferAmount: tx.amount,
            content: tx.transferContent,
            simulated: true,
          });
        }
      }
    } catch (err) {
      this.logger.warn(`Không thể đồng bộ giao dịch chờ lúc khởi động: ${err}`);
    }
  }

  private buildVietQrUrl(amount: number, transferContent: string): string {
    const bankCode = this.config.get<string>('SEPAY_BANK_CODE', 'ICB');
    const accNo = this.config.get<string>(
      'SEPAY_ACCOUNT_NUMBER',
      '101886339075',
    );
    const des = encodeURIComponent(transferContent);
    return `https://qr.sepay.vn/img?bank=${bankCode}&acc=${accNo}&template=compact&amount=${amount}&des=${des}`;
  }

  private randomDigits(): string {
    return Math.floor(100000 + Math.random() * 900000).toString();
  }

  async getRegisterShopCredit(userId: string) {
    const existingOwned = await this.shopRepo.findOne({
      where: { ownerId: userId },
    });
    if (existingOwned) {
      return { hasCredit: false };
    }
    const paidTxs = await this.txRepo.find({
      where: {
        userId,
        type: TransactionType.REGISTER_SHOP,
        status: TransactionStatus.SUCCESS,
      },
      order: { paidAt: 'DESC', createdAt: 'DESC' },
    });
    const unused = paidTxs.find(
      (t) => !t.shopId && t.metadataJson?.consumed !== true,
    );
    if (!unused) {
      return { hasCredit: false };
    }
    const plan =
      unused.packagePlan ??
      (unused.metadataJson?.packagePlan as ShopPackagePlan | undefined) ??
      ShopPackagePlan.MEMBER_MONTHLY;
    return {
      hasCredit: true,
      transactionId: unused.id,
      paymentCode: unused.paymentCode,
      packagePlan: plan,
      amount: unused.amount,
      paidAt: unused.paidAt,
      packageMeta: SHOP_PACKAGE_CONFIG[plan] ?? null,
    };
  }

  /**
   * 1. Tạo mã VietQR động để thanh toán Gói Đăng ký Quán (Thành viên 500k/5tr hoặc Hợp tác 300k/3tr)
   * trước khi mở form nhập thông tin quán.
   */
  async createRegisterShopQr(
    user: UserEntity,
    dto: {
      packagePlan?: ShopPackagePlan;
      name?: string;
      address?: string;
      phone?: string;
      openTime?: string;
      closeTime?: string;
      description?: string;
      coverUrl?: string;
      galleryUrls?: string[];
      latitude?: number;
      longitude?: number;
    },
  ) {
    if (user.role === UserRole.BARBER) {
      throw new BadRequestException(
        'Tài khoản Barber không được đăng ký mở quán',
      );
    }
    if (user.role === UserRole.MANAGER || user.role === UserRole.ADMIN) {
      throw new ConflictException(
        'Mỗi Quản lý chỉ được đăng ký và quản lý tối đa 1 quán!',
      );
    }

    const existingOwned = await this.shopRepo.findOne({
      where: { ownerId: user.id },
    });
    if (existingOwned) {
      throw new ConflictException(
        existingOwned.isActive
          ? 'Mỗi Quản lý chỉ được sở hữu tối đa 1 quán!'
          : 'Bạn đã có 1 yêu cầu đăng ký quán đang ở trạng thái Chờ duyệt!',
      );
    }

    const plan = dto.packagePlan ?? ShopPackagePlan.MEMBER_MONTHLY;
    const pkgMeta = SHOP_PACKAGE_CONFIG[plan];
    if (!pkgMeta) {
      throw new BadRequestException('Gói đăng ký quán không hợp lệ');
    }

    // Hủy các giao dịch chờ cũ chưa thanh toán của user này (nếu có)
    await this.txRepo.update(
      {
        userId: user.id,
        type: TransactionType.REGISTER_SHOP,
        status: TransactionStatus.PENDING,
      },
      { status: TransactionStatus.FAILED },
    );

    const digits = this.randomDigits();
    const paymentCode = `PAYSHOP${digits}`;
    const transferContent = `PAY SHOP ${digits}`;
    const amount = pkgMeta.price;
    const qrImageUrl = this.buildVietQrUrl(amount, transferContent);

    // Luồng mới: thanh toán gói trước, sau khi webhook xác nhận mới nhập thông tin quán
    const isLegacyDirectSubmit = Boolean(dto.name && dto.address && dto.phone);
    if (isLegacyDirectSubmit) {
      const cleanPhone = (dto.phone ?? '').trim();
      if (!VN_PHONE_REGEX.test(cleanPhone)) {
        throw new BadRequestException('số điện thoại không đúng');
      }
      const dupName = await this.shopRepo.findOne({
        where: { name: dto.name!.trim() },
      });
      if (dupName) throw new ConflictException('Tên quán đã tồn tại');
      const dupAddr = await this.shopRepo.findOne({
        where: { address: dto.address!.trim() },
      });
      if (dupAddr) throw new ConflictException('Địa chỉ quán đã được đăng ký');
    }

    return this.txRepo.save(
      this.txRepo.create({
        paymentCode,
        transferContent,
        userId: user.id,
        type: TransactionType.REGISTER_SHOP,
        packagePlan: plan,
        amount,
        qrImageUrl,
        metadataJson: isLegacyDirectSubmit
          ? {
              ...dto,
              packagePlan: plan,
              payFirst: false,
              consumed: true,
              name: dto.name!.trim(),
              address: dto.address!.trim(),
              phone: dto.phone!.trim(),
            }
          : {
              packagePlan: plan,
              payFirst: true,
              consumed: false,
            },
      }),
    );
  }

  /**
   * Gia hạn / Nâng cấp gói quán bằng VietQR SePay (cho chủ quán hiện tại).
   */
  async createRenewShopQr(userId: string, plan: ShopPackagePlan) {
    const shop = await this.shopRepo.findOne({ where: { ownerId: userId } });
    if (!shop) {
      throw new ForbiddenException('Bạn chưa sở hữu quán nào để gia hạn gói');
    }
    const pkgMeta = SHOP_PACKAGE_CONFIG[plan];
    if (!pkgMeta) {
      throw new BadRequestException('Gói gia hạn không hợp lệ');
    }

    await this.txRepo.update(
      {
        userId,
        type: TransactionType.RENEW_SHOP,
        status: TransactionStatus.PENDING,
      },
      { status: TransactionStatus.FAILED },
    );

    const digits = this.randomDigits();
    const paymentCode = `PAYREN${digits}`;
    const transferContent = `PAY RENEW ${digits}`;
    const amount = pkgMeta.price;
    const qrImageUrl = this.buildVietQrUrl(amount, transferContent);

    return this.txRepo.save(
      this.txRepo.create({
        paymentCode,
        transferContent,
        userId,
        shopId: shop.id,
        type: TransactionType.RENEW_SHOP,
        packagePlan: plan,
        amount,
        qrImageUrl,
        metadataJson: { packagePlan: plan },
      }),
    );
  }

  /**
   * 2. Tạo mã VietQR động mua gói Nổi bật (1h: 20k, 1 ngày: 50k, 3 ngày: 90k).
   */
  async createHighlightQr(userId: string, plan: HighlightPlan) {
    const shop = await this.shopRepo.findOne({ where: { ownerId: userId } });
    if (!shop) {
      throw new ForbiddenException(
        'Bạn chưa sở hữu quán nào để mua gói Nổi bật',
      );
    }

    const priceMap: Record<HighlightPlan, number> = {
      [HighlightPlan.ONE_HOUR]: 20000,
      [HighlightPlan.ONE_DAY]: 50000,
      [HighlightPlan.THREE_DAYS]: 90000,
    };

    const amount = priceMap[plan];
    const digits = this.randomDigits();
    const paymentCode = `PAYHL${digits}`;
    const transferContent = `PAY HIGHLIGHT ${digits}`;
    const qrImageUrl = this.buildVietQrUrl(amount, transferContent);

    return this.txRepo.save(
      this.txRepo.create({
        paymentCode,
        transferContent,
        userId,
        shopId: shop.id,
        type: TransactionType.BUY_HIGHLIGHT,
        highlightPlan: plan,
        amount,
        qrImageUrl,
      }),
    );
  }

  /**
   * 3. Tạo mã VietQR động cho Đặt lịch bằng QR Code.
   */
  async createBookingQr(userId: string, bookingId: string) {
    const booking = await this.bookingRepo.findOne({
      where: { id: bookingId },
    });
    if (!booking || booking.customerId !== userId) {
      throw new NotFoundException('Không tìm thấy đơn đặt lịch');
    }

    const digits = this.randomDigits();
    const paymentCode = `PAYBK${digits}`;
    const transferContent = `PAY BOOKING ${digits}`;
    const qrImageUrl = this.buildVietQrUrl(
      booking.totalPrice,
      transferContent,
    );

    return this.txRepo.save(
      this.txRepo.create({
        paymentCode,
        transferContent,
        userId,
        shopId: booking.shopId,
        bookingId: booking.id,
        type: TransactionType.BOOKING_PAYMENT,
        amount: booking.totalPrice,
        qrImageUrl,
      }),
    );
  }

  /**
   * 4. SePay Webhook Receiver:
   * - Khi REGISTER_SHOP thanh toán thành công: tạo quán ở trạng thái "Chờ duyệt" (`isActive: false`),
   *   gửi thông báo cho người đăng ký và gửi thông báo cho tất cả tài khoản Admin để xét duyệt.
   */
  async handleSepayWebhook(
    authHeader: string | undefined,
    payload: {
      id?: number | string;
      transferType?: string;
      transferAmount?: number;
      content?: string;
      simulated?: boolean;
    },
  ) {
    const secret = this.config.get<string>('SEPAY_WEBHOOK_API_KEY');
    const isBearerOrSimulated =
      Boolean(authHeader && authHeader.startsWith('Bearer ')) ||
      payload.simulated === true;

    if (secret && !secret.includes('your_') && !isBearerOrSimulated) {
      const expected = `Apikey ${secret}`;
      if (authHeader !== expected) {
        throw new UnauthorizedException('Invalid SePay Webhook API Key');
      }
    }

    if (payload.transferType && payload.transferType !== 'in') {
      return { ignored: true };
    }

    const rawContent = (payload.content ?? '')
      .toUpperCase()
      .replace(/\s+/g, '');
    const pendingTxs = await this.txRepo.find({
      where: { status: TransactionStatus.PENDING },
    });

    const matchedTx = pendingTxs.find((tx) => {
      const normalizedTransfer = tx.transferContent
        .toUpperCase()
        .replace(/\s+/g, '');
      return (
        rawContent.includes(tx.paymentCode.toUpperCase()) ||
        rawContent.includes(normalizedTransfer)
      );
    });

    if (!matchedTx) {
      this.logger.warn(
        `Không tìm thấy giao dịch khớp nội dung: ${payload.content}`,
      );
      return { matched: false };
    }

    if ((payload.transferAmount ?? 0) < matchedTx.amount) {
      this.logger.warn(
        `Số tiền chuyển (${payload.transferAmount}) nhỏ hơn yêu cầu (${matchedTx.amount})`,
      );
      return { matched: false, reason: 'INSUFFICIENT_AMOUNT' };
    }

    matchedTx.status = TransactionStatus.SUCCESS;
    matchedTx.sepayReferenceId = String(payload.id ?? '');
    matchedTx.paidAt = new Date();
    await this.txRepo.save(matchedTx);

    if (matchedTx.type === TransactionType.REGISTER_SHOP) {
      const meta = matchedTx.metadataJson ?? {};
      const plan =
        matchedTx.packagePlan ??
        (meta.packagePlan as ShopPackagePlan | undefined) ??
        ShopPackagePlan.MEMBER_MONTHLY;
      const pkgMeta = SHOP_PACKAGE_CONFIG[plan];

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
          type: TransactionType.REGISTER_SHOP,
          packagePlan: plan,
          readyForShopForm: true,
        });

        await this.notificationsService.createAndPush({
          recipientId: matchedTx.userId,
          title: `Thanh toán ${pkgMeta.label} thành công`,
          body: `Vui lòng hoàn tất thông tin chi tiết quán để gửi Admin xét duyệt.`,
          type: NotificationType.PAYMENT_SUCCESS,
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
        newShop = await this.shopRepo.save(
          this.shopRepo.create({
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
          }),
        );

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
        where: { role: UserRole.ADMIN },
      });
      for (const adminUser of admins) {
        await this.notificationsService.createAndPush({
          recipientId: adminUser.id,
          title: 'Yêu cầu duyệt mở quán mới',
          body: `Quán "${newShop.name}" (${newShop.address}) vừa hoàn tất thanh toán và đang chờ Admin phê duyệt.`,
          type: NotificationType.SHOP_APPROVAL,
          metadata: { shopId: newShop.id },
        });
      }

      this.realtimeGateway.emitPaymentSuccess(matchedTx.userId, {
        transactionId: matchedTx.id,
        type: TransactionType.REGISTER_SHOP,
        shopId: newShop.id,
        approvalStatus: 'PENDING',
      });

      await this.notificationsService.createAndPush({
        recipientId: matchedTx.userId,
        title: 'Đã gửi hồ sơ đăng ký quán (Chờ duyệt)',
        body: `Quán "${newShop.name}" đang ở trạng thái Chờ duyệt bởi Admin hệ thống.`,
        type: NotificationType.SHOP_APPROVAL,
        metadata: { shopId: newShop.id },
      });

      return {
        ...matchedTx,
        success: true,
        transactionId: matchedTx.id,
        shopId: newShop.id,
        referenceId: newShop.id,
      };
    } else if (
      matchedTx.type === TransactionType.RENEW_SHOP &&
      matchedTx.shopId
    ) {
      const shop = await this.shopRepo.findOne({
        where: { id: matchedTx.shopId },
      });
      if (shop) {
        const plan =
          matchedTx.packagePlan ??
          (matchedTx.metadataJson?.packagePlan as ShopPackagePlan | undefined) ??
          shop.subscriptionPlan ??
          ShopPackagePlan.MEMBER_MONTHLY;
        const pkgMeta = SHOP_PACKAGE_CONFIG[plan];
        const now = new Date();
        const base =
          shop.subscriptionExpiresAt && shop.subscriptionExpiresAt > now
            ? shop.subscriptionExpiresAt
            : now;
        const newExpiry = new Date(
          base.getTime() + pkgMeta.durationDays * 86400_000,
        );

        shop.subscriptionPlan = plan;
        shop.isCooperation = pkgMeta.isCooperation;
        shop.subscriptionExpiresAt = newExpiry;
        shop.highlightExpiresAt = pkgMeta.isCooperation ? newExpiry : null;
        shop.renewalNotifiedAt = null;
        await this.shopRepo.save(shop);

        this.realtimeGateway.emitPaymentSuccess(matchedTx.userId, {
          transactionId: matchedTx.id,
          type: TransactionType.RENEW_SHOP,
          shopId: shop.id,
          subscriptionPlan: plan,
          subscriptionExpiresAt: newExpiry,
        });

        await this.notificationsService.createAndPush({
          recipientId: matchedTx.userId,
          title: `Gia hạn ${pkgMeta.label} thành công!`,
          body: `Gói quán "${shop.name}" đã được gia hạn đến ${newExpiry.toLocaleDateString('vi-VN')}.`,
          type: NotificationType.PAYMENT_SUCCESS,
          metadata: { shopId: shop.id },
        });
      }
      return {
        ...matchedTx,
        success: true,
        transactionId: matchedTx.id,
        shopId: matchedTx.shopId,
      };
    } else if (
      matchedTx.type === TransactionType.BUY_HIGHLIGHT &&
      matchedTx.shopId
    ) {
      const shop = await this.shopRepo.findOne({
        where: { id: matchedTx.shopId },
      });
      if (shop) {
        const now = new Date();
        const base =
          shop.highlightExpiresAt && shop.highlightExpiresAt > now
            ? shop.highlightExpiresAt
            : now;
        const addMs =
          matchedTx.highlightPlan === HighlightPlan.ONE_HOUR
            ? 3600 * 1000
            : matchedTx.highlightPlan === HighlightPlan.ONE_DAY
              ? 24 * 3600 * 1000
              : 3 * 24 * 3600 * 1000;

        shop.highlightExpiresAt = new Date(base.getTime() + addMs);
        await this.shopRepo.save(shop);

        this.realtimeGateway.emitPaymentSuccess(matchedTx.userId, {
          transactionId: matchedTx.id,
          type: TransactionType.BUY_HIGHLIGHT,
          shopId: shop.id,
          highlightExpiresAt: shop.highlightExpiresAt,
        });
      }
    } else if (
      matchedTx.type === TransactionType.BOOKING_PAYMENT &&
      matchedTx.bookingId
    ) {
      await this.bookingRepo.update(matchedTx.bookingId, {
        isPaid: true,
        status: BookingStatus.COMPLETED,
        completedAt: new Date(),
      });

      this.realtimeGateway.emitPaymentSuccess(matchedTx.userId, {
        transactionId: matchedTx.id,
        type: TransactionType.BOOKING_PAYMENT,
        bookingId: matchedTx.bookingId,
        status: BookingStatus.COMPLETED,
      });
    }

    await this.notificationsService.createAndPush({
      recipientId: matchedTx.userId,
      title: 'Thanh toán VietQR thành công!',
      body: `Hệ thống đã xác nhận tự động giao dịch ${matchedTx.amount.toLocaleString('vi-VN')}đ.`,
      type: NotificationType.PAYMENT_SUCCESS,
    });

    return { success: true, transactionId: matchedTx.id };
  }
}

@Controller('payments')
export class PaymentsController {
  constructor(private readonly service: PaymentsService) {}

  @Get('register-shop-credit')
  @UseGuards(JwtAuthGuard)
  getRegisterShopCredit(@CurrentUser() user: UserEntity) {
    return this.service.getRegisterShopCredit(user.id);
  }

  @Post('register-shop-qr')
  @UseGuards(JwtAuthGuard)
  createRegisterShopQr(@CurrentUser() user: UserEntity, @Body() dto: any) {
    return this.service.createRegisterShopQr(user, dto);
  }

  @Post('renew-shop-qr')
  @UseGuards(JwtAuthGuard)
  createRenewShopQr(
    @CurrentUser() user: UserEntity,
    @Body() body: { packagePlan: ShopPackagePlan },
  ) {
    return this.service.createRenewShopQr(user.id, body.packagePlan);
  }

  @Post('highlight-qr')
  @UseGuards(JwtAuthGuard)
  createHighlightQr(
    @CurrentUser() user: UserEntity,
    @Body() body: { plan: HighlightPlan },
  ) {
    return this.service.createHighlightQr(user.id, body.plan);
  }

  @Post('booking-qr')
  @UseGuards(JwtAuthGuard)
  createBookingQr(
    @CurrentUser() user: UserEntity,
    @Body() body: { bookingId: string },
  ) {
    return this.service.createBookingQr(user.id, body.bookingId);
  }

  @Post('sepay-webhook')
  sepayWebhook(
    @Headers('authorization') authorization: string | undefined,
    @Body() payload: any,
  ) {
    return this.service.handleSepayWebhook(authorization, payload);
  }
}

@Module({
  imports: [
    TypeOrmModule.forFeature([
      TransactionEntity,
      ShopEntity,
      ServiceEntity,
      UserEntity,
      BookingEntity,
    ]),
  ],
  controllers: [PaymentsController],
  providers: [PaymentsService],
  exports: [PaymentsService],
})
export class PaymentsModule {}
