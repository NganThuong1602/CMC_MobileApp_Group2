import { OnModuleInit } from '@nestjs/common';
import { Repository } from 'typeorm';
import { BarberEntity, PostEntity, ReviewEntity, ServiceEntity, ShopEntity, TransactionEntity, UserEntity } from './entities';
export declare class DatabaseSeederService implements OnModuleInit {
    private readonly userRepo;
    private readonly shopRepo;
    private readonly barberRepo;
    private readonly serviceRepo;
    private readonly txRepo;
    private readonly reviewRepo;
    private readonly postRepo;
    private readonly logger;
    constructor(userRepo: Repository<UserEntity>, shopRepo: Repository<ShopEntity>, barberRepo: Repository<BarberEntity>, serviceRepo: Repository<ServiceEntity>, txRepo: Repository<TransactionEntity>, reviewRepo: Repository<ReviewEntity>, postRepo: Repository<PostEntity>);
    onModuleInit(): Promise<void>;
    private upsertUser;
    seedAll(): Promise<void>;
}
export declare class DatabaseSeederModule {
}
