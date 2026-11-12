import { UserEntity } from './user.entity';
export declare class FcmTokenEntity {
    id: string;
    userId: string;
    user: UserEntity;
    token: string;
    platform: string;
    updatedAt: Date;
}
