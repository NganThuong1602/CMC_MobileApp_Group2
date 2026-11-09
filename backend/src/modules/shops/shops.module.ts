import {
  BadRequestException,
  Body,
  Controller,
  Delete,
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
import { MoreThan, Repository } from 'typeorm';
import { CurrentUser, JwtAuthGuard } from '../../common/auth.guards';
import {
  BarberEntity,
  BookingEntity,
  BookingStatus,
  NotificationType,
  ReviewEntity,
  ServiceEntity,
  ShopEntity,
  UserEntity,
  UserRole,
} from '../../database/entities';
import { VN_PHONE_REGEX } from '../auth/auth.module';
import { NotificationsService } from '../notifications/notifications.module';
import { RealtimeGateway } from '../realtime/realtime.module';

@Injectable()
export class ShopsService {
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
    private readonly notificationsService: NotificationsService,
    private readonly realtimeGateway: RealtimeGateway,
  ) {}

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
  }) {
    const shops = await this.shopRepo.find({ where: { isActive: true } });
    const q = params.search?.trim().toLowerCase() ?? '';
    const userLat = params.lat ?? 20.9768;
    const userLng = params.lng ?? 105.7724;

    return shops
      .filter((s) => {
        if (params.minRating && s.rating < params.minRating) return false;
        if (!q) return true;
        return (
          s.name.toLowerCase().includes(q) ||
          s.address.toLowerCase().includes(q)
        );
      })
      .map((s) => ({
        ...s,
        distanceKm: this.haversineKm(userLat, userLng, s.latitude, s.longitude),
      }))
      .sort((a, b) => a.distanceKm - b.distanceKm);
  }

  async findHighlighted() {
    return this.shopRepo.find({
      where: {
        isActive: true,
        highlightExpiresAt: MoreThan(new Date()),
      },
      order: { highlightExpiresAt: 'DESC' },
    });
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

    const services = await this.serviceRepo.find({
      where: { shopId, isActive: true },
    });
    const barbers = await this.barberRepo.find({
      where: { shopId },
      relations: ['user'],
    });
    const reviews = await this.reviewRepo.find({
      where: { shopId },
      relations: ['customer'],
      order: { createdAt: 'DESC' },
    });

    return {
      ...shop,
      ownerName: shop.owner?.fullName ?? '',
      ownerPhone: shop.owner?.phone ?? '',
      ownerEmail: shop.owner?.email ?? '',
      services,
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
   * Admin: Lấy danh sách các quán đang ở trạng thái "Chờ duyệt" (`isActive: false`).
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
    return list.map((s) => ({
      ...s,
      ownerName: s.owner?.fullName ?? '',
      ownerPhone: s.owner?.phone ?? '',
      ownerEmail: s.owner?.email ?? '',
    }));
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
    return list.map((s) => ({
      ...s,
      ownerName: s.owner?.fullName ?? '',
      ownerPhone: s.owner?.phone ?? '',
      ownerEmail: s.owner?.email ?? '',
    }));
  }

  /**
   * Admin: Phê duyệt yêu cầu mở quán -> kích hoạt quán (`isActive = true`),
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

    shop.isActive = true;
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
      body: `Chúc mừng! Quán "${shop.name}" đã được Admin duyệt hoạt động. Tài khoản của bạn đã được nâng cấp thành Quản lý quán.`,
      type: NotificationType.SHOP_APPROVAL,
      metadata: { shopId: shop.id, approved: true },
    });

    return {
      ...shop,
      ownerName: shop.owner?.fullName ?? '',
      ownerPhone: shop.owner?.phone ?? '',
      ownerEmail: shop.owner?.email ?? '',
    };
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
    const ownerId = shop.ownerId;
    const shopName = shop.name;

    // Reset role của các Barber thuộc quán về USER
    const shopBarbers = await this.barberRepo.find({ where: { shopId } });
    for (const b of shopBarbers) {
      await this.userRepo.update(b.userId, { role: UserRole.USER });
      this.realtimeGateway.emitUserRoleUpdated(b.userId, {
        newRole: UserRole.USER,
      });
    }

    await this.shopRepo.delete(shop.id);

    // Reset role của chủ quán về USER (nếu không phải ADMIN)
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
      title: wasActive
        ? `Quán "${shopName}" đã bị xoá khỏi hệ thống`
        : `Yêu cầu mở quán "${shopName}" đã bị từ chối`,
      body: wasActive
        ? `Admin hệ thống đã gỡ quán "${shopName}". Tài khoản của bạn đã chuyển về vai trò Khách hàng.`
        : `Yêu cầu đăng ký mở quán "${shopName}" chưa được Admin phê duyệt. Bạn có thể kiểm tra thông tin và đăng ký lại.`,
      type: NotificationType.SHOP_APPROVAL,
      metadata: { shopId, approved: false },
    });

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
  ) {
    return this.shopsService.findNearby({
      search,
      lat: lat ? Number(lat) : undefined,
      lng: lng ? Number(lng) : undefined,
      minRating: minRating ? Number(minRating) : undefined,
    });
  }

  @Get()
  findAll(
    @Query('search') search?: string,
    @Query('lat') lat?: string,
    @Query('lng') lng?: string,
    @Query('minRating') minRating?: string,
  ) {
    return this.findNearby(search, lat, lng, minRating);
  }

  @Get('highlights')
  findHighlighted() {
    return this.shopsService.findHighlighted();
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
    ]),
  ],
  controllers: [ShopsController],
  providers: [ShopsService],
  exports: [ShopsService],
})
export class ShopsModule {}
