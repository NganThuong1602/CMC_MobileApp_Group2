import {
  BadRequestException,
  Body,
  ConflictException,
  Controller,
  ForbiddenException,
  Headers,
  Injectable,
  Logger,
  Module,
  NotFoundException,
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
  ShopEntity,
  TransactionEntity,
  TransactionStatus,
  TransactionType,
  UserEntity,
  UserRole,
} from '../../database/entities';
import { NotificationsService } from '../notifications/notifications.module';
import { RealtimeGateway } from '../realtime/realtime.module';

@Injectable()
export class PaymentsService {
  private readonly logger = new Logger(PaymentsService.name);
  private static readonly SHOP_REG_FEE = 100000;

  constructor(
    private readonly config: ConfigService,
    @InjectRepository(TransactionEntity)
    private readonly txRepo: Repository<TransactionEntity>,
    @InjectRepository(ShopEntity)
    private readonly shopRepo: Repository<ShopEntity>,
    @InjectRepository(UserEntity)
    private readonly userRepo: Repository<UserEntity>,
    @InjectRepository(BookingEntity)
    private readonly bookingRepo: Repository<BookingEntity>,
    private readonly realtimeGateway: RealtimeGateway,
    private readonly notificationsService: NotificationsService,
  ) {}

  private buildVietQrUrl(amount: number, transferContent: string): string {
    const bankCode = this.config.get<string>('SEPAY_BANK_CODE', 'ICB');
    const accNo = this.config.get<string>('SEPAY_ACCOUNT_NUMBER', '101886339075');
    const accName = encodeURIComponent(
      this.config.get<string>('SEPAY_ACCOUNT_NAME', 'BARBERSMART PLATFORM'),
    );
    const addInfo = encodeURIComponent(transferContent);
    return `https://img.vietqr.io/image/${bankCode}-${accNo}-compact2.png?amount=${amount}&addInfo=${addInfo}&accountName=${accName}`;
  }

  private randomDigits(): string {
    return Math.floor(100000 + Math.random() * 900000).toString();
  }

  /**
   * 1. Tạo mã VietQR động 100.000đ để Đăng ký Quán (1 Manager tối đa 1 quán).
   */
  async createRegisterShopQr(
    user: UserEntity,
    dto: {
      name: string;
      address: string;
      phone: string;
      openTime: string;
      closeTime: string;
      description?: string;
      coverUrl?: string;
      galleryUrls?: string[];
      latitude?: number;
      longitude?: number;
    },
  ) {
    if (user.role === UserRole.BARBER) {
      throw new BadRequestException('Tài khoản Barber không được đăng ký mở quán');
    }

    const existingOwned = await this.shopRepo.findOne({
      where: { ownerId: user.id },
    });
    if (existingOwned) {
      throw new ConflictException('Mỗi Quản lý chỉ được sở hữu tối đa 1 quán!');
    }

    const dupName = await this.shopRepo.findOne({ where: { name: dto.name.trim() } });
    if (dupName) throw new ConflictException('Tên quán đã tồn tại');

    const dupAddr = await this.shopRepo.findOne({
      where: { address: dto.address.trim() },
    });
    if (dupAddr) throw new ConflictException('Địa chỉ quán đã được đăng ký');

    const digits = this.randomDigits();
    const paymentCode = `PAYSHOP${digits}`;
    const transferContent = `PAY SHOP ${digits}`;
    const amount = PaymentsService.SHOP_REG_FEE;
    const qrImageUrl = this.buildVietQrUrl(amount, transferContent);

    return this.txRepo.save(
      this.txRepo.create({
        paymentCode,
        transferContent,
        userId: user.id,
        type: TransactionType.REGISTER_SHOP,
        amount,
        qrImageUrl,
        metadataJson: dto,
      }),
    );
  }

  /**
   * 2. Tạo mã VietQR động mua gói Nổi bật (1h: 20k, 1 ngày: 50k, 3 ngày: 90k).
   */
  async createHighlightQr(userId: string, plan: HighlightPlan) {
    const shop = await this.shopRepo.findOne({ where: { ownerId: userId } });
    if (!shop) {
      throw new ForbiddenException('Bạn chưa sở hữu quán nào để mua gói Nổi bật');
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
   * 3. Tạo mã VietQR động cho Đặt lịch bằng QR Code (Clarification A4).
   */
  async createBookingQr(userId: string, bookingId: string) {
    const booking = await this.bookingRepo.findOne({ where: { id: bookingId } });
    if (!booking || booking.customerId !== userId) {
      throw new NotFoundException('Không tìm thấy đơn đặt lịch');
    }

    const digits = this.randomDigits();
    const paymentCode = `PAYBK${digits}`;
    const transferContent = `PAY BOOKING ${digits}`;
    const qrImageUrl = this.buildVietQrUrl(booking.totalPrice, transferContent);

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
   * Bắt biến động số dư tự động -> Đối chiếu nội dung CK -> Mở quyền / Kích hoạt gói /
   * Chuyển Booking sang COMPLETED -> Đẩy Socket.IO realtime về App ngay lập tức!
   */
  async handleSepayWebhook(
    authHeader: string | undefined,
    payload: {
      id?: number | string;
      transferType?: string;
      transferAmount?: number;
      content?: string;
    },
  ) {
    const secret = this.config.get<string>('SEPAY_WEBHOOK_API_KEY');
    if (secret && !secret.includes('your_')) {
      const expected = `Apikey ${secret}`;
      if (authHeader !== expected) {
        throw new UnauthorizedException('Invalid SePay Webhook API Key');
      }
    }

    if (payload.transferType && payload.transferType !== 'in') {
      return { ignored: true };
    }

    const rawContent = (payload.content ?? '').toUpperCase().replace(/\s+/g, '');
    // Tìm giao dịch PENDING khớp mã định danh trong nội dung chuyển khoản
    const pendingTxs = await this.txRepo.find({
      where: { status: TransactionStatus.PENDING },
    });

    const matchedTx = pendingTxs.find((tx) => {
      const normalizedTransfer = tx.transferContent.toUpperCase().replace(/\s+/g, '');
      return (
        rawContent.includes(tx.paymentCode.toUpperCase()) ||
        rawContent.includes(normalizedTransfer)
      );
    });

    if (!matchedTx) {
      this.logger.warn(`Không tìm thấy giao dịch khớp nội dung: ${payload.content}`);
      return { matched: false };
    }

    if ((payload.transferAmount ?? 0) < matchedTx.amount) {
      this.logger.warn(`Số tiền chuyển (${payload.transferAmount}) nhỏ hơn yêu cầu (${matchedTx.amount})`);
      return { matched: false, reason: 'INSUFFICIENT_AMOUNT' };
    }

    matchedTx.status = TransactionStatus.SUCCESS;
    matchedTx.sepayReferenceId = String(payload.id ?? '');
    matchedTx.paidAt = new Date();
    await this.txRepo.save(matchedTx);

    // Thực thi nghiệp vụ tự động theo loại giao dịch
    if (matchedTx.type === TransactionType.REGISTER_SHOP) {
      const meta = matchedTx.metadataJson ?? {};
      const newShop = await this.shopRepo.save(
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
          isActive: true,
        }),
      );

      await this.userRepo.update(matchedTx.userId, { role: UserRole.MANAGER });

      this.realtimeGateway.emitPaymentSuccess(matchedTx.userId, {
        transactionId: matchedTx.id,
        type: TransactionType.REGISTER_SHOP,
        shopId: newShop.id,
        newRole: UserRole.MANAGER,
      });
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
      // Theo Clarification A4: Quét QR SePay thành công -> Tự động chuyển luôn sang COMPLETED!
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

  @Post('register-shop-qr')
  @UseGuards(JwtAuthGuard)
  createRegisterShopQr(@CurrentUser() user: UserEntity, @Body() dto: any) {
    return this.service.createRegisterShopQr(user, dto);
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
      UserEntity,
      BookingEntity,
    ]),
  ],
  controllers: [PaymentsController],
  providers: [PaymentsService],
  exports: [PaymentsService],
})
export class PaymentsModule {}

