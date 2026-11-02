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
  BookingStatus,
  NotificationType,
  PaymentMethod,
  ServiceEntity,
  ShopEntity,
  UserEntity,
} from '../../database/entities';
import { NotificationsService } from '../notifications/notifications.module';

@Injectable()
export class BookingsService {
  private static readonly STEP_MINUTES = 15; // Bước nhảy 15 phút theo Clarification A2
  private static readonly LUNCH_START = 11 * 60 + 30; // 11:30 (690p)
  private static readonly LUNCH_END = 14 * 60; // 14:00 (840p)

  constructor(
    @InjectRepository(BookingEntity)
    private readonly bookingRepo: Repository<BookingEntity>,
    @InjectRepository(ShopEntity)
    private readonly shopRepo: Repository<ShopEntity>,
    @InjectRepository(BarberEntity)
    private readonly barberRepo: Repository<BarberEntity>,
    @InjectRepository(ServiceEntity)
    private readonly serviceRepo: Repository<ServiceEntity>,
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

  /**
   * Core Booking Slot Engine (Clarification A2):
   * - Bước nhảy mỗi 15 phút.
   * - Ca sáng: từ giờ mở cửa quán -> 11:30. Nếu start + duration > 11:30 -> Disable (Chặn tràn giờ)!
   * - Nghỉ trưa cố định: 11:30 - 14:00.
   * - Ca chiều: từ 14:00 -> giờ đóng cửa quán. Nếu start + duration > closeTime -> Disable (Chặn tràn giờ)!
   * - Đã có khách đặt (chồng lấn khoảng [start, start + duration)) -> Chuyển màu xám & Disable!
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
    const duration = Math.max(params.durationMinutes || 15, 15);

    const activeBookings = await this.bookingRepo.find({
      where: {
        barberId: params.barberId,
        bookingDate: params.date,
        status: Not(BookingStatus.CANCELLED),
      },
    });

    const buildShiftSlots = (shiftStart: number, shiftEnd: number, shiftName: string) => {
      const slots: Array<{
        startMinutes: number;
        endMinutes: number;
        label: string;
        allocatedRange: string;
        isBooked: boolean;
        isOverflow: boolean;
        isSelectable: boolean;
        disabledReason: string | null;
      }> = [];

      for (
        let start = shiftStart;
        start < shiftEnd;
        start += BookingsService.STEP_MINUTES
      ) {
        const end = start + duration;
        const directlyBooked = activeBookings.some(
          (b) => start >= b.startMinutes && start < b.endMinutes,
        );
        const overlapsExisting = activeBookings.some(
          (b) => start < b.endMinutes && end > b.startMinutes,
        );
        const isOverflow = end > shiftEnd;

        let disabledReason: string | null = null;
        if (directlyBooked) {
          disabledReason = 'Khung giờ đã có khách đặt';
        } else if (isOverflow) {
          disabledReason = `Lấn qua giới hạn ${shiftName} (${this.formatHhMm(shiftEnd)})`;
        } else if (overlapsExisting) {
          disabledReason = `Không đủ ${duration} phút trống trước ca kế tiếp`;
        }

        slots.push({
          startMinutes: start,
          endMinutes: end,
          label: this.formatHhMm(start),
          allocatedRange: `${this.formatHhMm(start)} - ${this.formatHhMm(end)}`,
          isBooked: directlyBooked || (!isOverflow && overlapsExisting),
          isOverflow,
          isSelectable: !directlyBooked && !overlapsExisting && !isOverflow,
          disabledReason,
        });
      }
      return slots;
    };

    const morningStart = Math.min(openMin, BookingsService.LUNCH_START);
    const afternoonEnd = Math.max(closeMin, BookingsService.LUNCH_END);

    return {
      date: params.date,
      durationMinutes: duration,
      stepMinutes: BookingsService.STEP_MINUTES,
      morningRange: `${this.formatHhMm(morningStart)} - 11:30`,
      afternoonRange: `14:00 - ${this.formatHhMm(afternoonEnd)}`,
      morningSlots: buildShiftSlots(
        morningStart,
        BookingsService.LUNCH_START,
        'ca sáng',
      ),
      afternoonSlots: buildShiftSlots(
        BookingsService.LUNCH_END,
        afternoonEnd,
        'ca chiều',
      ),
    };
  }

  async createBooking(
    customerId: string,
    dto: {
      shopId: string;
      barberId: string;
      serviceIds: string[];
      bookingDate: string;
      startMinutes: number;
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
    const totalPrice = services.reduce((sum, s) => sum + s.price, 0);
    const start = dto.startMinutes;
    const end = start + totalDurationMinutes;

    const openMin = this.parseHhMm(shop.openTime, 8 * 60 + 30);
    const closeMin = this.parseHhMm(shop.closeTime, 20 * 60 + 30);

    // Kiểm tra chặn tràn giờ Ca sáng & Ca chiều
    const inMorning =
      start >= openMin && end <= BookingsService.LUNCH_START;
    const inAfternoon =
      start >= BookingsService.LUNCH_END && end <= closeMin;

    if (!inMorning && !inAfternoon) {
      throw new BadRequestException(
        'Khung giờ đã chọn bị tràn qua giờ nghỉ trưa (11:30) hoặc giờ đóng cửa quán!',
      );
    }

    // Kiểm tra va chạm lịch đặt
    const existing = await this.bookingRepo.find({
      where: {
        barberId: dto.barberId,
        bookingDate: dto.bookingDate,
        status: Not(BookingStatus.CANCELLED),
      },
    });
    const hasConflict = existing.some(
      (b) => start < b.endMinutes && end > b.startMinutes,
    );
    if (hasConflict) {
      throw new ConflictException(
        'Khung giờ này vừa có khách hàng khác đặt. Vui lòng chọn khung giờ khác!',
      );
    }

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
        totalDurationMinutes,
        totalPrice,
        servicesSnapshot: services.map((s) => ({
          id: s.id,
          name: s.name,
          price: s.price,
          durationMinutes: s.durationMinutes,
        })),
        paymentMethod: dto.paymentMethod,
        isPaid: false,
        status,
      }),
    );

    await this.notificationsService.createAndPush({
      recipientId: barber.userId,
      title: `Lịch đặt mới (${this.formatHhMm(start)} - ${this.formatHhMm(end)})`,
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
      startMinutes: number;
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
    ]),
  ],
  controllers: [BookingsController],
  providers: [BookingsService],
  exports: [BookingsService],
})
export class BookingsModule {}

