import {
  Body,
  Controller,
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
import { Repository } from 'typeorm';
import { CurrentUser, JwtAuthGuard } from '../../common/auth.guards';
import {
  FcmTokenEntity,
  NotificationEntity,
  NotificationType,
} from '../../database/entities';

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

    if (projectId && clientEmail && privateKey && !projectId.includes('your_')) {
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
    }
  }

  async registerFcmToken(userId: string, token: string, platform = 'android') {
    const existing = await this.tokenRepo.findOne({ where: { token } });
    if (existing) {
      existing.userId = userId;
      existing.platform = platform;
      return this.tokenRepo.save(existing);
    }
    return this.tokenRepo.save(
      this.tokenRepo.create({ userId, token, platform }),
    );
  }

  async createAndPush(params: {
    recipientId: string;
    title: string;
    body: string;
    type?: NotificationType;
    metadata?: Record<string, any>;
  }) {
    const saved = await this.notiRepo.save(
      this.notiRepo.create({
        recipientId: params.recipientId,
        title: params.title,
        body: params.body,
        type: params.type ?? NotificationType.SYSTEM,
        metadata: params.metadata,
      }),
    );

    if (this.fcmReady) {
      const tokens = await this.tokenRepo.find({
        where: { userId: params.recipientId },
      });
      if (tokens.length > 0) {
        try {
          await admin.messaging().sendEachForMulticast({
            tokens: tokens.map((t) => t.token),
            notification: { title: params.title, body: params.body },
          });
        } catch (err) {
          this.logger.warn(`FCM push error: ${err}`);
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
}

@Global()
@Module({
  imports: [TypeOrmModule.forFeature([NotificationEntity, FcmTokenEntity])],
  controllers: [NotificationsController],
  providers: [NotificationsService],
  exports: [NotificationsService],
})
export class NotificationsModule {}
