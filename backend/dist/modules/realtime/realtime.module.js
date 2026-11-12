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
var RealtimeGateway_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.RealtimeModule = exports.RealtimeGateway = void 0;
const common_1 = require("@nestjs/common");
const websockets_1 = require("@nestjs/websockets");
const typeorm_1 = require("@nestjs/typeorm");
const socket_io_1 = require("socket.io");
const typeorm_2 = require("typeorm");
const entities_1 = require("../../database/entities");
const notifications_module_1 = require("../notifications/notifications.module");
let RealtimeGateway = RealtimeGateway_1 = class RealtimeGateway {
    constructor(roomRepo, msgRepo, userRepo, notificationsService) {
        this.roomRepo = roomRepo;
        this.msgRepo = msgRepo;
        this.userRepo = userRepo;
        this.notificationsService = notificationsService;
        this.logger = new common_1.Logger(RealtimeGateway_1.name);
    }
    handleConnection(client) {
        const userId = client.handshake.query.userId;
        if (userId) {
            client.join(`user:${userId}`);
            this.logger.log(`Socket connected: ${client.id} -> joined user:${userId}`);
        }
    }
    handleDisconnect(client) {
        this.logger.log(`Socket disconnected: ${client.id}`);
    }
    emitPaymentSuccess(userId, payload) {
        this.server.to(`user:${userId}`).emit('payment.success', payload);
    }
    emitUserRoleUpdated(userId, payload) {
        this.server.to(`user:${userId}`).emit('user.role_updated', payload);
    }
    emitChatRoomMessage(roomId, payload) {
        this.server.to(`chat:${roomId}`).emit('chat.new_message', payload);
    }
    handleJoinRoom(client, data) {
        client.join(`chat:${data.roomId}`);
        return { joined: data.roomId };
    }
    async handleSendMessage(data) {
        if (!data.content?.trim())
            return;
        const sender = await this.userRepo.findOne({
            where: { id: data.senderId },
        });
        if (!sender)
            return;
        const room = await this.roomRepo.findOne({
            where: { id: data.roomId },
            relations: ['shop', 'customer'],
        });
        if (!room)
            return;
        const cleanContent = data.content.trim();
        const saved = await this.msgRepo.save(this.msgRepo.create({
            roomId: data.roomId,
            senderId: data.senderId,
            content: cleanContent,
        }));
        await this.roomRepo.update(data.roomId, {
            lastMessage: cleanContent,
        });
        if (room.shop && sender.id !== room.shop.ownerId) {
            await this.notificationsService.createAndPush({
                recipientId: room.shop.ownerId,
                title: `Tin nhắn mới từ khách hàng ${sender.fullName}`,
                body: cleanContent,
                type: entities_1.NotificationType.CHAT_MESSAGE,
                metadata: { roomId: room.id, shopId: room.shopId },
            });
        }
        else if (room.customerId && sender.id !== room.customerId) {
            await this.notificationsService.createAndPush({
                recipientId: room.customerId,
                title: `Phản hồi từ quán ${room.shop?.name ?? 'BarberSmart'}`,
                body: cleanContent,
                type: entities_1.NotificationType.CHAT_MESSAGE,
                metadata: { roomId: room.id, shopId: room.shopId },
            });
        }
        const payload = {
            id: saved.id,
            roomId: saved.roomId,
            senderId: sender.id,
            senderName: sender.fullName,
            senderAvatar: sender.avatarUrl ?? '',
            senderRole: sender.role,
            content: saved.content,
            createdAt: saved.createdAt,
        };
        this.server.to(`chat:${data.roomId}`).emit('chat.new_message', payload);
        return payload;
    }
};
exports.RealtimeGateway = RealtimeGateway;
__decorate([
    (0, websockets_1.WebSocketServer)(),
    __metadata("design:type", socket_io_1.Server)
], RealtimeGateway.prototype, "server", void 0);
__decorate([
    (0, websockets_1.SubscribeMessage)('chat.join_room'),
    __param(0, (0, websockets_1.ConnectedSocket)()),
    __param(1, (0, websockets_1.MessageBody)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [socket_io_1.Socket, Object]),
    __metadata("design:returntype", void 0)
], RealtimeGateway.prototype, "handleJoinRoom", null);
__decorate([
    (0, websockets_1.SubscribeMessage)('chat.send_message'),
    __param(0, (0, websockets_1.MessageBody)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], RealtimeGateway.prototype, "handleSendMessage", null);
exports.RealtimeGateway = RealtimeGateway = RealtimeGateway_1 = __decorate([
    (0, websockets_1.WebSocketGateway)({
        cors: { origin: '*' },
        namespace: '/realtime',
    }),
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(entities_1.ChatRoomEntity)),
    __param(1, (0, typeorm_1.InjectRepository)(entities_1.ChatMessageEntity)),
    __param(2, (0, typeorm_1.InjectRepository)(entities_1.UserEntity)),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        notifications_module_1.NotificationsService])
], RealtimeGateway);
let RealtimeModule = class RealtimeModule {
};
exports.RealtimeModule = RealtimeModule;
exports.RealtimeModule = RealtimeModule = __decorate([
    (0, common_1.Global)(),
    (0, common_1.Module)({
        imports: [
            typeorm_1.TypeOrmModule.forFeature([entities_1.ChatRoomEntity, entities_1.ChatMessageEntity, entities_1.UserEntity]),
        ],
        providers: [RealtimeGateway],
        exports: [RealtimeGateway],
    })
], RealtimeModule);
//# sourceMappingURL=realtime.module.js.map