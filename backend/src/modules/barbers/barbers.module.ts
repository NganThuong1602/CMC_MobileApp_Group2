import {
  BadRequestException,
  Body,
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
  UseGuards,
} from '@nestjs/common';
import { InjectRepository, TypeOrmModule } from '@nestjs/typeorm';
import { ILike, Repository } from 'typeorm';
import { CurrentUser, JwtAuthGuard } from '../../common/auth.guards';
import {
  BarberEntity,
  BookingEntity,
  BookingStatus,
  NotificationEntity,
  NotificationType,
  ShopEntity,
  UserEntity,
  UserRole,
} from '../../database/entities';
import { NotificationsService } from '../notifications/notifications.module';
import { RealtimeGateway } from '../realtime/realtime.module';

@Injectable()
export class BarbersService {
  constructor(
    @InjectRepository(BarberEntity)
    private readonly barberRepo: Repository<BarberEntity>,
    @InjectRepository(UserEntity)
    private readonly userRepo: Repository<UserEntity>,
    @InjectRepository(ShopEntity)
    private readonly shopRepo: Repository<ShopEntity>,
    @InjectRepository(BookingEntity)
    private readonly bookingRepo: Repository<BookingEntity>,
    @InjectRepository(NotificationEntity)
    private readonly notiRepo: Repository<NotificationEntity>,
    private readonly notificationsService: NotificationsService,
    private readonly realtimeGateway: RealtimeGateway,
  ) {}

  /**
   * Tìm kiếm ứng viên Barber theo Email hoặc Số điện thoại.
   */
  async searchCandidates(query: string) {
    const q = query?.trim();
    if (!q) return [];
    const users = await this.userRepo.find({
      where: [{ email: ILike(`%${q}%`) }, { phone: ILike(`%${q}%`) }],
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

  /**
   * Mời làm Barber:
   * - Manager KHÔNG được tự làm Barber.
   * - Nếu User đã thuộc quán khác (đang là Barber) hoặc là Manager -> Báo lỗi!
   */
  async inviteBarber(managerId: string, emailOrPhone: string) {
    const shop = await this.shopRepo.findOne({ where: { ownerId: managerId } });
    if (!shop) {
      throw new ForbiddenException('Bạn chưa sở hữu quán nào');
    }

    const q = emailOrPhone.trim().toLowerCase();
    const candidate = await this.userRepo.findOne({
      where: [{ email: q }, { phone: emailOrPhone.trim() }],
    });
    if (!candidate) {
      throw new NotFoundException(
        'Không tìm thấy tài khoản với Email hoặc Số điện thoại này',
      );
    }

    if (candidate.id === managerId || candidate.role === UserRole.MANAGER) {
      throw new BadRequestException(
        'Quản lý quán không được phép kiêm nhiệm làm Barber',
      );
    }

    const existingBarber = await this.barberRepo.findOne({
      where: { userId: candidate.id },
    });
    if (existingBarber) {
      throw new ConflictException(
        existingBarber.shopId === shop.id
          ? 'Thợ này đã thuộc quán của bạn'
          : 'Người dùng này hiện đã là Barber thuộc một quán khác!',
      );
    }

    await this.notificationsService.createAndPush({
      recipientId: candidate.id,
      title: `Lời mời làm Barber tại ${shop.name}`,
      body: `Quản lý quán ${shop.name} mời bạn gia nhập đội ngũ Barber.`,
      type: NotificationType.BARBER_INVITE,
      metadata: { shopId: shop.id, shopName: shop.name },
    });

    return { message: `Đã gửi lời mời làm Barber tới ${candidate.fullName}` };
  }

  async respondInvitation(userId: string, notificationId: string, accept: boolean) {
    const noti = await this.notiRepo.findOne({
      where: { id: notificationId, recipientId: userId },
    });
    if (!noti || noti.type !== NotificationType.BARBER_INVITE) {
      throw new NotFoundException('Không tìm thấy lời mời hợp lệ');
    }

    noti.isRead = true;
    noti.metadata = { ...(noti.metadata ?? {}), responded: true, accepted: accept };
    await this.notiRepo.save(noti);

    if (!accept) {
      return { accepted: false };
    }

    const user = await this.userRepo.findOneOrFail({ where: { id: userId } });
    if (user.role === UserRole.MANAGER) {
      throw new BadRequestException('Manager không được tự làm Barber');
    }

    const existing = await this.barberRepo.findOne({ where: { userId } });
    if (existing) {
      throw new ConflictException('Bạn đã thuộc một quán cắt tóc khác');
    }

    const shopId = noti.metadata?.shopId as string;
    const newBarber = await this.barberRepo.save(
      this.barberRepo.create({
        userId,
        shopId,
        baseSalary: 6000000,
        isActive: true,
      }),
    );

    user.role = UserRole.BARBER;
    await this.userRepo.save(user);

    this.realtimeGateway.emitUserRoleUpdated(userId, {
      newRole: UserRole.BARBER,
      workingShopId: shopId,
      barberId: newBarber.id,
    });

    return { accepted: true, role: UserRole.BARBER, shopId };
  }

  async updateBaseSalary(managerId: string, barberId: string, baseSalary: number) {
    const barber = await this.barberRepo.findOne({
      where: { id: barberId },
      relations: ['shop'],
    });
    if (!barber || barber.shop.ownerId !== managerId) {
      throw new ForbiddenException('Không có quyền cập nhật lương Barber này');
    }
    barber.baseSalary = baseSalary;
    return this.barberRepo.save(barber);
  }

  async getMonthlyHeatmap(userId: string, year: number, month: number) {
    const barber = await this.barberRepo.findOne({ where: { userId } });
    if (!barber) throw new NotFoundException('Chưa có hồ sơ Barber');

    const bookings = await this.bookingRepo.find({
      where: { barberId: barber.id },
    });

    const prefix = `${year}-${String(month).padStart(2, '0')}-`;
    const heatmap: Record<number, number> = {};
    for (const bk of bookings) {
      if (bk.status === BookingStatus.CANCELLED) continue;
      if (bk.bookingDate.startsWith(prefix)) {
        const day = Number(bk.bookingDate.split('-')[2]);
        heatmap[day] = (heatmap[day] ?? 0) + 1;
      }
    }
    return heatmap;
  }

  async getDayTimeline(userId: string, date: string) {
    const barber = await this.barberRepo.findOne({ where: { userId } });
    if (!barber) throw new NotFoundException('Chưa có hồ sơ Barber');

    const list = await this.bookingRepo.find({
      where: { barberId: barber.id, bookingDate: date },
      relations: ['customer'],
      order: { startMinutes: 'ASC' },
    });

    return list
      .filter((b) => b.status !== BookingStatus.CANCELLED)
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

  async getMyIncome(userId: string) {
    const barber = await this.barberRepo.findOne({
      where: { userId },
      relations: ['shop'],
    });
    if (!barber) throw new NotFoundException('Chưa có hồ sơ Barber');

    // Chỉ tính hoa hồng 10% cho các Booking đã COMPLETED
    const completed = await this.bookingRepo.find({
      where: { barberId: barber.id, status: BookingStatus.COMPLETED },
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
}

@Controller('barbers')
@UseGuards(JwtAuthGuard)
export class BarbersController {
  constructor(private readonly service: BarbersService) {}

  @Get('search-candidates')
  searchCandidates(@Query('q') q: string) {
    return this.service.searchCandidates(q);
  }

  @Post('invite')
  invite(
    @CurrentUser() user: UserEntity,
    @Body() body: { emailOrPhone: string },
  ) {
    return this.service.inviteBarber(user.id, body.emailOrPhone);
  }

  @Post('invitations/:notificationId/respond')
  respondInvite(
    @CurrentUser() user: UserEntity,
    @Param('notificationId') notificationId: string,
    @Body() body: { accept: boolean },
  ) {
    return this.service.respondInvitation(user.id, notificationId, body.accept);
  }

  @Patch(':id/salary')
  updateSalary(
    @CurrentUser() user: UserEntity,
    @Param('id') id: string,
    @Body() body: { baseSalary: number },
  ) {
    return this.service.updateBaseSalary(user.id, id, body.baseSalary);
  }

  @Get('me/profile')
  getMyProfile(@CurrentUser() user: UserEntity) {
    return this.service.getMyIncome(user.id);
  }

  @Get('me/heatmap')
  getHeatmap(
    @CurrentUser() user: UserEntity,
    @Query('year') year: string,
    @Query('month') month: string,
  ) {
    return this.service.getMonthlyHeatmap(user.id, Number(year), Number(month));
  }

  @Get('me/timeline')
  getTimeline(@CurrentUser() user: UserEntity, @Query('date') date: string) {
    return this.service.getDayTimeline(user.id, date);
  }

  @Get('me/income')
  getIncome(@CurrentUser() user: UserEntity) {
    return this.service.getMyIncome(user.id);
  }
}

@Module({
  imports: [
    TypeOrmModule.forFeature([
      BarberEntity,
      UserEntity,
      ShopEntity,
      BookingEntity,
      NotificationEntity,
    ]),
  ],
  controllers: [BarbersController],
  providers: [BarbersService],
  exports: [BarbersService],
})
export class BarbersModule {}

