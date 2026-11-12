import {
  BadRequestException,
  ConflictException,
  Controller,
  ForbiddenException,
  Get,
  Injectable,
  Module,
  NotFoundException,
  Param,
  Patch,
  Post,
  Query,
  Body,
  UseGuards,
} from '@nestjs/common';
import { InjectRepository, TypeOrmModule } from '@nestjs/typeorm';
import { In, Not, Repository } from 'typeorm';
import { CurrentUser, JwtAuthGuard } from '../../common/auth.guards';
import {
  BarberEntity,
  BookingEntity,
  BookingShift,
  BookingStatus,
  DiscountCodeEntity,
  NotificationType,
  PaymentMethod,
  ServiceEntity,
  ShopEntity,
  UserEntity,
} from '../../database/entities';
import { NotificationsService } from '../notifications/notifications.module';

@Injectable()
export class BookingsService {
  private static readonly GAP_MINUTES = 5;
  private static readonly MORNING_END = 12 * 60; // 12:00 (720p)
  private static readonly AFTERNOON_START = 13 * 60 + 30; // 13:30 (810p)

  constructor(
    @InjectRepository(BookingEntity)
    private readonly bookingRepo: Repository<BookingEntity>,
    @InjectRepository(ShopEntity)
    private readonly shopRepo: Repository<ShopEntity>,
    @InjectRepository(BarberEntity)
    private readonly barberRepo: Repository<BarberEntity>,
    @InjectRepository(ServiceEntity)
    private readonly serviceRepo: Repository<ServiceEntity>,
    @InjectRepository(DiscountCodeEntity)
    private readonly discountRepo: Repository<DiscountCodeEntity>,
    private readonly notificationsService: NotificationsService,
  ) {}

  private parseHhMm(hhMm: string, fallbackMinutes: number): number {
    const parts = hhMm?.split(':') ?? [];
    if (parts.length !== 2) return fallbackMinutes;
    const h = Number(parts[0]);
    const m = Number(parts[1]);
    if (Number.isNaN(h) || Number.isNaN(m)) return fallbackMinutes;
    return h * 60 + m;
  }

  private formatHhMm(mins: number): string {
    const h = String(Math.floor(mins / 60)).padStart(2, '0');
    const m = String(mins % 60).padStart(2, '0');
    return `${h}:${m}`;
  }

  private async getActiveCooperationDiscount(shop: ShopEntity): Promise<number> {
    if (!shop.isCooperation || !shop.isActive) return 0;
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

  private computeShiftAllocation(params: {
    shift: BookingShift;
    shiftStart: number;
    shiftEnd: number;
    durationMinutes: number;
    activeBookings: BookingEntity[];
  }) {
    const { shift, shiftStart, shiftEnd, durationMinutes, activeBookings } = params;
    const shiftBookings = activeBookings.filter((b) => {
      if (b.shift) return b.shift === shift;
      return shift === BookingShift.MORNING
        ? b.endMinutes <= BookingsService.MORNING_END
        : b.startMinutes >= BookingsService.AFTERNOON_START;
    });

    const maxEnd =
      shiftBookings.length === 0
        ? null
        : Math.max(...shiftBookings.map((b) => b.endMinutes));

    const startMinutes =
      maxEnd === null
        ? shiftStart
        : Math.max(shiftStart, maxEnd + BookingsService.GAP_MINUTES);
    const endMinutes = startMinutes + durationMinutes;
    const isAvailable =
      shiftStart < shiftEnd && durationMinutes > 0 && endMinutes <= shiftEnd;

    let disabledReason: string | null = null;
    if (!isAvailable) {
      disabledReason = `Ca này không còn đủ ${durationMinutes} phút trống trước ${this.formatHhMm(shiftEnd)}`;
    }

    return {
      shift,
      label: shift === BookingShift.MORNING ? 'Ca sáng' : 'Ca chiều',
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

  /**
   * Core Shift Auto-Scheduling Engine:
   * - Ca sáng: từ giờ mở cửa quán -> 12:00.
   * - Ca chiều: từ 13:30 -> giờ đóng cửa quán.
   * - Khách đầu tiên của ca bắt đầu ngay đầu ca; khách tiếp theo tự động xếp sau khách trước + 5 phút.
   */
  async getAvailableSlots(params: {
    shopId: string;
    barberId: string;
    date: string;
    durationMinutes: number;
  }) {
    const shop = await this.shopRepo.findOne({ where: { id: params.shopId } });
    if (!shop) throw new NotFoundException('Không tìm thấy quán');

    const openMin = this.parseHhMm(shop.openTime, 8 * 60 + 30);
    const closeMin = this.parseHhMm(shop.closeTime, 20 * 60 + 30);
    const duration = Math.max(params.durationMinutes || 15, 10);

    const activeBookings = await this.bookingRepo.find({
      where: {
        barberId: params.barberId,
        bookingDate: params.date,
        status: Not(BookingStatus.CANCELLED),
      },
    });

    const morningStart = Math.min(openMin, BookingsService.MORNING_END);
    const afternoonEnd = Math.max(closeMin, BookingsService.AFTERNOON_START);

    const morning = this.computeShiftAllocation({
      shift: BookingShift.MORNING,
      shiftStart: morningStart,
      shiftEnd: BookingsService.MORNING_END,
      durationMinutes: duration,
      activeBookings,
    });

    const afternoon = this.computeShiftAllocation({
      shift: BookingShift.AFTERNOON,
      shiftStart: BookingsService.AFTERNOON_START,
      shiftEnd: afternoonEnd,
      durationMinutes: duration,
      activeBookings,
    });

    return {
      date: params.date,
      durationMinutes: duration,
      gapMinutes: BookingsService.GAP_MINUTES,
      morningRange: morning.shiftRange,
      afternoonRange: afternoon.shiftRange,
      morning,
      afternoon,
    };
  }

  async createBooking(
    customerId: string,
    dto: {
      shopId: string;
      barberId: string;
      serviceIds: string[];
      bookingDate: string;
      shift?: BookingShift;
      startMinutes?: number;
      paymentMethod: PaymentMethod;
    },
  ) {
    if (!dto.serviceIds || dto.serviceIds.length === 0) {
      throw new BadRequestException('Vui lòng chọn ít nhất 1 dịch vụ');
    }

    const shop = await this.shopRepo.findOne({ where: { id: dto.shopId } });
    if (!shop) throw new NotFoundException('Không tìm thấy quán');

    const barber = await this.barberRepo.findOne({
      where: { id: dto.barberId, shopId: dto.shopId },
    });
    if (!barber) throw new NotFoundException('Không tìm thấy Barber tại quán này');

    const services = await this.serviceRepo.find({
      where: { id: In(dto.serviceIds), shopId: dto.shopId },
    });
    if (services.length === 0) {
      throw new BadRequestException('Danh sách dịch vụ không hợp lệ');
    }

    const totalDurationMinutes = services.reduce(
      (sum, s) => sum + s.durationMinutes,
      0,
    );
    const discountPercent = await this.getActiveCooperationDiscount(shop);
    const rawTotalPrice = services.reduce((sum, s) => sum + s.price, 0);
    const totalPrice =
      discountPercent > 0
        ? Math.max(0, Math.round((rawTotalPrice * (100 - discountPercent)) / 100))
        : rawTotalPrice;

    const targetShift =
      dto.shift ??
      (dto.startMinutes !== undefined &&
      dto.startMinutes >= BookingsService.AFTERNOON_START
        ? BookingShift.AFTERNOON
        : BookingShift.MORNING);

    const openMin = this.parseHhMm(shop.openTime, 8 * 60 + 30);
    const closeMin = this.parseHhMm(shop.closeTime, 20 * 60 + 30);
    const shiftStart =
      targetShift === BookingShift.MORNING
        ? Math.min(openMin, BookingsService.MORNING_END)
        : BookingsService.AFTERNOON_START;
    const shiftEnd =
      targetShift === BookingShift.MORNING
        ? BookingsService.MORNING_END
        : Math.max(closeMin, BookingsService.AFTERNOON_START);

    const existing = await this.bookingRepo.find({
      where: {
        barberId: dto.barberId,
        bookingDate: dto.bookingDate,
        status: Not(BookingStatus.CANCELLED),
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
      throw new ConflictException(
        allocation.disabledReason ??
          'Ca làm việc đã đầy lịch. Vui lòng chọn ca hoặc ngày khác!',
      );
    }

    const start = allocation.startMinutes;
    const end = allocation.endMinutes;

    const status =
      dto.paymentMethod === PaymentMethod.SEPAY_QR
        ? BookingStatus.PENDING
        : BookingStatus.CONFIRMED;

    const saved = await this.bookingRepo.save(
      this.bookingRepo.create({
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
          price:
            discountPercent > 0
              ? Math.max(0, Math.round((s.price * (100 - discountPercent)) / 100))
              : s.price,
          durationMinutes: s.durationMinutes,
        })),
        paymentMethod: dto.paymentMethod,
        isPaid: false,
        status,
      }),
    );

    await this.notificationsService.createAndPush({
      recipientId: barber.userId,
      title: `Lịch đặt mới (${allocation.label}: ${this.formatHhMm(start)} - ${this.formatHhMm(end)})`,
      body: `Bạn có khách đặt lịch ngày ${dto.bookingDate} tại ${shop.name}.`,
      type: NotificationType.BOOKING,
      metadata: { bookingId: saved.id },
    });

    return saved;
  }

  async getMyBookings(customerId: string) {
    return this.bookingRepo.find({
      where: { customerId },
      relations: ['shop', 'barber', 'barber.user'],
      order: { createdAt: 'DESC' },
    });
  }

  /**
   * Cho phép khách hàng Hủy lịch khi lịch chưa COMPLETED.
   */
  async cancelBooking(bookingId: string, customerId: string) {
    const bk = await this.bookingRepo.findOne({ where: { id: bookingId } });
    if (!bk) throw new NotFoundException('Không tìm thấy lịch đặt');
    if (bk.customerId !== customerId) {
      throw new ForbiddenException('Bạn không có quyền hủy lịch này');
    }
    if (bk.status === BookingStatus.COMPLETED) {
      throw new BadRequestException('Lịch đã hoàn tất không thể hủy');
    }
    bk.status = BookingStatus.CANCELLED;
    return this.bookingRepo.save(bk);
  }

  /**
   * Barber bấm nút "Xác nhận đã thanh toán":
   * Đổi trạng thái sang COMPLETED -> Quán được cộng doanh thu & Barber được cộng 10% hoa hồng.
   */
  async confirmPaidByBarber(bookingId: string, barberUserId: string) {
    const barber = await this.barberRepo.findOne({
      where: { userId: barberUserId },
    });
    if (!barber) throw new ForbiddenException('Chỉ Barber mới có quyền xác nhận');

    const bk = await this.bookingRepo.findOne({ where: { id: bookingId } });
    if (!bk || bk.barberId !== barber.id) {
      throw new NotFoundException('Không tìm thấy lịch hẹn thuộc về bạn');
    }

    bk.isPaid = true;
    bk.status = BookingStatus.COMPLETED;
    bk.completedAt = new Date();
    return this.bookingRepo.save(bk);
  }
}

@Controller('bookings')
export class BookingsController {
  constructor(private readonly service: BookingsService) {}

  @Get('slots')
  getSlots(
    @Query('shopId') shopId: string,
    @Query('barberId') barberId: string,
    @Query('date') date: string,
    @Query('durationMinutes') durationMinutes: string,
  ) {
    return this.service.getAvailableSlots({
      shopId,
      barberId,
      date,
      durationMinutes: Number(durationMinutes || 30),
    });
  }

  @Post()
  @UseGuards(JwtAuthGuard)
  create(
    @CurrentUser() user: UserEntity,
    @Body()
    dto: {
      shopId: string;
      barberId: string;
      serviceIds: string[];
      bookingDate: string;
      shift?: BookingShift;
      startMinutes?: number;
      paymentMethod: PaymentMethod;
    },
  ) {
    return this.service.createBooking(user.id, dto);
  }

  @Get('me')
  @UseGuards(JwtAuthGuard)
  getMine(@CurrentUser() user: UserEntity) {
    return this.service.getMyBookings(user.id);
  }

  @Patch(':id/cancel')
  @UseGuards(JwtAuthGuard)
  cancel(@Param('id') id: string, @CurrentUser() user: UserEntity) {
    return this.service.cancelBooking(id, user.id);
  }

  @Post(':id/confirm-paid')
  @UseGuards(JwtAuthGuard)
  confirmPaid(@Param('id') id: string, @CurrentUser() user: UserEntity) {
    return this.service.confirmPaidByBarber(id, user.id);
  }
}

@Module({
  imports: [
    TypeOrmModule.forFeature([
      BookingEntity,
      ShopEntity,
      BarberEntity,
      ServiceEntity,
      DiscountCodeEntity,
    ]),
  ],
  controllers: [BookingsController],
  providers: [BookingsService],
  exports: [BookingsService],
})
export class BookingsModule {}

