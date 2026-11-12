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
Object.defineProperty(exports, "__esModule", { value: true });
exports.CommunityModule = exports.CommunityController = exports.CommunityService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const auth_guards_1 = require("../../common/auth.guards");
const entities_1 = require("../../database/entities");
const notifications_module_1 = require("../notifications/notifications.module");
const realtime_module_1 = require("../realtime/realtime.module");
let CommunityService = class CommunityService {
    constructor(postRepo, commentRepo, reviewRepo, shopRepo, roomRepo, msgRepo, barberRepo, userRepo, notificationsService, realtimeGateway) {
        this.postRepo = postRepo;
        this.commentRepo = commentRepo;
        this.reviewRepo = reviewRepo;
        this.shopRepo = shopRepo;
        this.roomRepo = roomRepo;
        this.msgRepo = msgRepo;
        this.barberRepo = barberRepo;
        this.userRepo = userRepo;
        this.notificationsService = notificationsService;
        this.realtimeGateway = realtimeGateway;
    }
    async getPublicUserProfile(userId) {
        const user = await this.userRepo.findOne({ where: { id: userId } });
        if (!user) {
            throw new common_1.NotFoundException('Không tìm thấy trang cá nhân người dùng');
        }
        return {
            id: user.id,
            email: user.email,
            phone: user.phone,
            fullName: user.fullName,
            role: user.role,
            gender: user.gender,
            birthDate: user.birthDate,
            avatarUrl: user.avatarUrl && user.avatarUrl.trim().length > 0
                ? user.avatarUrl
                : entities_1.DEFAULT_AVATAR_URL,
            coverUrl: user.coverUrl ?? '',
        };
    }
    async getAllFeedPosts() {
        return this.postRepo.find({
            relations: ['author', 'comments', 'comments.author'],
            order: { createdAt: 'DESC' },
            take: 40,
        });
    }
    async getForumPosts() {
        const [barbers, shops, managers] = await Promise.all([
            this.barberRepo.find({
                where: { isActive: true },
                relations: ['shop', 'user'],
            }),
            this.shopRepo.find({
                order: { isActive: 'DESC', createdAt: 'DESC' },
            }),
            this.userRepo.find({
                where: { role: entities_1.UserRole.MANAGER },
            }),
        ]);
        const barberByUserId = new Map();
        for (const b of barbers) {
            if (b.user?.role === entities_1.UserRole.BARBER) {
                barberByUserId.set(b.userId, b);
            }
        }
        const shopByOwnerId = new Map();
        for (const shop of shops) {
            if (!shopByOwnerId.has(shop.ownerId)) {
                shopByOwnerId.set(shop.ownerId, shop);
            }
        }
        const eligibleAuthorIds = Array.from(new Set([
            ...barberByUserId.keys(),
            ...managers.map((m) => m.id),
        ]));
        if (eligibleAuthorIds.length === 0)
            return [];
        const posts = await this.postRepo.find({
            where: { authorId: (0, typeorm_2.In)(eligibleAuthorIds) },
            relations: ['author', 'comments', 'comments.author'],
            order: { createdAt: 'DESC' },
            take: 100,
        });
        return posts
            .filter((post) => {
            if (post.author?.role === entities_1.UserRole.MANAGER) {
                return true;
            }
            const barber = barberByUserId.get(post.authorId);
            if (!barber)
                return false;
            const since = barber.joinedAt ?? barber.createdAt;
            return new Date(post.createdAt).getTime() >= new Date(since).getTime();
        })
            .slice(0, 60)
            .map((post) => {
            if (post.author?.role === entities_1.UserRole.MANAGER) {
                const ownedShop = shopByOwnerId.get(post.authorId);
                return {
                    ...post,
                    authorShopId: ownedShop?.id ?? null,
                    authorShopName: ownedShop?.name ?? '',
                };
            }
            const barber = barberByUserId.get(post.authorId);
            return {
                ...post,
                authorShopId: barber?.shopId ?? null,
                authorShopName: barber?.shop?.name ?? '',
            };
        });
    }
    async getUserPosts(userId) {
        return this.postRepo.find({
            where: { authorId: userId },
            relations: ['author', 'comments', 'comments.author'],
            order: { createdAt: 'DESC' },
        });
    }
    async createPost(authorId, dto) {
        const images = (dto.imageUrls ?? [])
            .map((u) => u.trim())
            .filter((u) => u.length > 0);
        if (images.length > 5) {
            throw new common_1.BadRequestException('Bài viết chỉ được đính kèm tối đa 5 ảnh');
        }
        const caption = (dto.caption ?? '').trim();
        if (!caption && images.length === 0) {
            throw new common_1.BadRequestException('Vui lòng nhập nội dung hoặc đính kèm ít nhất 1 ảnh');
        }
        const saved = await this.postRepo.save(this.postRepo.create({
            authorId,
            caption,
            imageUrls: images,
        }));
        return this.postRepo.findOneOrFail({
            where: { id: saved.id },
            relations: ['author', 'comments', 'comments.author'],
        });
    }
    async updatePost(postId, userId, dto) {
        const post = await this.postRepo.findOne({ where: { id: postId } });
        if (!post) {
            throw new common_1.NotFoundException('Không tìm thấy bài viết');
        }
        if (post.authorId !== userId) {
            throw new common_1.ForbiddenException('Bạn chỉ có thể chỉnh sửa bài viết của chính mình');
        }
        const nextCaption = dto.caption !== undefined ? dto.caption.trim() : post.caption;
        const nextImages = dto.imageUrls !== undefined
            ? dto.imageUrls.map((u) => u.trim()).filter((u) => u.length > 0)
            : post.imageUrls;
        if (nextImages.length > 5) {
            throw new common_1.BadRequestException('Bài viết chỉ được đính kèm tối đa 5 ảnh');
        }
        if (!nextCaption && nextImages.length === 0) {
            throw new common_1.BadRequestException('Bài viết cần có nội dung hoặc ít nhất 1 hình ảnh');
        }
        post.caption = nextCaption;
        post.imageUrls = nextImages;
        await this.postRepo.save(post);
        return this.postRepo.findOneOrFail({
            where: { id: post.id },
            relations: ['author', 'comments', 'comments.author'],
        });
    }
    async deletePost(postId, userId) {
        const post = await this.postRepo.findOne({ where: { id: postId } });
        if (!post) {
            throw new common_1.NotFoundException('Không tìm thấy bài viết');
        }
        if (post.authorId !== userId) {
            throw new common_1.ForbiddenException('Bạn chỉ có thể xoá bài viết của chính mình');
        }
        await this.postRepo.delete(post.id);
        return { deleted: true, id: postId };
    }
    async addComment(postId, authorId, content) {
        if (!content?.trim()) {
            throw new common_1.BadRequestException('Nội dung bình luận không được trống');
        }
        const saved = await this.commentRepo.save(this.commentRepo.create({
            postId,
            authorId,
            content: content.trim(),
        }));
        return this.commentRepo.findOneOrFail({
            where: { id: saved.id },
            relations: ['author'],
        });
    }
    async getShopReviews(shopId) {
        return this.reviewRepo.find({
            where: { shopId },
            relations: ['customer'],
            order: { createdAt: 'DESC' },
        });
    }
    async addReview(shopId, customerId, dto) {
        const saved = await this.reviewRepo.save(this.reviewRepo.create({
            shopId,
            customerId,
            rating: Math.min(5, Math.max(1, dto.rating)),
            comment: dto.comment,
        }));
        const allReviews = await this.reviewRepo.find({ where: { shopId } });
        const avg = allReviews.length > 0
            ? allReviews.reduce((s, r) => s + r.rating, 0) / allReviews.length
            : 0;
        await this.shopRepo.update(shopId, {
            rating: Number(avg.toFixed(1)),
            reviewCount: allReviews.length,
        });
        return saved;
    }
    async openOrCreateShopGroupChat(shopId, customerId) {
        let room = await this.roomRepo.findOne({
            where: { shopId, customerId },
            relations: ['shop', 'customer'],
        });
        if (!room) {
            room = await this.roomRepo.save(this.roomRepo.create({
                shopId,
                customerId,
                lastMessage: 'Bắt đầu cuộc trò chuyện với quán',
            }));
            room = await this.roomRepo.findOneOrFail({
                where: { id: room.id },
                relations: ['shop', 'customer'],
            });
        }
        return room;
    }
    async getConsultRoomsForManager(managerUserId) {
        const shop = await this.shopRepo.findOne({
            where: { ownerId: managerUserId },
        });
        if (!shop)
            return [];
        return this.roomRepo.find({
            where: { shopId: shop.id },
            relations: ['customer', 'shop'],
            order: { updatedAt: 'DESC' },
        });
    }
    async getConsultRoomsForBarber(barberUserId) {
        const ownedShop = await this.shopRepo.findOne({
            where: { ownerId: barberUserId },
        });
        if (ownedShop) {
            return this.roomRepo.find({
                where: { shopId: ownedShop.id },
                relations: ['customer', 'shop'],
                order: { updatedAt: 'DESC' },
            });
        }
        const barber = await this.barberRepo.findOne({
            where: { userId: barberUserId },
        });
        if (!barber)
            return [];
        return this.roomRepo.find({
            where: { shopId: barber.shopId },
            relations: ['customer', 'shop'],
            order: { updatedAt: 'DESC' },
        });
    }
    async getRoomMessages(roomId) {
        const list = await this.msgRepo.find({
            where: { roomId },
            relations: ['sender'],
            order: { createdAt: 'ASC' },
        });
        return list.map((m) => ({
            id: m.id,
            roomId: m.roomId,
            senderId: m.senderId,
            senderName: m.sender.fullName,
            senderAvatar: m.sender.avatarUrl ?? '',
            senderRole: m.sender.role,
            content: m.content,
            createdAt: m.createdAt,
        }));
    }
    async sendRoomMessage(roomId, senderId, content) {
        const cleanContent = content?.trim();
        if (!cleanContent) {
            throw new common_1.BadRequestException('Nội dung tin nhắn không được để trống');
        }
        const sender = await this.userRepo.findOne({ where: { id: senderId } });
        if (!sender) {
            throw new common_1.NotFoundException('Không tìm thấy tài khoản gửi tin nhắn');
        }
        const room = await this.roomRepo.findOne({
            where: { id: roomId },
            relations: ['shop', 'customer'],
        });
        if (!room) {
            throw new common_1.NotFoundException('Không tìm thấy phòng trò chuyện');
        }
        const saved = await this.msgRepo.save(this.msgRepo.create({
            roomId,
            senderId,
            content: cleanContent,
        }));
        await this.roomRepo.update(roomId, {
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
        this.realtimeGateway.emitChatRoomMessage(roomId, payload);
        return payload;
    }
};
exports.CommunityService = CommunityService;
exports.CommunityService = CommunityService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(entities_1.PostEntity)),
    __param(1, (0, typeorm_1.InjectRepository)(entities_1.PostCommentEntity)),
    __param(2, (0, typeorm_1.InjectRepository)(entities_1.ReviewEntity)),
    __param(3, (0, typeorm_1.InjectRepository)(entities_1.ShopEntity)),
    __param(4, (0, typeorm_1.InjectRepository)(entities_1.ChatRoomEntity)),
    __param(5, (0, typeorm_1.InjectRepository)(entities_1.ChatMessageEntity)),
    __param(6, (0, typeorm_1.InjectRepository)(entities_1.BarberEntity)),
    __param(7, (0, typeorm_1.InjectRepository)(entities_1.UserEntity)),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        notifications_module_1.NotificationsService,
        realtime_module_1.RealtimeGateway])
], CommunityService);
let CommunityController = class CommunityController {
    constructor(service) {
        this.service = service;
    }
    getPublicUserProfile(userId) {
        return this.service.getPublicUserProfile(userId);
    }
    getAllFeedPosts() {
        return this.service.getAllFeedPosts();
    }
    getForumPosts() {
        return this.service.getForumPosts();
    }
    getUserPosts(userId) {
        return this.service.getUserPosts(userId);
    }
    getShopReviews(shopId) {
        return this.service.getShopReviews(shopId);
    }
    createPost(user, dto) {
        return this.service.createPost(user.id, dto);
    }
    updatePost(postId, user, dto) {
        return this.service.updatePost(postId, user.id, dto);
    }
    deletePost(postId, user) {
        return this.service.deletePost(postId, user.id);
    }
    addComment(postId, user, body) {
        return this.service.addComment(postId, user.id, body.content);
    }
    addReview(shopId, user, dto) {
        return this.service.addReview(shopId, user.id, dto);
    }
    openChat(shopId, user) {
        return this.service.openOrCreateShopGroupChat(shopId, user.id);
    }
    getManagerRooms(user) {
        return this.service.getConsultRoomsForManager(user.id);
    }
    getBarberRooms(user) {
        return this.service.getConsultRoomsForBarber(user.id);
    }
    getMessages(roomId) {
        return this.service.getRoomMessages(roomId);
    }
    sendMessage(roomId, user, body) {
        return this.service.sendRoomMessage(roomId, user.id, body.content);
    }
};
exports.CommunityController = CommunityController;
__decorate([
    (0, common_1.Get)('users/:userId/public-profile'),
    __param(0, (0, common_1.Param)('userId')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], CommunityController.prototype, "getPublicUserProfile", null);
__decorate([
    (0, common_1.Get)('posts'),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", void 0)
], CommunityController.prototype, "getAllFeedPosts", null);
__decorate([
    (0, common_1.Get)('posts/forum'),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", void 0)
], CommunityController.prototype, "getForumPosts", null);
__decorate([
    (0, common_1.Get)('posts/user/:userId'),
    __param(0, (0, common_1.Param)('userId')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], CommunityController.prototype, "getUserPosts", null);
__decorate([
    (0, common_1.Get)('shops/:shopId/reviews'),
    __param(0, (0, common_1.Param)('shopId')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], CommunityController.prototype, "getShopReviews", null);
__decorate([
    (0, common_1.Post)('posts'),
    (0, common_1.UseGuards)(auth_guards_1.JwtAuthGuard),
    __param(0, (0, auth_guards_1.CurrentUser)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [entities_1.UserEntity, Object]),
    __metadata("design:returntype", void 0)
], CommunityController.prototype, "createPost", null);
__decorate([
    (0, common_1.Patch)('posts/:postId'),
    (0, common_1.UseGuards)(auth_guards_1.JwtAuthGuard),
    __param(0, (0, common_1.Param)('postId')),
    __param(1, (0, auth_guards_1.CurrentUser)()),
    __param(2, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, entities_1.UserEntity, Object]),
    __metadata("design:returntype", void 0)
], CommunityController.prototype, "updatePost", null);
__decorate([
    (0, common_1.Delete)('posts/:postId'),
    (0, common_1.UseGuards)(auth_guards_1.JwtAuthGuard),
    __param(0, (0, common_1.Param)('postId')),
    __param(1, (0, auth_guards_1.CurrentUser)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, entities_1.UserEntity]),
    __metadata("design:returntype", void 0)
], CommunityController.prototype, "deletePost", null);
__decorate([
    (0, common_1.Post)('posts/:postId/comments'),
    (0, common_1.UseGuards)(auth_guards_1.JwtAuthGuard),
    __param(0, (0, common_1.Param)('postId')),
    __param(1, (0, auth_guards_1.CurrentUser)()),
    __param(2, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, entities_1.UserEntity, Object]),
    __metadata("design:returntype", void 0)
], CommunityController.prototype, "addComment", null);
__decorate([
    (0, common_1.Post)('shops/:shopId/reviews'),
    (0, common_1.UseGuards)(auth_guards_1.JwtAuthGuard),
    __param(0, (0, common_1.Param)('shopId')),
    __param(1, (0, auth_guards_1.CurrentUser)()),
    __param(2, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, entities_1.UserEntity, Object]),
    __metadata("design:returntype", void 0)
], CommunityController.prototype, "addReview", null);
__decorate([
    (0, common_1.Post)('chat/shops/:shopId/open'),
    (0, common_1.UseGuards)(auth_guards_1.JwtAuthGuard),
    __param(0, (0, common_1.Param)('shopId')),
    __param(1, (0, auth_guards_1.CurrentUser)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, entities_1.UserEntity]),
    __metadata("design:returntype", void 0)
], CommunityController.prototype, "openChat", null);
__decorate([
    (0, common_1.Get)('chat/manager/rooms'),
    (0, common_1.UseGuards)(auth_guards_1.JwtAuthGuard),
    __param(0, (0, auth_guards_1.CurrentUser)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [entities_1.UserEntity]),
    __metadata("design:returntype", void 0)
], CommunityController.prototype, "getManagerRooms", null);
__decorate([
    (0, common_1.Get)('chat/barber/rooms'),
    (0, common_1.UseGuards)(auth_guards_1.JwtAuthGuard),
    __param(0, (0, auth_guards_1.CurrentUser)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [entities_1.UserEntity]),
    __metadata("design:returntype", void 0)
], CommunityController.prototype, "getBarberRooms", null);
__decorate([
    (0, common_1.Get)('chat/rooms/:roomId/messages'),
    (0, common_1.UseGuards)(auth_guards_1.JwtAuthGuard),
    __param(0, (0, common_1.Param)('roomId')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], CommunityController.prototype, "getMessages", null);
__decorate([
    (0, common_1.Post)('chat/rooms/:roomId/messages'),
    (0, common_1.UseGuards)(auth_guards_1.JwtAuthGuard),
    __param(0, (0, common_1.Param)('roomId')),
    __param(1, (0, auth_guards_1.CurrentUser)()),
    __param(2, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, entities_1.UserEntity, Object]),
    __metadata("design:returntype", void 0)
], CommunityController.prototype, "sendMessage", null);
exports.CommunityController = CommunityController = __decorate([
    (0, common_1.Controller)(),
    __metadata("design:paramtypes", [CommunityService])
], CommunityController);
let CommunityModule = class CommunityModule {
};
exports.CommunityModule = CommunityModule;
exports.CommunityModule = CommunityModule = __decorate([
    (0, common_1.Module)({
        imports: [
            typeorm_1.TypeOrmModule.forFeature([
                entities_1.PostEntity,
                entities_1.PostCommentEntity,
                entities_1.ReviewEntity,
                entities_1.ShopEntity,
                entities_1.ChatRoomEntity,
                entities_1.ChatMessageEntity,
                entities_1.BarberEntity,
                entities_1.UserEntity,
            ]),
        ],
        controllers: [CommunityController],
        providers: [CommunityService],
    })
], CommunityModule);
//# sourceMappingURL=community.module.js.map