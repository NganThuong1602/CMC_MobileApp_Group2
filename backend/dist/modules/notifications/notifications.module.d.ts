import { ConfigService } from '@nestjs/config';
import { Repository } from 'typeorm';
import { FcmTokenEntity, NotificationEntity, NotificationType } from '../../database/entities';
export declare class NotificationsService {
    private readonly config;
    private readonly notiRepo;
    private readonly tokenRepo;
    private readonly logger;
    private fcmReady;
    constructor(config: ConfigService, notiRepo: Repository<NotificationEntity>, tokenRepo: Repository<FcmTokenEntity>);
    registerFcmToken(userId: string, token: string, platform?: string): Promise<FcmTokenEntity>;
    createAndPush(params: {
        recipientId: string;
        title: string;
        body: string;
        type?: NotificationType;
        metadata?: Record<string, any>;
    }): Promise<NotificationEntity>;
    getMyNotifications(userId: string): Promise<{
        unreadCount: number;
        items: NotificationEntity[];
    }>;
    markAllRead(userId: string): Promise<{
        success: boolean;
    }>;
    markOneRead(userId: string, notifId: string): Promise<{
        success: boolean;
    }>;
}
export declare class NotificationsController {
    private readonly service;
    constructor(service: NotificationsService);
    getMine(user: {
        id: string;
    }): Promise<{
        unreadCount: number;
        items: NotificationEntity[];
    }>;
    markAllRead(user: {
        id: string;
    }): Promise<{
        success: boolean;
    }>;
    markOneRead(user: {
        id: string;
    }, id: string): Promise<{
        success: boolean;
    }>;
    saveToken(user: {
        id: string;
    }, body: {
        token: string;
        platform?: string;
    }): Promise<FcmTokenEntity>;
}
export declare class NotificationsModule {
}
