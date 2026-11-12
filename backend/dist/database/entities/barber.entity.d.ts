import { UserEntity } from './user.entity';
import { ShopEntity } from './shop.entity';
export declare class BarberEntity {
    id: string;
    userId: string;
    user: UserEntity;
    shopId: string;
    shop: ShopEntity;
    baseSalary: number;
    isActive: boolean;
    bio: string;
    rating: number;
    joinedAt: Date;
    createdAt: Date;
}
