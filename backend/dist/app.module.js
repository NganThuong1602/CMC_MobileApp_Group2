"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.AppModule = void 0;
const common_1 = require("@nestjs/common");
const config_1 = require("@nestjs/config");
const typeorm_1 = require("@nestjs/typeorm");
const entities_1 = require("./database/entities");
const seeder_module_1 = require("./database/seeder.module");
const auth_module_1 = require("./modules/auth/auth.module");
const barbers_module_1 = require("./modules/barbers/barbers.module");
const bookings_module_1 = require("./modules/bookings/bookings.module");
const community_module_1 = require("./modules/community/community.module");
const discounts_module_1 = require("./modules/discounts/discounts.module");
const mailer_module_1 = require("./modules/mailer/mailer.module");
const notifications_module_1 = require("./modules/notifications/notifications.module");
const payments_module_1 = require("./modules/payments/payments.module");
const realtime_module_1 = require("./modules/realtime/realtime.module");
const shops_module_1 = require("./modules/shops/shops.module");
const upload_module_1 = require("./modules/upload/upload.module");
let AppModule = class AppModule {
};
exports.AppModule = AppModule;
exports.AppModule = AppModule = __decorate([
    (0, common_1.Module)({
        imports: [
            config_1.ConfigModule.forRoot({
                isGlobal: true,
                envFilePath: ['.env', 'backend/.env'],
            }),
            typeorm_1.TypeOrmModule.forRootAsync({
                imports: [config_1.ConfigModule],
                inject: [config_1.ConfigService],
                useFactory: (config) => ({
                    type: 'postgres',
                    url: config.get('DATABASE_URL'),
                    entities: [
                        entities_1.UserEntity,
                        entities_1.OtpVerificationEntity,
                        entities_1.FcmTokenEntity,
                        entities_1.ShopEntity,
                        entities_1.BarberEntity,
                        entities_1.ServiceEntity,
                        entities_1.BookingEntity,
                        entities_1.TransactionEntity,
                        entities_1.PostEntity,
                        entities_1.PostCommentEntity,
                        entities_1.ReviewEntity,
                        entities_1.ChatRoomEntity,
                        entities_1.ChatMessageEntity,
                        entities_1.NotificationEntity,
                        entities_1.DiscountCodeEntity,
                    ],
                    synchronize: config.get('DB_SYNCHRONIZE', 'true') === 'true',
                    ssl: config.get('DB_SSL', 'true') === 'true'
                        ? { rejectUnauthorized: false }
                        : false,
                }),
            }),
            mailer_module_1.MailerModule,
            upload_module_1.UploadModule,
            realtime_module_1.RealtimeModule,
            notifications_module_1.NotificationsModule,
            auth_module_1.AuthModule,
            shops_module_1.ShopsModule,
            discounts_module_1.DiscountsModule,
            barbers_module_1.BarbersModule,
            bookings_module_1.BookingsModule,
            payments_module_1.PaymentsModule,
            community_module_1.CommunityModule,
            seeder_module_1.DatabaseSeederModule,
        ],
    })
], AppModule);
//# sourceMappingURL=app.module.js.map