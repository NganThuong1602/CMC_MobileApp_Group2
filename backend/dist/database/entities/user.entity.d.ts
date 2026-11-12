import { Gender, UserRole } from './enums';
import { ShopEntity } from './shop.entity';
import { BarberEntity } from './barber.entity';
import { FcmTokenEntity } from './fcm-token.entity';
export declare class UserEntity {
    id: string;
    email: string;
    phone: string;
    passwordHash: string;
    fullName: string;
    role: UserRole;
    avatarUrl?: string;
    coverUrl?: string;
    birthDate?: string;
    gender: Gender;
    managedShop?: ShopEntity;
    barberProfile?: BarberEntity;
    fcmTokens?: FcmTokenEntity[];
    createdAt: Date;
    updatedAt: Date;
}
