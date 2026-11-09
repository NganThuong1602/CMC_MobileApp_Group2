import { Injectable, Logger, Module, OnModuleInit } from '@nestjs/common';
import { InjectRepository, TypeOrmModule } from '@nestjs/typeorm';
import { IsNull, Repository } from 'typeorm';
import { hashPassword } from '../modules/auth/auth.module';
import {
  BarberEntity,
  DEFAULT_AVATAR_URL,
  Gender,
  HighlightPlan,
  PostCommentEntity,
  PostEntity,
  ReviewEntity,
  ServiceEntity,
  ShopEntity,
  TransactionEntity,
  TransactionStatus,
  TransactionType,
  UserEntity,
  UserRole,
} from './entities';

interface SeedBarberSpec {
  email: string;
  phone: string;
  fullName: string;
  avatarUrl: string;
  coverUrl: string;
  bio: string;
  baseSalary: number;
  rating: number;
}

interface SeedShopSpec {
  managerEmail: string;
  managerPhone: string;
  managerName: string;
  managerAvatar: string;
  managerCover: string;
  shopName: string;
  address: string;
  phone: string;
  openTime: string;
  closeTime: string;
  latitude: number;
  longitude: number;
  rating: number;
  reviewCount: number;
  avatarUrl: string;
  coverUrl: string;
  galleryUrls: string[];
  description: string;
  isHighlighted100Days: boolean;
  highlightPaymentCode?: string;
  barbers: SeedBarberSpec[];
}

const VAN_PHUC_SHOPS_SEED: SeedShopSpec[] = [
  {
    managerEmail: 'manager@barbersmart.vn',
    managerPhone: '0901888234',
    managerName: 'Trần Minh Quân',
    managerAvatar:
      'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&q=80',
    managerCover:
      'https://images.unsplash.com/photo-1585747860715-2ba37e788b70?w=1000&q=80',
    shopName: 'Vạn Phúc Barber House',
    address: 'Số 48 Phố Lụa, Phường Vạn Phúc, Quận Hà Đông, Hà Nội',
    phone: '0901888234',
    openTime: '08:00',
    closeTime: '21:30',
    latitude: 20.9768,
    longitude: 105.7724,
    rating: 4.9,
    reviewCount: 146,
    avatarUrl:
      'https://images.unsplash.com/photo-1621605815971-fbc98d665033?w=400&q=80',
    coverUrl:
      'https://images.unsplash.com/photo-1585747860715-2ba37e788b70?w=1000&q=80',
    galleryUrls: [
      'https://images.unsplash.com/photo-1585747860715-2ba37e788b70?w=900&q=80',
      'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?w=900&q=80',
      'https://images.unsplash.com/photo-1622286342621-4bd786c2447c?w=900&q=80',
      'https://images.unsplash.com/photo-1599351431202-1e0f0137899a?w=900&q=80',
    ],
    description:
      'Tiệm cắt tóc nam chuẩn quý ông ngay trung tâm Làng Lụa Vạn Phúc, Hà Đông. Chuyên Skin Fade, Side Part Hàn Quốc và cạo mặt khăn nóng thư giãn.',
    isHighlighted100Days: true,
    highlightPaymentCode: 'PAYHLSEED001',
    barbers: [
      {
        email: 'barber@barbersmart.vn',
        phone: '0911200101',
        fullName: 'Lê Hoàng Nam',
        avatarUrl:
          'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400&q=80',
        coverUrl:
          'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?w=900&q=80',
        bio: 'Master Barber 6 năm kinh nghiệm chuyên Skin Fade & Pompadour cổ điển.',
        baseSalary: 8000000,
        rating: 4.9,
      },
      {
        email: 'barber1_2@barbersmart.vn',
        phone: '0911200102',
        fullName: 'Nguyễn Đức Thịnh',
        avatarUrl:
          'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=400&q=80',
        coverUrl:
          'https://images.unsplash.com/photo-1621605815971-fbc98d665033?w=900&q=80',
        bio: 'Chuyên gia tạo kiểu Layer Hàn Quốc & uốn phồng tự nhiên.',
        baseSalary: 7200000,
        rating: 4.9,
      },
      {
        email: 'barber1_3@barbersmart.vn',
        phone: '0911200103',
        fullName: 'Phan Anh Dũng',
        avatarUrl:
          'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=400&q=80',
        coverUrl:
          'https://images.unsplash.com/photo-1599351431202-1e0f0137899a?w=900&q=80',
        bio: 'Tỉ mỉ từng đường tông đơ, chuyên Mullet & Mohican hiện đại.',
        baseSalary: 6800000,
        rating: 4.8,
      },
      {
        email: 'barber1_4@barbersmart.vn',
        phone: '0911200104',
        fullName: 'Bùi Quang Huy',
        avatarUrl:
          'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=400&q=80',
        coverUrl:
          'https://images.unsplash.com/photo-1622286342621-4bd786c2447c?w=900&q=80',
        bio: 'Kỹ thuật nhuộm khói & tẩy tóc an toàn không xót da đầu.',
        baseSalary: 7000000,
        rating: 4.8,
      },
    ],
  },
  {
    managerEmail: 'manager2@barbersmart.vn',
    managerPhone: '0902888111',
    managerName: 'Lê Hoàng Phúc',
    managerAvatar:
      'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=400&q=80',
    managerCover:
      'https://images.unsplash.com/photo-1521590832167-7bcbfaa6381f?w=1000&q=80',
    shopName: 'The Gentlemen Hair Salon Hà Đông',
    address: 'Số 126 Tố Hữu, Phường Vạn Phúc, Quận Hà Đông, Hà Nội',
    phone: '0902888111',
    openTime: '08:30',
    closeTime: '21:00',
    latitude: 20.9785,
    longitude: 105.7746,
    rating: 4.9,
    reviewCount: 112,
    avatarUrl:
      'https://images.unsplash.com/photo-1521590832167-7bcbfaa6381f?w=400&q=80',
    coverUrl:
      'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?w=1000&q=80',
    galleryUrls: [
      'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?w=900&q=80',
      'https://images.unsplash.com/photo-1521590832167-7bcbfaa6381f?w=900&q=80',
      'https://images.unsplash.com/photo-1621605815971-fbc98d665033?w=900&q=80',
    ],
    description:
      'Không gian sang trọng mặt đường Tố Hữu - Vạn Phúc. Chuyên thiết kế form tóc doanh nhân, gội đầu dưỡng sinh & chăm sóc da mặt chuyên sâu.',
    isHighlighted100Days: true,
    highlightPaymentCode: 'PAYHLSEED002',
    barbers: [
      {
        email: 'barber2_1@barbersmart.vn',
        phone: '0911200201',
        fullName: 'Đặng Tuấn Kiệt',
        avatarUrl:
          'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400&q=80',
        coverUrl:
          'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?w=900&q=80',
        bio: 'Senior Stylist 5 năm kinh nghiệm tạo kiểu chuẩn quý ông châu Âu.',
        baseSalary: 7800000,
        rating: 4.9,
      },
      {
        email: 'barber2_2@barbersmart.vn',
        phone: '0911200202',
        fullName: 'Hoàng Minh Triết',
        avatarUrl:
          'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=400&q=80',
        coverUrl:
          'https://images.unsplash.com/photo-1585747860715-2ba37e788b70?w=900&q=80',
        bio: 'Chuyên Side Part 7/3, Comma Hair và phục hồi tóc hư tổn.',
        baseSalary: 7200000,
        rating: 4.9,
      },
      {
        email: 'barber2_3@barbersmart.vn',
        phone: '0911200203',
        fullName: 'Trịnh Gia Bảo',
        avatarUrl:
          'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?w=400&q=80',
        coverUrl:
          'https://images.unsplash.com/photo-1622286342621-4bd786c2447c?w=900&q=80',
        bio: 'Chuyên cạo râu tạo hình nghệ thuật & Taper Fade sắc nét.',
        baseSalary: 6800000,
        rating: 4.8,
      },
      {
        email: 'barber2_4@barbersmart.vn',
        phone: '0911200204',
        fullName: 'Ngô Quốc Khánh',
        avatarUrl:
          'https://images.unsplash.com/photo-1504257432389-52343af06ae3?w=400&q=80',
        coverUrl:
          'https://images.unsplash.com/photo-1599351431202-1e0f0137899a?w=900&q=80',
        bio: 'Tư vấn form tóc chuẩn từng khuôn mặt Á Đông.',
        baseSalary: 6500000,
        rating: 4.8,
      },
    ],
  },
  {
    managerEmail: 'manager3@barbersmart.vn',
    managerPhone: '0903888222',
    managerName: 'Phạm Quốc Bảo',
    managerAvatar:
      'https://images.unsplash.com/photo-1560250097-0b93528c311a?w=400&q=80',
    managerCover:
      'https://images.unsplash.com/photo-1622286342621-4bd786c2447c?w=1000&q=80',
    shopName: '30Shine Studio Vạn Phúc',
    address: 'Số 82 Đường Vạn Phúc, Phường Vạn Phúc, Quận Hà Đông, Hà Nội',
    phone: '0903888222',
    openTime: '08:00',
    closeTime: '22:00',
    latitude: 20.9749,
    longitude: 105.7708,
    rating: 4.8,
    reviewCount: 205,
    avatarUrl:
      'https://images.unsplash.com/photo-1622286342621-4bd786c2447c?w=400&q=80',
    coverUrl:
      'https://images.unsplash.com/photo-1621605815971-fbc98d665033?w=1000&q=80',
    galleryUrls: [
      'https://images.unsplash.com/photo-1621605815971-fbc98d665033?w=900&q=80',
      'https://images.unsplash.com/photo-1599351431202-1e0f0137899a?w=900&q=80',
      'https://images.unsplash.com/photo-1585747860715-2ba37e788b70?w=900&q=80',
    ],
    description:
      'Tổ hợp cắt tóc công nghệ cao & Shine Combo 10 bước nổi tiếng tại Đường Vạn Phúc, Hà Đông. Không gian rộng rãi, phục vụ nhanh chuẩn giờ.',
    isHighlighted100Days: true,
    highlightPaymentCode: 'PAYHLSEED003',
    barbers: [
      {
        email: 'barber3_1@barbersmart.vn',
        phone: '0911200301',
        fullName: 'Vương Hải Đăng',
        avatarUrl:
          'https://images.unsplash.com/photo-1501196354995-cbb51c65aaea?w=400&q=80',
        coverUrl:
          'https://images.unsplash.com/photo-1621605815971-fbc98d665033?w=900&q=80',
        bio: 'Top Stylist khu vực Hà Đông, chuyên uốn con sâu & Premlock.',
        baseSalary: 7500000,
        rating: 4.9,
      },
      {
        email: 'barber3_2@barbersmart.vn',
        phone: '0911200302',
        fullName: 'Lương Thế Vinh',
        avatarUrl:
          'https://images.unsplash.com/photo-1463453091185-61582044d556?w=400&q=80',
        coverUrl:
          'https://images.unsplash.com/photo-1585747860715-2ba37e788b70?w=900&q=80',
        bio: 'Chuyên Short Quiff, Sport năng động cho mùa hè.',
        baseSalary: 6800000,
        rating: 4.8,
      },
      {
        email: 'barber3_3@barbersmart.vn',
        phone: '0911200303',
        fullName: 'Đinh Trọng Nghĩa',
        avatarUrl:
          'https://images.unsplash.com/photo-1528892952291-009c663ce843?w=400&q=80',
        coverUrl:
          'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?w=900&q=80',
        bio: 'Tay kéo vàng 4 năm kinh nghiệm cắt Undercut & kẻ line nghệ thuật.',
        baseSalary: 6700000,
        rating: 4.8,
      },
      {
        email: 'barber3_4@barbersmart.vn',
        phone: '0911200304',
        fullName: 'Hà Minh Tuấn',
        avatarUrl:
          'https://images.unsplash.com/photo-1542909168-82c3e7fdca5c?w=400&q=80',
        coverUrl:
          'https://images.unsplash.com/photo-1599351431202-1e0f0137899a?w=900&q=80',
        bio: 'Chuyên nhuộm màu thời trang & ép side gọn gàng.',
        baseSalary: 6500000,
        rating: 4.7,
      },
    ],
  },
  {
    managerEmail: 'manager4@barbersmart.vn',
    managerPhone: '0904888333',
    managerName: 'Vũ Đình Liêm',
    managerAvatar:
      'https://images.unsplash.com/photo-1566492031773-4f4e44671857?w=400&q=80',
    managerCover:
      'https://images.unsplash.com/photo-1599351431202-1e0f0137899a?w=1000&q=80',
    shopName: 'Liem Barber Shop Hà Đông',
    address: 'Số 19 Nguyễn Thanh Bình, Phường Vạn Phúc, Quận Hà Đông, Hà Nội',
    phone: '0904888333',
    openTime: '09:00',
    closeTime: '21:00',
    latitude: 20.9776,
    longitude: 105.7695,
    rating: 4.8,
    reviewCount: 94,
    avatarUrl:
      'https://images.unsplash.com/photo-1599351431202-1e0f0137899a?w=400&q=80',
    coverUrl:
      'https://images.unsplash.com/photo-1599351431202-1e0f0137899a?w=1000&q=80',
    galleryUrls: [
      'https://images.unsplash.com/photo-1599351431202-1e0f0137899a?w=900&q=80',
      'https://images.unsplash.com/photo-1585747860715-2ba37e788b70?w=900&q=80',
    ],
    description:
      'Phong cách Chicano & Vintage đặc trưng ngay trục đường Nguyễn Thanh Bình - Vạn Phúc. Đậm chất nghệ thuật đường phố dành cho anh em cá tính.',
    isHighlighted100Days: false,
    barbers: [
      {
        email: 'barber4_1@barbersmart.vn',
        phone: '0911200401',
        fullName: 'Trương Quốc Việt',
        avatarUrl:
          'https://images.unsplash.com/photo-1531427186611-ecfd6d936c79?w=400&q=80',
        coverUrl:
          'https://images.unsplash.com/photo-1599351431202-1e0f0137899a?w=900&q=80',
        bio: 'Chuyên Tattoo Hair, Buzz Cut & High Skin Fade cực nét.',
        baseSalary: 7200000,
        rating: 4.9,
      },
      {
        email: 'barber4_2@barbersmart.vn',
        phone: '0911200402',
        fullName: 'Phùng Thanh Độ',
        avatarUrl:
          'https://images.unsplash.com/photo-1548372290-8d01b6c8e78c?w=400&q=80',
        coverUrl:
          'https://images.unsplash.com/photo-1585747860715-2ba37e788b70?w=900&q=80',
        bio: 'Chuyên Slick Back cổ điển và vuốt pomade chuẩn bài.',
        baseSalary: 6800000,
        rating: 4.8,
      },
      {
        email: 'barber4_3@barbersmart.vn',
        phone: '0911200403',
        fullName: 'Mai Xuân Trường',
        avatarUrl:
          'https://images.unsplash.com/photo-1552374196-c4e7ffc6e126?w=400&q=80',
        coverUrl:
          'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?w=900&q=80',
        bio: 'Kỹ thuật tỉa kéo thủ công giúp form tóc giữ nếp suốt 30 ngày.',
        baseSalary: 6500000,
        rating: 4.8,
      },
      {
        email: 'barber4_4@barbersmart.vn',
        phone: '0911200404',
        fullName: 'Đoàn Văn Hậu',
        avatarUrl:
          'https://images.unsplash.com/photo-1513956589380-bad6acb9b9d4?w=400&q=80',
        coverUrl:
          'https://images.unsplash.com/photo-1621605815971-fbc98d665033?w=900&q=80',
        bio: 'Chuyên kiểu tóc thể thao gọn khỏe, dễ chăm sóc tại nhà.',
        baseSalary: 6300000,
        rating: 4.7,
      },
    ],
  },
  {
    managerEmail: 'manager5@barbersmart.vn',
    managerPhone: '0905888444',
    managerName: 'Đỗ Mạnh Hùng',
    managerAvatar:
      'https://images.unsplash.com/photo-1556157382-97eda2d62296?w=400&q=80',
    managerCover:
      'https://images.unsplash.com/photo-1622286342621-4bd786c2447c?w=1000&q=80',
    shopName: 'Classic Fade Club Vạn Phúc',
    address: 'Số 35 Ngô Thì Nhậm, Giáp Vạn Phúc, Quận Hà Đông, Hà Nội',
    phone: '0905888444',
    openTime: '08:30',
    closeTime: '20:30',
    latitude: 20.9734,
    longitude: 105.7751,
    rating: 4.7,
    reviewCount: 73,
    avatarUrl:
      'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?w=400&q=80',
    coverUrl:
      'https://images.unsplash.com/photo-1622286342621-4bd786c2447c?w=1000&q=80',
    galleryUrls: [
      'https://images.unsplash.com/photo-1622286342621-4bd786c2447c?w=900&q=80',
      'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?w=900&q=80',
    ],
    description:
      'Câu lạc bộ cắt tóc nam ấm cúng gần cầu Am - Vạn Phúc, Hà Đông. Dịch vụ tận tâm, giá hợp lý cho sinh viên và dân văn phòng.',
    isHighlighted100Days: false,
    barbers: [
      {
        email: 'barber5_1@barbersmart.vn',
        phone: '0911200501',
        fullName: 'Cao Thái Sơn',
        avatarUrl:
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&q=80',
        coverUrl:
          'https://images.unsplash.com/photo-1622286342621-4bd786c2447c?w=900&q=80',
        bio: '5 năm kinh nghiệm cắt tóc nam cổ điển & chăm sóc râu.',
        baseSalary: 6800000,
        rating: 4.8,
      },
      {
        email: 'barber5_2@barbersmart.vn',
        phone: '0911200502',
        fullName: 'Tạ Minh Đức',
        avatarUrl:
          'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400&q=80',
        coverUrl:
          'https://images.unsplash.com/photo-1585747860715-2ba37e788b70?w=900&q=80',
        bio: 'Chuyên Textured Crop & French Crop gọn gàng lịch sự.',
        baseSalary: 6500000,
        rating: 4.7,
      },
      {
        email: 'barber5_3@barbersmart.vn',
        phone: '0911200503',
        fullName: 'Lâm Bảo Châu',
        avatarUrl:
          'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=400&q=80',
        coverUrl:
          'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?w=900&q=80',
        bio: 'Chuyên gội massage cổ vai gáy & tạo kiểu Layer trẻ trung.',
        baseSalary: 6200000,
        rating: 4.7,
      },
    ],
  },
];

@Injectable()
export class DatabaseSeederService implements OnModuleInit {
  private readonly logger = new Logger(DatabaseSeederService.name);

  constructor(
    @InjectRepository(UserEntity)
    private readonly userRepo: Repository<UserEntity>,
    @InjectRepository(ShopEntity)
    private readonly shopRepo: Repository<ShopEntity>,
    @InjectRepository(BarberEntity)
    private readonly barberRepo: Repository<BarberEntity>,
    @InjectRepository(ServiceEntity)
    private readonly serviceRepo: Repository<ServiceEntity>,
    @InjectRepository(TransactionEntity)
    private readonly txRepo: Repository<TransactionEntity>,
    @InjectRepository(ReviewEntity)
    private readonly reviewRepo: Repository<ReviewEntity>,
    @InjectRepository(PostEntity)
    private readonly postRepo: Repository<PostEntity>,
  ) {}

  async onModuleInit() {
    try {
      await this.seedAll();
    } catch (err) {
      this.logger.error('Lỗi khi chạy DatabaseSeederService:', err);
    }
  }

  private async upsertUser(params: {
    email: string;
    phone: string;
    fullName: string;
    role: UserRole;
    passwordHash: string;
    avatarUrl?: string;
    coverUrl?: string;
  }): Promise<UserEntity> {
    const email = params.email.trim().toLowerCase();
    let user = await this.userRepo.findOne({ where: { email } });
    if (!user) {
      const byPhone = await this.userRepo.findOne({
        where: { phone: params.phone },
      });
      if (byPhone) {
        user = byPhone;
      }
    }

    if (!user) {
      return this.userRepo.save(
        this.userRepo.create({
          email,
          phone: params.phone,
          fullName: params.fullName,
          passwordHash: params.passwordHash,
          role: params.role,
          gender: Gender.MALE,
          birthDate: '1997-08-15',
          avatarUrl: params.avatarUrl ?? DEFAULT_AVATAR_URL,
          coverUrl: params.coverUrl ?? '',
        }),
      );
    }

    let changed = false;
    if (user.role !== params.role) {
      user.role = params.role;
      changed = true;
    }
    if (!user.avatarUrl || user.avatarUrl.trim().length === 0) {
      user.avatarUrl = params.avatarUrl ?? DEFAULT_AVATAR_URL;
      changed = true;
    } else if (
      params.avatarUrl &&
      user.avatarUrl === DEFAULT_AVATAR_URL &&
      params.avatarUrl !== DEFAULT_AVATAR_URL
    ) {
      user.avatarUrl = params.avatarUrl;
      changed = true;
    }
    if ((!user.coverUrl || user.coverUrl.trim().length === 0) && params.coverUrl) {
      user.coverUrl = params.coverUrl;
      changed = true;
    }

    return changed ? this.userRepo.save(user) : user;
  }

  async seedAll() {
    this.logger.log(
      'Đang kiểm tra & khởi tạo dữ liệu mẫu cụm Vạn Phúc - Hà Đông trên Supabase...',
    );

    const defaultPasswordHash = await hashPassword('123456');

    // 1. Đảm bảo toàn bộ tài khoản cũ chưa có ảnh đại diện đều nhận Avatar xám trống mặc định
    await this.userRepo.update(
      { avatarUrl: IsNull() },
      { avatarUrl: DEFAULT_AVATAR_URL },
    );
    await this.userRepo.update(
      { avatarUrl: '' },
      { avatarUrl: DEFAULT_AVATAR_URL },
    );

    // 2. Tạo tài khoản Admin hệ thống & Khách hàng mẫu
    await this.upsertUser({
      email: 'admin@barbersmart.vn',
      phone: '0900999999',
      fullName: 'Quản Trị Viên Hệ Thống',
      role: UserRole.ADMIN,
      passwordHash: defaultPasswordHash,
      avatarUrl:
        'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=400&q=80',
      coverUrl:
        'https://images.unsplash.com/photo-1585747860715-2ba37e788b70?w=1000&q=80',
    });

    const customerMain = await this.upsertUser({
      email: 'user@barbersmart.vn',
      phone: '0988111222',
      fullName: 'Nguyễn Tuấn Anh',
      role: UserRole.USER,
      passwordHash: defaultPasswordHash,
      avatarUrl:
        'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=400&q=80',
      coverUrl:
        'https://images.unsplash.com/photo-1585747860715-2ba37e788b70?w=1000&q=80',
    });

    const customerDefaultAvatar = await this.upsertUser({
      email: 'khachmoi@barbersmart.vn',
      phone: '0988111333',
      fullName: 'Hoàng Gia Huy',
      role: UserRole.USER,
      passwordHash: defaultPasswordHash,
      avatarUrl: DEFAULT_AVATAR_URL,
    });

    const highlightTargetExpiry = new Date(
      Date.now() + 100 * 24 * 60 * 60 * 1000,
    );
    const minValidHighlight = new Date(
      Date.now() + 90 * 24 * 60 * 60 * 1000,
    );

    // 3. Khởi tạo 5 Quán cắt tóc xoay quanh Vạn Phúc, Hà Đông + 5 Manager + 19 Barber + Dịch vụ + Gói Nổi bật 100 ngày
    const seededShops: ShopEntity[] = [];

    for (const spec of VAN_PHUC_SHOPS_SEED) {
      const manager = await this.upsertUser({
        email: spec.managerEmail,
        phone: spec.managerPhone,
        fullName: spec.managerName,
        role: UserRole.MANAGER,
        passwordHash: defaultPasswordHash,
        avatarUrl: spec.managerAvatar,
        coverUrl: spec.managerCover,
      });

      let shop = await this.shopRepo.findOne({ where: { ownerId: manager.id } });
      if (!shop) {
        shop = await this.shopRepo.findOne({ where: { name: spec.shopName } });
      }

      const desiredHighlight = spec.isHighlighted100Days
        ? shop?.highlightExpiresAt && shop.highlightExpiresAt > minValidHighlight
          ? shop.highlightExpiresAt
          : highlightTargetExpiry
        : shop?.highlightExpiresAt ?? null;

      if (!shop) {
        shop = await this.shopRepo.save(
          this.shopRepo.create({
            ownerId: manager.id,
            name: spec.shopName,
            address: spec.address,
            phone: spec.phone,
            openTime: spec.openTime,
            closeTime: spec.closeTime,
            latitude: spec.latitude,
            longitude: spec.longitude,
            rating: spec.rating,
            reviewCount: spec.reviewCount,
            avatarUrl: spec.avatarUrl,
            coverUrl: spec.coverUrl,
            galleryUrls: spec.galleryUrls,
            description: spec.description,
            isActive: true,
            highlightExpiresAt: desiredHighlight,
          }),
        );
      } else {
        // Cập nhật lại quán cũ (VD: quán demo TP.HCM cũ của manager@barbersmart.vn) về đúng tọa độ Vạn Phúc - Hà Đông
        shop.name = spec.shopName;
        shop.address = spec.address;
        shop.phone = spec.phone;
        shop.openTime = spec.openTime;
        shop.closeTime = spec.closeTime;
        shop.latitude = spec.latitude;
        shop.longitude = spec.longitude;
        shop.avatarUrl = shop.avatarUrl || spec.avatarUrl;
        shop.coverUrl = shop.coverUrl || spec.coverUrl;
        shop.galleryUrls =
          shop.galleryUrls && shop.galleryUrls.length > 0
            ? shop.galleryUrls
            : spec.galleryUrls;
        shop.description = spec.description;
        shop.isActive = true;
        if (spec.isHighlighted100Days) {
          shop.highlightExpiresAt = desiredHighlight;
        }
        shop = await this.shopRepo.save(shop);
      }

      seededShops.push(shop);

      // Seed bản ghi Giao dịch "Đã mua gói Nổi bật" cho 3 quán Nổi bật (hết hạn sau 100 ngày)
      if (spec.isHighlighted100Days && spec.highlightPaymentCode) {
        const existingTx = await this.txRepo.findOne({
          where: { paymentCode: spec.highlightPaymentCode },
        });
        if (!existingTx) {
          await this.txRepo.save(
            this.txRepo.create({
              paymentCode: spec.highlightPaymentCode,
              transferContent: `PAY HIGHLIGHT ${spec.highlightPaymentCode}`,
              userId: manager.id,
              shopId: shop.id,
              type: TransactionType.BUY_HIGHLIGHT,
              highlightPlan: HighlightPlan.THREE_DAYS,
              amount: 90000,
              qrImageUrl:
                'https://img.vietqr.io/image/ICB-101886339075-compact2.png?amount=90000&addInfo=PAY%20HIGHLIGHT%20SEED',
              status: TransactionStatus.SUCCESS,
              sepayReferenceId: `SEPAY_SEED_${spec.highlightPaymentCode}`,
              metadataJson: {
                note: 'Gói Nổi bật khởi tạo mẫu (hiệu lực 100 ngày)',
                durationDays: 100,
              },
              paidAt: new Date(),
            }),
          );
        }
      }

      // Seed 3-4 Barber thực cho từng quán
      for (const bSpec of spec.barbers) {
        const barberUser = await this.upsertUser({
          email: bSpec.email,
          phone: bSpec.phone,
          fullName: bSpec.fullName,
          role: UserRole.BARBER,
          passwordHash: defaultPasswordHash,
          avatarUrl: bSpec.avatarUrl,
          coverUrl: bSpec.coverUrl,
        });

        let barberProfile = await this.barberRepo.findOne({
          where: { userId: barberUser.id },
        });
        if (!barberProfile) {
          await this.barberRepo.save(
            this.barberRepo.create({
              userId: barberUser.id,
              shopId: shop.id,
              baseSalary: bSpec.baseSalary,
              isActive: true,
              bio: bSpec.bio,
              rating: bSpec.rating,
            }),
          );
        } else if (barberProfile.shopId !== shop.id) {
          barberProfile.shopId = shop.id;
          barberProfile.bio = bSpec.bio;
          await this.barberRepo.save(barberProfile);
        }
      }

      // Seed 4 Dịch vụ tiêu chuẩn cho từng quán nếu chưa đủ
      const existingServicesCount = await this.serviceRepo.count({
        where: { shopId: shop.id },
      });
      if (existingServicesCount === 0) {
        await this.serviceRepo.save([
          this.serviceRepo.create({
            shopId: shop.id,
            name: 'Cắt tạo kiểu Quý ông (Skin Fade / Side Part)',
            price: 90000,
            durationMinutes: 30,
            description: 'Tư vấn form tóc, cắt tạo kiểu, xả sạch và vuốt sáp cao cấp.',
          }),
          this.serviceRepo.create({
            shopId: shop.id,
            name: 'Combo Đế Vương 7 Bước (Cắt + Gội + Massage Đá Nóng)',
            price: 150000,
            durationMinutes: 45,
            description: 'Trọn gói cắt tạo kiểu, gội dưỡng sinh và massage cổ vai gáy.',
          }),
          this.serviceRepo.create({
            shopId: shop.id,
            name: 'Cạo mặt khăn nóng & Tạo dáng râu',
            price: 60000,
            durationMinutes: 15,
            description: 'Chườm khăn ấm mở lỗ chân lông, cạo êm ái bằng dao chuyên dụng.',
          }),
          this.serviceRepo.create({
            shopId: shop.id,
            name: 'Uốn phồng Hàn Quốc / Nhuộm thời trang',
            price: 320000,
            durationMinutes: 60,
            description: 'Thuốc uốn/nhuộm chính hãng giữ nếp bền đẹp không khô xơ.',
          }),
        ]);
      }
    }

    // 4. Seed Đánh giá (Reviews) & Bài viết Mạng xã hội (Posts) mẫu nếu DB chưa có
    const totalReviews = await this.reviewRepo.count();
    if (totalReviews === 0 && seededShops.length >= 2) {
      await this.reviewRepo.save([
        this.reviewRepo.create({
          shopId: seededShops[0].id,
          customerId: customerMain.id,
          rating: 5,
          comment:
            'Quán ngay Phố Lụa Vạn Phúc cực dễ tìm, anh em Barber cắt Side Part tỉ mỉ và gội đầu rất êm!',
        }),
        this.reviewRepo.create({
          shopId: seededShops[1].id,
          customerId: customerDefaultAvatar.id,
          rating: 5,
          comment:
            'Không gian trên trục Tố Hữu thoáng mát, đặt lịch trước qua BarberSmart đến là được cắt ngay không phải đợi.',
        }),
      ]);
    }

    const totalPosts = await this.postRepo.count();
    if (totalPosts === 0) {
      await this.postRepo.save([
        this.postRepo.create({
          authorId: customerMain.id,
          caption:
            'Vừa tút lại quả đầu Side Part Pompadour tại Vạn Phúc Barber House (Hà Đông), ưng ý từng đường kéo!',
          imageUrls: [
            'https://images.unsplash.com/photo-1622286342621-4bd786c2447c?w=800&q=80',
            'https://images.unsplash.com/photo-1621605815971-fbc98d665033?w=800&q=80',
            'https://images.unsplash.com/photo-1599351431202-1e0f0137899a?w=800&q=80',
          ],
        }),
      ]);
    }

    const mainManager = await this.userRepo.findOne({
      where: { email: 'manager@barbersmart.vn' },
    });
    if (mainManager) {
      const mgrPostCount = await this.postRepo.count({
        where: { authorId: mainManager.id },
      });
      if (mgrPostCount === 0) {
        await this.postRepo.save(
          this.postRepo.create({
            authorId: mainManager.id,
            caption:
              'Không gian Vạn Phúc Barber House hôm nay đã sẵn sàng đón anh em Hà Đông ghé trải nghiệm Combo Đế Vương 7 Bước!',
            imageUrls: [
              'https://images.unsplash.com/photo-1585747860715-2ba37e788b70?w=900&q=80',
              'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?w=900&q=80',
            ],
          }),
        );
      }
    }

    const mainBarber = await this.userRepo.findOne({
      where: { email: 'barber@barbersmart.vn' },
    });
    if (mainBarber) {
      const barberPostCount = await this.postRepo.count({
        where: { authorId: mainBarber.id },
      });
      if (barberPostCount === 0) {
        await this.postRepo.save(
          this.postRepo.create({
            authorId: mainBarber.id,
            caption:
              'Tác phẩm Skin Fade & Pompadour vừa hoàn thiện cho khách quen sáng nay tại Vạn Phúc Barber House.',
            imageUrls: [
              'https://images.unsplash.com/photo-1621605815971-fbc98d665033?w=800&q=80',
              'https://images.unsplash.com/photo-1622286342621-4bd786c2447c?w=800&q=80',
            ],
          }),
        );
      }
    }

    this.logger.log(
      `Hoàn tất Seeding Supabase: ${seededShops.length} quán khu vực Vạn Phúc - Hà Đông (3 quán Nổi bật +100 ngày) & đầy đủ Manager/Barber!`,
    );
  }
}

@Module({
  imports: [
    TypeOrmModule.forFeature([
      UserEntity,
      ShopEntity,
      BarberEntity,
      ServiceEntity,
      TransactionEntity,
      ReviewEntity,
      PostEntity,
      PostCommentEntity,
    ]),
  ],
  providers: [DatabaseSeederService],
  exports: [DatabaseSeederService],
})
export class DatabaseSeederModule {}

