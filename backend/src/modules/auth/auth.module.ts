import {
  BadRequestException,
  Body,
  ConflictException,
  Controller,
  Get,
  Injectable,
  Module,
  Patch,
  Post,
  UnauthorizedException,
  UseGuards,
} from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { JwtModule, JwtService } from '@nestjs/jwt';
import { PassportModule, PassportStrategy } from '@nestjs/passport';
import { InjectRepository, TypeOrmModule } from '@nestjs/typeorm';
import { randomBytes, scrypt as scryptCb, timingSafeEqual } from 'crypto';
import { promisify } from 'util';

const scryptAsync = promisify(scryptCb);

export async function hashPassword(password: string): Promise<string> {
  const salt = randomBytes(16).toString('hex');
  const derivedKey = (await scryptAsync(password, salt, 64)) as Buffer;
  return `${salt}:${derivedKey.toString('hex')}`;
}

async function verifyPassword(
  password: string,
  storedHash: string,
): Promise<boolean> {
  const [salt, keyHex] = storedHash.split(':');
  if (!salt || !keyHex) return false;
  const keyBuffer = Buffer.from(keyHex, 'hex');
  const derivedKey = (await scryptAsync(password, salt, 64)) as Buffer;
  if (keyBuffer.length !== derivedKey.length) return false;
  return timingSafeEqual(keyBuffer, derivedKey);
}
import {
  IsEmail,
  IsEnum,
  IsNotEmpty,
  IsOptional,
  IsString,
  Matches,
  MinLength,
} from 'class-validator';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { Repository } from 'typeorm';
import { CurrentUser, JwtAuthGuard } from '../../common/auth.guards';
import {
  BarberEntity,
  DEFAULT_AVATAR_URL,
  Gender,
  OtpPurpose,
  OtpVerificationEntity,
  ShopEntity,
  UserEntity,
  UserRole,
} from '../../database/entities';
import { MailerService } from '../mailer/mailer.module';

export const VN_PHONE_REGEX =
  /^(032|033|034|035|036|037|038|039|086|096|097|098|081|082|083|084|085|088|091|094|070|076|077|078|079|089|090|093)\d{7}$/;

// ==================== DTOs ====================
export class RegisterRequestOtpDto {
  @IsString()
  @IsNotEmpty({ message: 'Vui lòng nhập họ tên' })
  fullName!: string;

  @IsEmail({}, { message: 'Email xác thực không hợp lệ' })
  email!: string;

  @IsString()
  @Matches(VN_PHONE_REGEX, { message: 'số điện thoại không đúng' })
  phone!: string;

  @IsString()
  @MinLength(6, { message: 'Mật khẩu tối thiểu 6 ký tự' })
  password!: string;

  @IsString()
  confirmPassword!: string;
}

export class VerifyOtpDto {
  @IsEmail()
  email!: string;

  @IsString()
  @MinLength(6)
  otpCode!: string;
}

export class LoginDto {
  @IsEmail({}, { message: 'Email không hợp lệ' })
  email!: string;

  @IsString()
  @IsNotEmpty()
  password!: string;
}

export class ResetPasswordDto {
  @IsEmail()
  email!: string;

  @IsString()
  otpCode!: string;

  @IsString()
  @MinLength(6)
  newPassword!: string;
}

export class UpdateProfileDto {
  @IsOptional()
  @IsString()
  fullName?: string;

  @IsOptional()
  @IsString()
  avatarUrl?: string;

  @IsOptional()
  @IsString()
  coverUrl?: string;

  @IsOptional()
  @IsString()
  birthDate?: string;

  @IsOptional()
  @IsEnum(Gender)
  gender?: Gender;
}

// ==================== JWT STRATEGY ====================
@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(
    config: ConfigService,
    @InjectRepository(UserEntity)
    private readonly userRepo: Repository<UserEntity>,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: config.get<string>('JWT_SECRET', 'barbersmart_secret_2026'),
    });
  }

  async validate(payload: { sub: string; email: string; role: UserRole }) {
    const user = await this.userRepo.findOne({ where: { id: payload.sub } });
    if (!user) throw new UnauthorizedException('Phiên đăng nhập không hợp lệ');
    return user;
  }
}

// ==================== SERVICE ====================
@Injectable()
export class AuthService {
  constructor(
    @InjectRepository(UserEntity)
    private readonly userRepo: Repository<UserEntity>,
    @InjectRepository(OtpVerificationEntity)
    private readonly otpRepo: Repository<OtpVerificationEntity>,
    @InjectRepository(ShopEntity)
    private readonly shopRepo: Repository<ShopEntity>,
    @InjectRepository(BarberEntity)
    private readonly barberRepo: Repository<BarberEntity>,
    private readonly jwtService: JwtService,
    private readonly mailerService: MailerService,
  ) {}

  private generateSixDigitOtp(): string {
    return Math.floor(100000 + Math.random() * 900000).toString();
  }

  async formatUserResponse(user: UserEntity) {
    const managedShop = await this.shopRepo.findOne({
      where: { ownerId: user.id },
    });
    const barberProfile = await this.barberRepo.findOne({
      where: { userId: user.id },
    });

    return {
      id: user.id,
      email: user.email,
      phone: user.phone,
      fullName: user.fullName,
      role: user.role,
      avatarUrl:
        user.avatarUrl && user.avatarUrl.trim().length > 0
          ? user.avatarUrl
          : DEFAULT_AVATAR_URL,
      coverUrl: user.coverUrl ?? '',
      birthDate: user.birthDate ?? null,
      gender: user.gender,
      managedShopId: managedShop?.id ?? null,
      workingShopId: barberProfile?.shopId ?? null,
      barberId: barberProfile?.id ?? null,
    };
  }

  async requestRegisterOtp(dto: RegisterRequestOtpDto) {
    if (dto.password !== dto.confirmPassword) {
      throw new BadRequestException('Nhập lại mật khẩu không trùng khớp');
    }

    const email = dto.email.trim().toLowerCase();
    const phone = dto.phone.trim();
    if (!VN_PHONE_REGEX.test(phone)) {
      throw new BadRequestException('số điện thoại không đúng');
    }

    const existingEmail = await this.userRepo.findOne({ where: { email } });
    if (existingEmail) {
      throw new ConflictException('Email này đã được đăng ký');
    }

    const existingPhone = await this.userRepo.findOne({ where: { phone } });
    if (existingPhone) {
      throw new ConflictException('Số điện thoại này đã được đăng ký');
    }

    const passwordHash = await hashPassword(dto.password);
    const otpCode = this.generateSixDigitOtp();

    await this.otpRepo.save(
      this.otpRepo.create({
        email,
        otpCode,
        purpose: OtpPurpose.REGISTER,
        payloadJson: {
          fullName: dto.fullName.trim(),
          email,
          phone,
          passwordHash,
        },
        expiresAt: new Date(Date.now() + 5 * 60 * 1000),
      }),
    );

    await this.mailerService.sendOtpEmail(email, otpCode, dto.fullName.trim());
    return {
      message: 'Mã OTP 6 số đã được gửi tới Email của bạn',
      email,
    };
  }

  async verifyRegisterOtp(dto: VerifyOtpDto) {
    const email = dto.email.trim().toLowerCase();
    const otpRecord = await this.otpRepo.findOne({
      where: {
        email,
        otpCode: dto.otpCode.trim(),
        purpose: OtpPurpose.REGISTER,
        isUsed: false,
      },
      order: { createdAt: 'DESC' },
    });

    if (!otpRecord || otpRecord.expiresAt < new Date()) {
      throw new BadRequestException('Mã OTP không hợp lệ hoặc đã hết hạn');
    }

    const payload = otpRecord.payloadJson!;
    otpRecord.isUsed = true;
    await this.otpRepo.save(otpRecord);

    // Tạo User với Role mặc định bắt buộc là USER & Avatar mặc định xám trống
    const newUser = await this.userRepo.save(
      this.userRepo.create({
        email: payload.email,
        phone: payload.phone,
        fullName: payload.fullName,
        passwordHash: payload.passwordHash,
        role: UserRole.USER,
        avatarUrl: DEFAULT_AVATAR_URL,
      }),
    );

    const accessToken = this.jwtService.sign({
      sub: newUser.id,
      email: newUser.email,
      role: newUser.role,
    });

    return {
      accessToken,
      user: await this.formatUserResponse(newUser),
    };
  }

  async login(dto: LoginDto) {
    const email = dto.email.trim().toLowerCase();
    const user = await this.userRepo.findOne({ where: { email } });
    if (!user) {
      throw new UnauthorizedException('Email hoặc mật khẩu không chính xác');
    }

    const valid = await verifyPassword(dto.password, user.passwordHash);
    if (!valid) {
      throw new UnauthorizedException('Email hoặc mật khẩu không chính xác');
    }

    const accessToken = this.jwtService.sign({
      sub: user.id,
      email: user.email,
      role: user.role,
    });

    return {
      accessToken,
      user: await this.formatUserResponse(user),
    };
  }

  async requestForgotPasswordOtp(emailInput: string) {
    const email = emailInput.trim().toLowerCase();
    const user = await this.userRepo.findOne({ where: { email } });
    if (!user) {
      throw new BadRequestException('Không tìm thấy tài khoản với Email này');
    }

    const otpCode = this.generateSixDigitOtp();
    await this.otpRepo.save(
      this.otpRepo.create({
        email,
        otpCode,
        purpose: OtpPurpose.RESET_PASSWORD,
        expiresAt: new Date(Date.now() + 5 * 60 * 1000),
      }),
    );

    await this.mailerService.sendOtpEmail(email, otpCode, user.fullName);
    return { message: 'Đã gửi mã OTP đặt lại mật khẩu qua Email' };
  }

  async resetPassword(dto: ResetPasswordDto) {
    const email = dto.email.trim().toLowerCase();
    const otpRecord = await this.otpRepo.findOne({
      where: {
        email,
        otpCode: dto.otpCode.trim(),
        purpose: OtpPurpose.RESET_PASSWORD,
        isUsed: false,
      },
      order: { createdAt: 'DESC' },
    });

    if (!otpRecord || otpRecord.expiresAt < new Date()) {
      throw new BadRequestException('Mã OTP không chính xác hoặc đã hết hạn');
    }

    otpRecord.isUsed = true;
    await this.otpRepo.save(otpRecord);

    const passwordHash = await hashPassword(dto.newPassword);
    await this.userRepo.update({ email }, { passwordHash });

    return { message: 'Đặt lại mật khẩu thành công' };
  }

  async updateProfile(userId: string, dto: UpdateProfileDto) {
    const patch: Partial<UserEntity> = {};
    if (dto.fullName !== undefined && dto.fullName.trim().length > 0) {
      patch.fullName = dto.fullName.trim();
    }
    if (dto.avatarUrl !== undefined) {
      patch.avatarUrl =
        dto.avatarUrl.trim().length > 0
          ? dto.avatarUrl.trim()
          : DEFAULT_AVATAR_URL;
    }
    if (dto.coverUrl !== undefined) {
      patch.coverUrl = dto.coverUrl.trim();
    }
    if (dto.birthDate !== undefined) {
      patch.birthDate = dto.birthDate;
    }
    if (dto.gender !== undefined) {
      patch.gender = dto.gender;
    }
    if (Object.keys(patch).length > 0) {
      await this.userRepo.update(userId, patch);
    }
    const updated = await this.userRepo.findOneOrFail({ where: { id: userId } });
    return this.formatUserResponse(updated);
  }
}

// ==================== CONTROLLER ====================
@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('register/request-otp')
  requestRegisterOtp(@Body() dto: RegisterRequestOtpDto) {
    return this.authService.requestRegisterOtp(dto);
  }

  @Post('register/verify-otp')
  verifyRegisterOtp(@Body() dto: VerifyOtpDto) {
    return this.authService.verifyRegisterOtp(dto);
  }

  @Post('login')
  login(@Body() dto: LoginDto) {
    return this.authService.login(dto);
  }

  @Post('forgot-password/request-otp')
  requestResetOtp(@Body() body: { email: string }) {
    return this.authService.requestForgotPasswordOtp(body.email);
  }

  @Post('forgot-password/reset')
  resetPassword(@Body() dto: ResetPasswordDto) {
    return this.authService.resetPassword(dto);
  }

  @Get('me')
  @UseGuards(JwtAuthGuard)
  getMe(@CurrentUser() user: UserEntity) {
    return this.authService.formatUserResponse(user);
  }

  @Patch('profile')
  @UseGuards(JwtAuthGuard)
  updateProfile(
    @CurrentUser() user: UserEntity,
    @Body() dto: UpdateProfileDto,
  ) {
    return this.authService.updateProfile(user.id, dto);
  }
}

@Module({
  imports: [
    PassportModule,
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: config.get<string>('JWT_SECRET', 'barbersmart_secret_2026'),
        signOptions: {
          expiresIn: config.get<string>('JWT_EXPIRES_IN', '7d') as any,
        },
      }),
    }),
    TypeOrmModule.forFeature([
      UserEntity,
      OtpVerificationEntity,
      ShopEntity,
      BarberEntity,
    ]),
  ],
  controllers: [AuthController],
  providers: [AuthService, JwtStrategy],
  exports: [AuthService, JwtModule],
})
export class AuthModule {}

