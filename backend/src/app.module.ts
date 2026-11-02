import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import {
  BarberEntity,
  BookingEntity,
  ChatMessageEntity,
  ChatRoomEntity,
  FcmTokenEntity,
  NotificationEntity,
  OtpVerificationEntity,
  PostCommentEntity,
  PostEntity,
  ReviewEntity,
  ServiceEntity,
  ShopEntity,
  TransactionEntity,
  UserEntity,
} from './database/entities';
import { DatabaseSeederModule } from './database/seeder.module';
import { AuthModule } from './modules/auth/auth.module';
import { BarbersModule } from './modules/barbers/barbers.module';
import { BookingsModule } from './modules/bookings/bookings.module';
import { CommunityModule } from './modules/community/community.module';
import { MailerModule } from './modules/mailer/mailer.module';
import { NotificationsModule } from './modules/notifications/notifications.module';
import { PaymentsModule } from './modules/payments/payments.module';
import { RealtimeModule } from './modules/realtime/realtime.module';
import { ShopsModule } from './modules/shops/shops.module';
import { UploadModule } from './modules/upload/upload.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: ['.env', 'backend/.env'],
    }),
    TypeOrmModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        type: 'postgres',
        url: config.get<string>('DATABASE_URL'),
        entities: [
          UserEntity,
          OtpVerificationEntity,
          FcmTokenEntity,
          ShopEntity,
          BarberEntity,
          ServiceEntity,
          BookingEntity,
          TransactionEntity,
          PostEntity,
          PostCommentEntity,
          ReviewEntity,
          ChatRoomEntity,
          ChatMessageEntity,
          NotificationEntity,
        ],
        synchronize: config.get<string>('DB_SYNCHRONIZE', 'true') === 'true',
        ssl:
          config.get<string>('DB_SSL', 'true') === 'true'
            ? { rejectUnauthorized: false }
            : false,
      }),
    }),
    MailerModule,
    UploadModule,
    RealtimeModule,
    NotificationsModule,
    AuthModule,
    ShopsModule,
    BarbersModule,
    BookingsModule,
    PaymentsModule,
    CommunityModule,
    DatabaseSeederModule,
  ],
})
export class AppModule {}

