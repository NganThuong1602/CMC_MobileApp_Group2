import { Repository } from 'typeorm';
import { DiscountCodeEntity, UserEntity } from '../../database/entities';
export declare class DiscountsService {
    private readonly discountRepo;
    constructor(discountRepo: Repository<DiscountCodeEntity>);
    findAll(): Promise<DiscountCodeEntity[]>;
    findActiveNow(): Promise<DiscountCodeEntity[]>;
    getBestActiveDiscount(): Promise<DiscountCodeEntity | null>;
    createByAdmin(adminUser: UserEntity, dto: {
        name: string;
        code?: string;
        discountPercent: number;
        startAt: string;
        endAt: string;
    }): Promise<DiscountCodeEntity>;
    deleteByAdmin(adminUser: UserEntity, id: string): Promise<{
        deleted: boolean;
        id: string;
    }>;
}
export declare class DiscountsController {
    private readonly service;
    constructor(service: DiscountsService);
    findAll(): Promise<DiscountCodeEntity[]>;
    findActive(): Promise<DiscountCodeEntity[]>;
    create(user: UserEntity, dto: {
        name: string;
        code?: string;
        discountPercent: number;
        startAt: string;
        endAt: string;
    }): Promise<DiscountCodeEntity>;
    remove(user: UserEntity, id: string): Promise<{
        deleted: boolean;
        id: string;
    }>;
}
export declare class DiscountsModule {
}
