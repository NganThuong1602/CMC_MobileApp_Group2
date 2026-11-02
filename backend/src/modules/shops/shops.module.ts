import {
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
  ReviewEntity,
  ServiceEntity,
  ShopEntity,
  UserEntity,
} from '../../database/entities';

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
    return Number((R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))).toFixed(1));
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
    const shop = await this.shopRepo.findOne({ where: { id: shopId } });
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
      services,
      barbers: barbers.map((b) => ({
        id: b.id,
        userId: b.userId,
        fullName: b.user.fullName,
        email: b.user.email,
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

  async updateShop(shopId: string, ownerId: string, dto: Partial<ShopEntity>) {
    const shop = await this.shopRepo.findOne({ where: { id: shopId } });
    if (!shop) throw new NotFoundException('Không tìm thấy quán');
    if (shop.ownerId !== ownerId) {
      throw new ForbiddenException('Bạn không phải Quản lý của quán này');
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
    dto: { name: string; price: number; durationMinutes: number; description?: string },
  ) {
    const shop = await this.shopRepo.findOne({ where: { id: shopId } });
    if (!shop || shop.ownerId !== ownerId) {
      throw new ForbiddenException('Không có quyền quản lý dịch vụ của quán này');
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
    dto: { name?: string; price?: number; durationMinutes?: number; description?: string },
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
   * Chỉ tính các Booking có trạng thái COMPLETED (khách quét QR SePay thành công
   * hoặc Barber đã bấm nút "Xác nhận đã thanh toán").
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
    @Body() dto: { name: string; price: number; durationMinutes: number; description?: string },
  ) {
    return this.shopsService.createService(id, user.id, dto);
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
    ]),
  ],
  controllers: [ShopsController],
  providers: [ShopsService],
  exports: [ShopsService],
})
export class ShopsModule {}

