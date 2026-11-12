import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
export declare function hashPassword(password: string): Promise<string>;
import { Strategy } from 'passport-jwt';
import { Repository } from 'typeorm';
import { BarberEntity, Gender, OtpVerificationEntity, ShopEntity, UserEntity, UserRole } from '../../database/entities';
import { MailerService } from '../mailer/mailer.module';
export declare const VN_PHONE_REGEX: RegExp;
export declare class RegisterRequestOtpDto {
    fullName: string;
    email: string;
    phone: string;
    password: string;
    confirmPassword: string;
}
export declare class VerifyOtpDto {
    email: string;
    otpCode: string;
}
export declare class LoginDto {
    email: string;
    password: string;
}
export declare class ResetPasswordDto {
    email: string;
    otpCode: string;
    newPassword: string;
}
export declare class UpdateProfileDto {
    fullName?: string;
    avatarUrl?: string;
    coverUrl?: string;
    birthDate?: string;
    gender?: Gender;
}
declare const JwtStrategy_base: new (...args: any[]) => Strategy;
export declare class JwtStrategy extends JwtStrategy_base {
    private readonly userRepo;
    constructor(config: ConfigService, userRepo: Repository<UserEntity>);
    validate(payload: {
        sub: string;
        email: string;
        role: UserRole;
    }): Promise<UserEntity>;
}
export declare class AuthService {
    private readonly userRepo;
    private readonly otpRepo;
    private readonly shopRepo;
    private readonly barberRepo;
    private readonly jwtService;
    private readonly mailerService;
    constructor(userRepo: Repository<UserEntity>, otpRepo: Repository<OtpVerificationEntity>, shopRepo: Repository<ShopEntity>, barberRepo: Repository<BarberEntity>, jwtService: JwtService, mailerService: MailerService);
    private generateSixDigitOtp;
    formatUserResponse(user: UserEntity): Promise<{
        id: string;
        email: string;
        phone: string;
        fullName: string;
        role: UserRole;
        avatarUrl: string;
        coverUrl: string;
        birthDate: string | null;
        gender: Gender;
        managedShopId: string | null;
        workingShopId: string | null;
        barberId: string | null;
    }>;
    requestRegisterOtp(dto: RegisterRequestOtpDto): Promise<{
        message: string;
        email: string;
    }>;
    verifyRegisterOtp(dto: VerifyOtpDto): Promise<{
        accessToken: string;
        user: {
            id: string;
            email: string;
            phone: string;
            fullName: string;
            role: UserRole;
            avatarUrl: string;
            coverUrl: string;
            birthDate: string | null;
            gender: Gender;
            managedShopId: string | null;
            workingShopId: string | null;
            barberId: string | null;
        };
    }>;
    login(dto: LoginDto): Promise<{
        accessToken: string;
        user: {
            id: string;
            email: string;
            phone: string;
            fullName: string;
            role: UserRole;
            avatarUrl: string;
            coverUrl: string;
            birthDate: string | null;
            gender: Gender;
            managedShopId: string | null;
            workingShopId: string | null;
            barberId: string | null;
        };
    }>;
    requestForgotPasswordOtp(emailInput: string): Promise<{
        message: string;
    }>;
    resetPassword(dto: ResetPasswordDto): Promise<{
        message: string;
    }>;
    updateProfile(userId: string, dto: UpdateProfileDto): Promise<{
        id: string;
        email: string;
        phone: string;
        fullName: string;
        role: UserRole;
        avatarUrl: string;
        coverUrl: string;
        birthDate: string | null;
        gender: Gender;
        managedShopId: string | null;
        workingShopId: string | null;
        barberId: string | null;
    }>;
}
export declare class AuthController {
    private readonly authService;
    constructor(authService: AuthService);
    requestRegisterOtp(dto: RegisterRequestOtpDto): Promise<{
        message: string;
        email: string;
    }>;
    verifyRegisterOtp(dto: VerifyOtpDto): Promise<{
        accessToken: string;
        user: {
            id: string;
            email: string;
            phone: string;
            fullName: string;
            role: UserRole;
            avatarUrl: string;
            coverUrl: string;
            birthDate: string | null;
            gender: Gender;
            managedShopId: string | null;
            workingShopId: string | null;
            barberId: string | null;
        };
    }>;
    login(dto: LoginDto): Promise<{
        accessToken: string;
        user: {
            id: string;
            email: string;
            phone: string;
            fullName: string;
            role: UserRole;
            avatarUrl: string;
            coverUrl: string;
            birthDate: string | null;
            gender: Gender;
            managedShopId: string | null;
            workingShopId: string | null;
            barberId: string | null;
        };
    }>;
    requestResetOtp(body: {
        email: string;
    }): Promise<{
        message: string;
    }>;
    resetPassword(dto: ResetPasswordDto): Promise<{
        message: string;
    }>;
    getMe(user: UserEntity): Promise<{
        id: string;
        email: string;
        phone: string;
        fullName: string;
        role: UserRole;
        avatarUrl: string;
        coverUrl: string;
        birthDate: string | null;
        gender: Gender;
        managedShopId: string | null;
        workingShopId: string | null;
        barberId: string | null;
    }>;
    updateProfile(user: UserEntity, dto: UpdateProfileDto): Promise<{
        id: string;
        email: string;
        phone: string;
        fullName: string;
        role: UserRole;
        avatarUrl: string;
        coverUrl: string;
        birthDate: string | null;
        gender: Gender;
        managedShopId: string | null;
        workingShopId: string | null;
        barberId: string | null;
    }>;
}
export declare class AuthModule {
}
export {};
