"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
var NotificationsService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.NotificationsModule = exports.NotificationsController = exports.NotificationsService = void 0;
const common_1 = require("@nestjs/common");
const config_1 = require("@nestjs/config");
const typeorm_1 = require("@nestjs/typeorm");
const admin = require("firebase-admin");
const typeorm_2 = require("typeorm");
const auth_guards_1 = require("../../common/auth.guards");
const entities_1 = require("../../database/entities");
let NotificationsService = NotificationsService_1 = class NotificationsService {
    constructor(config, notiRepo, tokenRepo) {
        this.config = config;
        this.notiRepo = notiRepo;
        this.tokenRepo = tokenRepo;
        this.logger = new common_1.Logger(NotificationsService_1.name);
        this.fcmReady = false;
        const projectId = this.config.get('FIREBASE_PROJECT_ID');
        const clientEmail = this.config.get('FIREBASE_CLIENT_EMAIL');
        const privateKey = this.config
            .get('FIREBASE_PRIVATE_KEY')
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
    async registerFcmToken(userId, token, platform = 'android') {
        const existing = await this.tokenRepo.findOne({ where: { token } });
        if (existing) {
            existing.userId = userId;
            existing.platform = platform;
            return this.tokenRepo.save(existing);
        }
        return this.tokenRepo.save(this.tokenRepo.create({ userId, token, platform }));
    }
    async createAndPush(params) {
        const saved = await this.notiRepo.save(this.notiRepo.create({
            recipientId: params.recipientId,
            title: params.title,
            body: params.body,
            type: params.type ?? entities_1.NotificationType.SYSTEM,
            metadata: params.metadata,
        }));
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
                }
                catch (err) {
                    this.logger.warn(`FCM push error: ${err}`);
                }
            }
        }
        return saved;
    }
    async getMyNotifications(userId) {
        const items = await this.notiRepo.find({
            where: { recipientId: userId },
            order: { createdAt: 'DESC' },
        });
        const unreadCount = items.filter((i) => !i.isRead).length;
        return { unreadCount, items };
    }
    async markAllRead(userId) {
        await this.notiRepo.update({ recipientId: userId, isRead: false }, { isRead: true });
        return { success: true };
    }
    async markOneRead(userId, notifId) {
        await this.notiRepo.update({ id: notifId, recipientId: userId }, { isRead: true });
        return { success: true };
    }
};
exports.NotificationsService = NotificationsService;
exports.NotificationsService = NotificationsService = NotificationsService_1 = __decorate([
    (0, common_1.Injectable)(),
    __param(1, (0, typeorm_1.InjectRepository)(entities_1.NotificationEntity)),
    __param(2, (0, typeorm_1.InjectRepository)(entities_1.FcmTokenEntity)),
    __metadata("design:paramtypes", [config_1.ConfigService,
        typeorm_2.Repository,
        typeorm_2.Repository])
], NotificationsService);
let NotificationsController = class NotificationsController {
    constructor(service) {
        this.service = service;
    }
    getMine(user) {
        return this.service.getMyNotifications(user.id);
    }
    markAllRead(user) {
        return this.service.markAllRead(user.id);
    }
    markOneRead(user, id) {
        return this.service.markOneRead(user.id, id);
    }
    saveToken(user, body) {
        return this.service.registerFcmToken(user.id, body.token, body.platform);
    }
};
exports.NotificationsController = NotificationsController;
__decorate([
    (0, common_1.Get)(),
    __param(0, (0, auth_guards_1.CurrentUser)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", void 0)
], NotificationsController.prototype, "getMine", null);
__decorate([
    (0, common_1.Patch)('read-all'),
    __param(0, (0, auth_guards_1.CurrentUser)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", void 0)
], NotificationsController.prototype, "markAllRead", null);
__decorate([
    (0, common_1.Patch)(':id/read'),
    __param(0, (0, auth_guards_1.CurrentUser)()),
    __param(1, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", void 0)
], NotificationsController.prototype, "markOneRead", null);
__decorate([
    (0, common_1.Post)('fcm-token'),
    __param(0, (0, auth_guards_1.CurrentUser)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, Object]),
    __metadata("design:returntype", void 0)
], NotificationsController.prototype, "saveToken", null);
exports.NotificationsController = NotificationsController = __decorate([
    (0, common_1.Controller)('notifications'),
    (0, common_1.UseGuards)(auth_guards_1.JwtAuthGuard),
    __metadata("design:paramtypes", [NotificationsService])
], NotificationsController);
let NotificationsModule = class NotificationsModule {
};
exports.NotificationsModule = NotificationsModule;
exports.NotificationsModule = NotificationsModule = __decorate([
    (0, common_1.Global)(),
    (0, common_1.Module)({
        imports: [typeorm_1.TypeOrmModule.forFeature([entities_1.NotificationEntity, entities_1.FcmTokenEntity])],
        controllers: [NotificationsController],
        providers: [NotificationsService],
        exports: [NotificationsService],
    })
], NotificationsModule);
//# sourceMappingURL=notifications.module.js.map