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
  Post,
  UseGuards,
} from '@nestjs/common';
import { InjectRepository, TypeOrmModule } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { CurrentUser, JwtAuthGuard } from '../../common/auth.guards';
import { DiscountCodeEntity, UserEntity, UserRole } from '../../database/entities';

@Injectable()
export class DiscountsService {
  constructor(
    @InjectRepository(DiscountCodeEntity)
    private readonly discountRepo: Repository<DiscountCodeEntity>,
  ) {}

  async findAll() {
    return this.discountRepo.find({
      order: { createdAt: 'DESC' },
    });
  }

  async findActiveNow(): Promise<DiscountCodeEntity[]> {
    const now = new Date();
    const list = await this.discountRepo.find({
      where: { isActive: true },
      order: { discountPercent: 'DESC', createdAt: 'DESC' },
    });
    return list.filter(
      (d) => new Date(d.startAt) <= now && now <= new Date(d.endAt),
    );
  }

  async getBestActiveDiscount(): Promise<DiscountCodeEntity | null> {
    const active = await this.findActiveNow();
    return active.length > 0 ? active[0] : null;
  }

  async createByAdmin(
    adminUser: UserEntity,
    dto: {
      name: string;
      code?: string;
      discountPercent: number;
      startAt: string;
      endAt: string;
    },
  ) {
    if (adminUser.role !== UserRole.ADMIN) {
      throw new ForbiddenException('Chỉ Admin mới có quyền thêm mã giảm giá');
    }
    const cleanName = dto.name?.trim() ?? '';
    if (!cleanName) {
      throw new BadRequestException('Vui lòng nhập tên hoặc mô tả mã giảm giá');
    }
    const pct = Math.round(Number(dto.discountPercent));
    if (Number.isNaN(pct) || pct < 1 || pct > 90) {
      throw new BadRequestException('Phần trăm giảm giá phải từ 1% đến 90%');
    }
    const start = new Date(dto.startAt);
    const end = new Date(dto.endAt);
    if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) {
      throw new BadRequestException('Thời gian bắt đầu / kết thúc không hợp lệ');
    }
    if (end <= start) {
      throw new BadRequestException(
        'Thời gian kết thúc phải sau thời gian bắt đầu',
      );
    }

    const cleanCode = dto.code?.trim().toUpperCase() || undefined;

    return this.discountRepo.save(
      this.discountRepo.create({
        name: cleanName,
        code: cleanCode,
        discountPercent: pct,
        startAt: start,
        endAt: end,
        isActive: true,
      }),
    );
  }

  async deleteByAdmin(adminUser: UserEntity, id: string) {
    if (adminUser.role !== UserRole.ADMIN) {
      throw new ForbiddenException('Chỉ Admin mới có quyền xoá mã giảm giá');
    }
    const existing = await this.discountRepo.findOne({ where: { id } });
    if (!existing) {
      throw new NotFoundException('Không tìm thấy mã giảm giá');
    }
    await this.discountRepo.delete(id);
    return { deleted: true, id };
  }
}

@Controller('discounts')
export class DiscountsController {
  constructor(private readonly service: DiscountsService) {}

  @Get()
  findAll() {
    return this.service.findAll();
  }

  @Get('active')
  findActive() {
    return this.service.findActiveNow();
  }

  @Post('admin')
  @UseGuards(JwtAuthGuard)
  create(
    @CurrentUser() user: UserEntity,
    @Body()
    dto: {
      name: string;
      code?: string;
      discountPercent: number;
      startAt: string;
      endAt: string;
    },
  ) {
    return this.service.createByAdmin(user, dto);
  }

  @Delete(':id')
  @UseGuards(JwtAuthGuard)
  remove(@CurrentUser() user: UserEntity, @Param('id') id: string) {
    return this.service.deleteByAdmin(user, id);
  }
}

@Module({
  imports: [TypeOrmModule.forFeature([DiscountCodeEntity])],
  controllers: [DiscountsController],
  providers: [DiscountsService],
  exports: [DiscountsService],
})
export class DiscountsModule {}
