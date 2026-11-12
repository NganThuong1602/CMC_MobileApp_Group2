import { ShopEntity } from './shop.entity';
export declare class ServiceEntity {
    id: string;
    shopId: string;
    shop: ShopEntity;
    name: string;
    price: number;
    durationMinutes: number;
    description: string;
    isActive: boolean;
}
