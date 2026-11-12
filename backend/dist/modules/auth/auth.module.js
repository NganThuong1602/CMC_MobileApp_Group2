"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.AuthModule = exports.AuthController = exports.AuthService = exports.JwtStrategy = exports.UpdateProfileDto = exports.ResetPasswordDto = exports.LoginDto = exports.VerifyOtpDto = exports.RegisterRequestOtpDto = exports.VN_PHONE_REGEX = void 0;
exports.hashPassword = hashPassword;
const common_1 = require("@nestjs/common");
const config_1 = require("@nestjs/config");
const jwt_1 = require("@nestjs/jwt");
const passport_1 = require("@nestjs/passport");
const typeorm_1 = require("@nestjs/typeorm");
const crypto_1 = require("crypto");
const util_1 = require("util");
const scryptAsync = (0, util_1.promisify)(crypto_1.scrypt);
async function hashPassword(password) {
    const salt = (0, crypto_1.randomBytes)(16).toString('hex');
    const derivedKey = (await scryptAsync(password, salt, 64));
    return `${salt}:${derivedKey.toString('hex')}`;
}
async function verifyPassword(password, storedHash) {
    const [salt, keyHex] = storedHash.split(':');
    if (!salt || !keyHex)
        return false;
    const keyBuffer = Buffer.from(keyHex, 'hex');
    const derivedKey = (await scryptAsync(password, salt, 64));
    if (keyBuffer.length !== derivedKey.length)
        return false;
    return (0, crypto_1.timingSafeEqual)(keyBuffer, derivedKey);
}
const class_validator_1 = require("class-validator");
const passport_jwt_1 = require("passport-jwt");
const typeorm_2 = require("typeorm");
const auth_guards_1 = require("../../common/auth.guards");
const entities_1 = require("../../database/entities");
const mailer_module_1 = require("../mailer/mailer.module");
exports.VN_PHONE_REGEX = /^(032|033|034|035|036|037|038|039|086|096|097|098|081|082|083|084|085|088|091|094|070|076|077|078|079|089|090|093)\d{7}$/;
class RegisterRequestOtpDto {
}
exports.RegisterRequestOtpDto = RegisterRequestOtpDto;
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.IsNotEmpty)({ message: 'Vui lòng nhập họ tên' }),
    __metadata("design:type", String)
], RegisterRequestOtpDto.prototype, "fullName", void 0);
__decorate([
    (0, class_validator_1.IsEmail)({}, { message: 'Email xác thực không hợp lệ' }),
    __metadata("design:type", String)
], RegisterRequestOtpDto.prototype, "email", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.Matches)(exports.VN_PHONE_REGEX, { message: 'số điện thoại không đúng' }),
    __metadata("design:type", String)
], RegisterRequestOtpDto.prototype, "phone", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MinLength)(6, { message: 'Mật khẩu tối thiểu 6 ký tự' }),
    __metadata("design:type", String)
], RegisterRequestOtpDto.prototype, "password", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], RegisterRequestOtpDto.prototype, "confirmPassword", void 0);
class VerifyOtpDto {
}
exports.VerifyOtpDto = VerifyOtpDto;
__decorate([
    (0, class_validator_1.IsEmail)(),
    __metadata("design:type", String)
], VerifyOtpDto.prototype, "email", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MinLength)(6),
    __metadata("design:type", String)
], VerifyOtpDto.prototype, "otpCode", void 0);
class LoginDto {
}
exports.LoginDto = LoginDto;
__decorate([
    (0, class_validator_1.IsEmail)({}, { message: 'Email không hợp lệ' }),
    __metadata("design:type", String)
], LoginDto.prototype, "email", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.IsNotEmpty)(),
    __metadata("design:type", String)
], LoginDto.prototype, "password", void 0);
class ResetPasswordDto {
}
exports.ResetPasswordDto = ResetPasswordDto;
__decorate([
    (0, class_validator_1.IsEmail)(),
    __metadata("design:type", String)
], ResetPasswordDto.prototype, "email", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], ResetPasswordDto.prototype, "otpCode", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MinLength)(6),
    __metadata("design:type", String)
], ResetPasswordDto.prototype, "newPassword", void 0);
class UpdateProfileDto {
}
exports.UpdateProfileDto = UpdateProfileDto;
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], UpdateProfileDto.prototype, "fullName", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], UpdateProfileDto.prototype, "avatarUrl", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], UpdateProfileDto.prototype, "coverUrl", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], UpdateProfileDto.prototype, "birthDate", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsEnum)(entities_1.Gender),
    __metadata("design:type", String)
], UpdateProfileDto.prototype, "gender", void 0);
let JwtStrategy = class JwtStrategy extends (0, passport_1.PassportStrategy)(passport_jwt_1.Strategy) {
    constructor(config, userRepo) {
        super({
            jwtFromRequest: passport_jwt_1.ExtractJwt.fromAuthHeaderAsBearerToken(),
            ignoreExpiration: false,
            secretOrKey: config.get('JWT_SECRET', 'barbersmart_secret_2026'),
        });
        this.userRepo = userRepo;
    }
    async validate(payload) {
        const user = await this.userRepo.findOne({ where: { id: payload.sub } });
        if (!user)
            throw new common_1.UnauthorizedException('Phiên đăng nhập không hợp lệ');
        return user;
    }
};
exports.JwtStrategy = JwtStrategy;
exports.JwtStrategy = JwtStrategy = __decorate([
    (0, common_1.Injectable)(),
    __param(1, (0, typeorm_1.InjectRepository)(entities_1.UserEntity)),
    __metadata("design:paramtypes", [config_1.ConfigService,
        typeorm_2.Repository])
], JwtStrategy);
let AuthService = class AuthService {
    constructor(userRepo, otpRepo, shopRepo, barberRepo, jwtService, mailerService) {
        this.userRepo = userRepo;
        this.otpRepo = otpRepo;
        this.shopRepo = shopRepo;
        this.barberRepo = barberRepo;
        this.jwtService = jwtService;
        this.mailerService = mailerService;
    }
    generateSixDigitOtp() {
        return Math.floor(100000 + Math.random() * 900000).toString();
    }
    async formatUserResponse(user) {
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
            avatarUrl: user.avatarUrl && user.avatarUrl.trim().length > 0
                ? user.avatarUrl
                : entities_1.DEFAULT_AVATAR_URL,
            coverUrl: user.coverUrl ?? '',
            birthDate: user.birthDate ?? null,
            gender: user.gender,
            managedShopId: managedShop?.id ?? null,
            workingShopId: barberProfile?.shopId ?? null,
            barberId: barberProfile?.id ?? null,
        };
    }
    async requestRegisterOtp(dto) {
        if (dto.password !== dto.confirmPassword) {
            throw new common_1.BadRequestException('Nhập lại mật khẩu không trùng khớp');
        }
        const email = dto.email.trim().toLowerCase();
        const phone = dto.phone.trim();
        if (!exports.VN_PHONE_REGEX.test(phone)) {
            throw new common_1.BadRequestException('số điện thoại không đúng');
        }
        const existingEmail = await this.userRepo.findOne({ where: { email } });
        if (existingEmail) {
            throw new common_1.ConflictException('Email này đã được đăng ký');
        }
        const existingPhone = await this.userRepo.findOne({ where: { phone } });
        if (existingPhone) {
            throw new common_1.ConflictException('Số điện thoại này đã được đăng ký');
        }
        const passwordHash = await hashPassword(dto.password);
        const otpCode = this.generateSixDigitOtp();
        await this.otpRepo.save(this.otpRepo.create({
            email,
            otpCode,
            purpose: entities_1.OtpPurpose.REGISTER,
            payloadJson: {
                fullName: dto.fullName.trim(),
                email,
                phone,
                passwordHash,
            },
            expiresAt: new Date(Date.now() + 5 * 60 * 1000),
        }));
        await this.mailerService.sendOtpEmail(email, otpCode, dto.fullName.trim());
        return {
            message: 'Mã OTP 6 số đã được gửi tới Email của bạn',
            email,
        };
    }
    async verifyRegisterOtp(dto) {
        const email = dto.email.trim().toLowerCase();
        const otpRecord = await this.otpRepo.findOne({
            where: {
                email,
                otpCode: dto.otpCode.trim(),
                purpose: entities_1.OtpPurpose.REGISTER,
                isUsed: false,
            },
            order: { createdAt: 'DESC' },
        });
        if (!otpRecord || otpRecord.expiresAt < new Date()) {
            throw new common_1.BadRequestException('Mã OTP không hợp lệ hoặc đã hết hạn');
        }
        const payload = otpRecord.payloadJson;
        otpRecord.isUsed = true;
        await this.otpRepo.save(otpRecord);
        const newUser = await this.userRepo.save(this.userRepo.create({
            email: payload.email,
            phone: payload.phone,
            fullName: payload.fullName,
            passwordHash: payload.passwordHash,
            role: entities_1.UserRole.USER,
            avatarUrl: entities_1.DEFAULT_AVATAR_URL,
        }));
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
    async login(dto) {
        const email = dto.email.trim().toLowerCase();
        const user = await this.userRepo.findOne({ where: { email } });
        if (!user) {
            throw new common_1.UnauthorizedException('Email hoặc mật khẩu không chính xác');
        }
        const valid = await verifyPassword(dto.password, user.passwordHash);
        if (!valid) {
            throw new common_1.UnauthorizedException('Email hoặc mật khẩu không chính xác');
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
    async requestForgotPasswordOtp(emailInput) {
        const email = emailInput.trim().toLowerCase();
        const user = await this.userRepo.findOne({ where: { email } });
        if (!user) {
            throw new common_1.BadRequestException('Không tìm thấy tài khoản với Email này');
        }
        const otpCode = this.generateSixDigitOtp();
        await this.otpRepo.save(this.otpRepo.create({
            email,
            otpCode,
            purpose: entities_1.OtpPurpose.RESET_PASSWORD,
            expiresAt: new Date(Date.now() + 5 * 60 * 1000),
        }));
        await this.mailerService.sendOtpEmail(email, otpCode, user.fullName);
        return { message: 'Đã gửi mã OTP đặt lại mật khẩu qua Email' };
    }
    async resetPassword(dto) {
        const email = dto.email.trim().toLowerCase();
        const otpRecord = await this.otpRepo.findOne({
            where: {
                email,
                otpCode: dto.otpCode.trim(),
                purpose: entities_1.OtpPurpose.RESET_PASSWORD,
                isUsed: false,
            },
            order: { createdAt: 'DESC' },
        });
        if (!otpRecord || otpRecord.expiresAt < new Date()) {
            throw new common_1.BadRequestException('Mã OTP không chính xác hoặc đã hết hạn');
        }
        otpRecord.isUsed = true;
        await this.otpRepo.save(otpRecord);
        const passwordHash = await hashPassword(dto.newPassword);
        await this.userRepo.update({ email }, { passwordHash });
        return { message: 'Đặt lại mật khẩu thành công' };
    }
    async updateProfile(userId, dto) {
        const patch = {};
        if (dto.fullName !== undefined && dto.fullName.trim().length > 0) {
            patch.fullName = dto.fullName.trim();
        }
        if (dto.avatarUrl !== undefined) {
            patch.avatarUrl =
                dto.avatarUrl.trim().length > 0
                    ? dto.avatarUrl.trim()
                    : entities_1.DEFAULT_AVATAR_URL;
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
};
exports.AuthService = AuthService;
exports.AuthService = AuthService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(entities_1.UserEntity)),
    __param(1, (0, typeorm_1.InjectRepository)(entities_1.OtpVerificationEntity)),
    __param(2, (0, typeorm_1.InjectRepository)(entities_1.ShopEntity)),
    __param(3, (0, typeorm_1.InjectRepository)(entities_1.BarberEntity)),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        jwt_1.JwtService,
        mailer_module_1.MailerService])
], AuthService);
let AuthController = class AuthController {
    constructor(authService) {
        this.authService = authService;
    }
    requestRegisterOtp(dto) {
        return this.authService.requestRegisterOtp(dto);
    }
    verifyRegisterOtp(dto) {
        return this.authService.verifyRegisterOtp(dto);
    }
    login(dto) {
        return this.authService.login(dto);
    }
    requestResetOtp(body) {
        return this.authService.requestForgotPasswordOtp(body.email);
    }
    resetPassword(dto) {
        return this.authService.resetPassword(dto);
    }
    getMe(user) {
        return this.authService.formatUserResponse(user);
    }
    updateProfile(user, dto) {
        return this.authService.updateProfile(user.id, dto);
    }
};
exports.AuthController = AuthController;
__decorate([
    (0, common_1.Post)('register/request-otp'),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [RegisterRequestOtpDto]),
    __metadata("design:returntype", void 0)
], AuthController.prototype, "requestRegisterOtp", null);
__decorate([
    (0, common_1.Post)('register/verify-otp'),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [VerifyOtpDto]),
    __metadata("design:returntype", void 0)
], AuthController.prototype, "verifyRegisterOtp", null);
__decorate([
    (0, common_1.Post)('login'),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [LoginDto]),
    __metadata("design:returntype", void 0)
], AuthController.prototype, "login", null);
__decorate([
    (0, common_1.Post)('forgot-password/request-otp'),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", void 0)
], AuthController.prototype, "requestResetOtp", null);
__decorate([
    (0, common_1.Post)('forgot-password/reset'),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [ResetPasswordDto]),
    __metadata("design:returntype", void 0)
], AuthController.prototype, "resetPassword", null);
__decorate([
    (0, common_1.Get)('me'),
    (0, common_1.UseGuards)(auth_guards_1.JwtAuthGuard),
    __param(0, (0, auth_guards_1.CurrentUser)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [entities_1.UserEntity]),
    __metadata("design:returntype", void 0)
], AuthController.prototype, "getMe", null);
__decorate([
    (0, common_1.Patch)('profile'),
    (0, common_1.UseGuards)(auth_guards_1.JwtAuthGuard),
    __param(0, (0, auth_guards_1.CurrentUser)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [entities_1.UserEntity,
        UpdateProfileDto]),
    __metadata("design:returntype", void 0)
], AuthController.prototype, "updateProfile", null);
exports.AuthController = AuthController = __decorate([
    (0, common_1.Controller)('auth'),
    __metadata("design:paramtypes", [AuthService])
], AuthController);
let AuthModule = class AuthModule {
};
exports.AuthModule = AuthModule;
exports.AuthModule = AuthModule = __decorate([
    (0, common_1.Module)({
        imports: [
            passport_1.PassportModule,
            jwt_1.JwtModule.registerAsync({
                imports: [config_1.ConfigModule],
                inject: [config_1.ConfigService],
                useFactory: (config) => ({
                    secret: config.get('JWT_SECRET', 'barbersmart_secret_2026'),
                    signOptions: {
                        expiresIn: config.get('JWT_EXPIRES_IN', '7d'),
                    },
                }),
            }),
            typeorm_1.TypeOrmModule.forFeature([
                entities_1.UserEntity,
                entities_1.OtpVerificationEntity,
                entities_1.ShopEntity,
                entities_1.BarberEntity,
            ]),
        ],
        controllers: [AuthController],
        providers: [AuthService, JwtStrategy],
        exports: [AuthService, jwt_1.JwtModule],
    })
], AuthModule);
//# sourceMappingURL=auth.module.js.map