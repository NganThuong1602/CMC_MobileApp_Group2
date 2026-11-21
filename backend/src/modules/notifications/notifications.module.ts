import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  Global,
  Injectable,
  Logger,
  Module,
  Param,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectRepository, TypeOrmModule } from '@nestjs/typeorm';
import * as admin from 'firebase-admin';
import { In, Repository } from 'typeorm';
import { CurrentUser, JwtAuthGuard } from '../../common/auth.guards';
import {
  FcmTokenEntity,
  NotificationEntity,
  NotificationType,
} from '../../database/entities';

const INVALID_FCM_ERROR_CODES = new Set<string>([
  'messaging/invalid-registration-token',
  'messaging/registration-token-not-registered',
  'messaging/invalid-argument',
  'messaging/unregistered',
]);

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);
  private fcmReady = false;

  constructor(
    private readonly config: ConfigService,
    @InjectRepository(NotificationEntity)
    private readonly notiRepo: Repository<NotificationEntity>,
    @InjectRepository(FcmTokenEntity)
    private readonly tokenRepo: Repository<FcmTokenEntity>,
  ) {
    const projectId = this.config.get<string>('FIREBASE_PROJECT_ID');
    const clientEmail = this.config.get<string>('FIREBASE_CLIENT_EMAIL');
    const privateKey = this.config
      .get<string>('FIREBASE_PRIVATE_KEY')
      ?.replace(/\\n/g, '\n');

    if (
      projectId &&
      clientEmail &&
      privateKey &&
      !projectId.includes('your_') &&
      !privateKey.includes('YOUR_PRIVATE_KEY')
    ) {
      try {
        if (admin.apps.length === 0) {
          admin.initializeApp({
            credential: admin.credential.cert({
              projectId,
              clientEmail,
              privateKey,
            }),
          });
        }
        this.fcmReady = true;
      } catch (err) {
        this.logger.warn(
          `Firebase Admin init skipped (${err instanceof Error ? err.message : 'invalid config'})`,
        );
      }
    }
  }

  async registerFcmToken(userId: string, token: string, platform = 'android') {
    const cleanToken = (token ?? '').trim();
    if (!cleanToken) {
      throw new BadRequestException('FCM token không hợp lệ');
    }
    const cleanPlatform = (platform ?? 'android').trim().toLowerCase() || 'android';

    const existing = await this.tokenRepo.findOne({
      where: { token: cleanToken },
    });
    if (existing) {
      existing.userId = userId;
      existing.platform = cleanPlatform;
      const saved = await this.tokenRepo.save(existing);
      this.logger.debug(
        `Updated FCM token ownership for user=${userId} platform=${cleanPlatform}`,
      );
      return { id: saved.id, userId: saved.userId, platform: saved.platform };
    }
    const saved = await this.tokenRepo.save(
      this.tokenRepo.create({
        userId,
        token: cleanToken,
        platform: cleanPlatform,
      }),
    );
    this.logger.debug(
      `Registered new FCM token for user=${userId} platform=${cleanPlatform}`,
    );
    return { id: saved.id, userId: saved.userId, platform: saved.platform };
  }

  async unregisterFcmToken(userId: string, token?: string) {
    const cleanToken = (token ?? '').trim();
    if (cleanToken) {
      await this.tokenRepo.delete({ userId, token: cleanToken });
    } else {
      await this.tokenRepo.delete({ userId });
    }
    this.logger.debug(`Removed FCM token(s) on logout for user=${userId}`);
    return { success: true };
  }

  private buildStringDataPayload(
    notificationId: string,
    type: NotificationType,
    metadata?: Record<string, any>,
  ): Record<string, string> {
    const data: Record<string, string> = {
      notificationId: String(notificationId),
      type: String(type),
    };
    if (!metadata) return data;
    for (const key of ['shopId', 'roomId', 'bookingId', 'barberId', 'approved']) {
      if (metadata[key] !== undefined && metadata[key] !== null) {
        data[key] = String(metadata[key]);
      }
    }
    return data;
  }

  async createAndPush(params: {
    recipientId: string;
    title: string;
    body: string;
    type?: NotificationType;
    metadata?: Record<string, any>;
  }) {
    const resolvedType = params.type ?? NotificationType.SYSTEM;
    const saved = await this.notiRepo.save(
      this.notiRepo.create({
        recipientId: params.recipientId,
        title: params.title,
        body: params.body,
        type: resolvedType,
        metadata: params.metadata,
      }),
    );

    if (this.fcmReady) {
      const tokenEntities = await this.tokenRepo.find({
        where: { userId: params.recipientId },
      });
      // Khử trùng lặp token trên cùng user (nếu có)
      const uniqueTokenEntities: FcmTokenEntity[] = [];
      const seenTokens = new Set<string>();
      for (const item of tokenEntities) {
        const t = (item.token ?? '').trim();
        if (!t || seenTokens.has(t)) continue;
        seenTokens.add(t);
        uniqueTokenEntities.push(item);
      }

      if (uniqueTokenEntities.length > 0) {
        try {
          const dataPayload = this.buildStringDataPayload(
            saved.id,
            resolvedType,
            params.metadata,
          );
          const batchResponse = await admin.messaging().sendEachForMulticast({
            tokens: uniqueTokenEntities.map((t) => t.token),
            notification: {
              title: params.title,
              body: params.body,
            },
            data: dataPayload,
            android: {
              priority: 'high',
              notification: {
                channelId: 'barbersmart_notifications',
                icon: 'ic_launcher',
                sound: 'default',
                defaultSound: true,
              },
            },
            webpush: {
              notification: {
                title: params.title,
                body: params.body,
                icon: '/icons/Icon-192.png',
              },
              fcmOptions: {
                link: '/#/notifications',
              },
            },
          });

          const invalidTokenIds: string[] = [];
          batchResponse.responses.forEach((resp, idx) => {
            if (!resp.success) {
              const code = resp.error?.code ?? 'unknown';
              if (INVALID_FCM_ERROR_CODES.has(code)) {
                invalidTokenIds.push(uniqueTokenEntities[idx].id);
              }
            }
          });

          if (invalidTokenIds.length > 0) {
            await this.tokenRepo.delete({ id: In(invalidTokenIds) });
          }

          if (batchResponse.failureCount > 0) {
            this.logger.debug(
              `FCM multicast recipient=${params.recipientId} type=${resolvedType}: ${batchResponse.successCount} sent, ${batchResponse.failureCount} failed (${invalidTokenIds.length} expired/invalid tokens pruned)`,
            );
          }
        } catch (err) {
          this.logger.warn(
            `FCM push error for recipient=${params.recipientId}: ${err instanceof Error ? err.message : 'send failed'}`,
          );
        }
      }
    }

    return saved;
  }

  async getMyNotifications(userId: string) {
    const items = await this.notiRepo.find({
      where: { recipientId: userId },
      order: { createdAt: 'DESC' },
    });
    const unreadCount = items.filter((i) => !i.isRead).length;
    return { unreadCount, items };
  }

  async markAllRead(userId: string) {
    await this.notiRepo.update(
      { recipientId: userId, isRead: false },
      { isRead: true },
    );
    return { success: true };
  }

  async markOneRead(userId: string, notifId: string) {
    await this.notiRepo.update(
      { id: notifId, recipientId: userId },
      { isRead: true },
    );
    return { success: true };
  }
}

@Controller('notifications')
@UseGuards(JwtAuthGuard)
export class NotificationsController {
  constructor(private readonly service: NotificationsService) {}

  @Get()
  getMine(@CurrentUser() user: { id: string }) {
    return this.service.getMyNotifications(user.id);
  }

  @Patch('read-all')
  markAllRead(@CurrentUser() user: { id: string }) {
    return this.service.markAllRead(user.id);
  }

  @Patch(':id/read')
  markOneRead(
    @CurrentUser() user: { id: string },
    @Param('id') id: string,
  ) {
    return this.service.markOneRead(user.id, id);
  }

  @Post('fcm-token')
  saveToken(
    @CurrentUser() user: { id: string },
    @Body() body: { token: string; platform?: string },
  ) {
    return this.service.registerFcmToken(user.id, body.token, body.platform);
  }

  @Delete('fcm-token')
  removeToken(
    @CurrentUser() user: { id: string },
    @Body() body?: { token?: string },
  ) {
    return this.service.unregisterFcmToken(user.id, body?.token);
  }
}

@Global()
@Module({
  imports: [TypeOrmModule.forFeature([NotificationEntity, FcmTokenEntity])],
  controllers: [NotificationsController],
  providers: [NotificationsService],
  exports: [NotificationsService],
})
export class NotificationsModule {}
