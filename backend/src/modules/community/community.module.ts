import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  ForbiddenException,
  Get,
  Injectable,
  Module,
  NotFoundException,
  Param,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { InjectRepository, TypeOrmModule } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';
import { CurrentUser, JwtAuthGuard } from '../../common/auth.guards';
import {
  BarberEntity,
  ChatMessageEntity,
  ChatRoomEntity,
  DEFAULT_AVATAR_URL,
  NotificationType,
  PostCommentEntity,
  PostEntity,
  ReviewEntity,
  ShopEntity,
  UserEntity,
  UserRole,
} from '../../database/entities';
import { NotificationsService } from '../notifications/notifications.module';
import { RealtimeGateway } from '../realtime/realtime.module';

@Injectable()
export class CommunityService {
  constructor(
    @InjectRepository(PostEntity)
    private readonly postRepo: Repository<PostEntity>,
    @InjectRepository(PostCommentEntity)
    private readonly commentRepo: Repository<PostCommentEntity>,
    @InjectRepository(ReviewEntity)
    private readonly reviewRepo: Repository<ReviewEntity>,
    @InjectRepository(ShopEntity)
    private readonly shopRepo: Repository<ShopEntity>,
    @InjectRepository(ChatRoomEntity)
    private readonly roomRepo: Repository<ChatRoomEntity>,
    @InjectRepository(ChatMessageEntity)
    private readonly msgRepo: Repository<ChatMessageEntity>,
    @InjectRepository(BarberEntity)
    private readonly barberRepo: Repository<BarberEntity>,
    @InjectRepository(UserEntity)
    private readonly userRepo: Repository<UserEntity>,
    private readonly notificationsService: NotificationsService,
    private readonly realtimeGateway: RealtimeGateway,
  ) {}

  async getPublicUserProfile(userId: string) {
    const user = await this.userRepo.findOne({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('Không tìm thấy trang cá nhân người dùng');
    }
    return {
      id: user.id,
      email: user.email,
      phone: user.phone,
      fullName: user.fullName,
      role: user.role,
      gender: user.gender,
      birthDate: user.birthDate,
      avatarUrl:
        user.avatarUrl && user.avatarUrl.trim().length > 0
          ? user.avatarUrl
          : DEFAULT_AVATAR_URL,
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

  /**
   * Diễn đàn (thay cho Nổi bật):
   * - Hiển thị bài đăng của tài khoản đang là BARBER (từ thời điểm trở thành Barber: post.createdAt >= barber.joinedAt)
   *   VÀ bài đăng của tài khoản đang giữ role MANAGER (Chủ quán).
   * - Sắp xếp theo thời gian mới nhất (createdAt DESC).
   */
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
        where: { role: UserRole.MANAGER },
      }),
    ]);

    const barberByUserId = new Map<string, BarberEntity>();
    for (const b of barbers) {
      if (b.user?.role === UserRole.BARBER) {
        barberByUserId.set(b.userId, b);
      }
    }

    const shopByOwnerId = new Map<string, ShopEntity>();
    for (const shop of shops) {
      if (!shopByOwnerId.has(shop.ownerId)) {
        shopByOwnerId.set(shop.ownerId, shop);
      }
    }

    const eligibleAuthorIds = Array.from(
      new Set([
        ...barberByUserId.keys(),
        ...managers.map((m) => m.id),
      ]),
    );
    if (eligibleAuthorIds.length === 0) return [];

    const posts = await this.postRepo.find({
      where: { authorId: In(eligibleAuthorIds) },
      relations: ['author', 'comments', 'comments.author'],
      order: { createdAt: 'DESC' },
      take: 100,
    });

    return posts
      .filter((post) => {
        if (post.author?.role === UserRole.MANAGER) {
          return true;
        }
        const barber = barberByUserId.get(post.authorId);
        if (!barber) return false;
        const since = barber.joinedAt ?? barber.createdAt;
        return new Date(post.createdAt).getTime() >= new Date(since).getTime();
      })
      .slice(0, 60)
      .map((post) => {
        if (post.author?.role === UserRole.MANAGER) {
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

  async getUserPosts(userId: string) {
    return this.postRepo.find({
      where: { authorId: userId },
      relations: ['author', 'comments', 'comments.author'],
      order: { createdAt: 'DESC' },
    });
  }

  async createPost(
    authorId: string,
    dto: { caption: string; imageUrls?: string[] },
  ) {
    const images = (dto.imageUrls ?? [])
      .map((u) => u.trim())
      .filter((u) => u.length > 0);
    if (images.length > 5) {
      throw new BadRequestException('Bài viết chỉ được đính kèm tối đa 5 ảnh');
    }
    const caption = (dto.caption ?? '').trim();
    if (!caption && images.length === 0) {
      throw new BadRequestException(
        'Vui lòng nhập nội dung hoặc đính kèm ít nhất 1 ảnh',
      );
    }
    const saved = await this.postRepo.save(
      this.postRepo.create({
        authorId,
        caption,
        imageUrls: images,
      }),
    );
    return this.postRepo.findOneOrFail({
      where: { id: saved.id },
      relations: ['author', 'comments', 'comments.author'],
    });
  }

  async updatePost(
    postId: string,
    userId: string,
    dto: { caption?: string; imageUrls?: string[] },
  ) {
    const post = await this.postRepo.findOne({ where: { id: postId } });
    if (!post) {
      throw new NotFoundException('Không tìm thấy bài viết');
    }
    if (post.authorId !== userId) {
      throw new ForbiddenException(
        'Bạn chỉ có thể chỉnh sửa bài viết của chính mình',
      );
    }

    const nextCaption =
      dto.caption !== undefined ? dto.caption.trim() : post.caption;
    const nextImages =
      dto.imageUrls !== undefined
        ? dto.imageUrls.map((u) => u.trim()).filter((u) => u.length > 0)
        : post.imageUrls;

    if (nextImages.length > 5) {
      throw new BadRequestException('Bài viết chỉ được đính kèm tối đa 5 ảnh');
    }
    if (!nextCaption && nextImages.length === 0) {
      throw new BadRequestException(
        'Bài viết cần có nội dung hoặc ít nhất 1 hình ảnh',
      );
    }

    post.caption = nextCaption;
    post.imageUrls = nextImages;
    await this.postRepo.save(post);

    return this.postRepo.findOneOrFail({
      where: { id: post.id },
      relations: ['author', 'comments', 'comments.author'],
    });
  }

  async deletePost(postId: string, userId: string) {
    const post = await this.postRepo.findOne({ where: { id: postId } });
    if (!post) {
      throw new NotFoundException('Không tìm thấy bài viết');
    }
    if (post.authorId !== userId) {
      throw new ForbiddenException(
        'Bạn chỉ có thể xoá bài viết của chính mình',
      );
    }
    await this.postRepo.delete(post.id);
    return { deleted: true, id: postId };
  }

  async addComment(postId: string, authorId: string, content: string) {
    if (!content?.trim()) {
      throw new BadRequestException('Nội dung bình luận không được trống');
    }
    const saved = await this.commentRepo.save(
      this.commentRepo.create({
        postId,
        authorId,
        content: content.trim(),
      }),
    );
    return this.commentRepo.findOneOrFail({
      where: { id: saved.id },
      relations: ['author'],
    });
  }

  async getShopReviews(shopId: string) {
    return this.reviewRepo.find({
      where: { shopId },
      relations: ['customer'],
      order: { createdAt: 'DESC' },
    });
  }

  async addReview(
    shopId: string,
    customerId: string,
    dto: { rating: number; comment: string },
  ) {
    const saved = await this.reviewRepo.save(
      this.reviewRepo.create({
        shopId,
        customerId,
        rating: Math.min(5, Math.max(1, dto.rating)),
        comment: dto.comment,
      }),
    );

    const allReviews = await this.reviewRepo.find({ where: { shopId } });
    const avg =
      allReviews.length > 0
        ? allReviews.reduce((s, r) => s + r.rating, 0) / allReviews.length
        : 0;
    await this.shopRepo.update(shopId, {
      rating: Number(avg.toFixed(1)),
      reviewCount: allReviews.length,
    });

    return saved;
  }

  async openOrCreateShopGroupChat(shopId: string, customerId: string) {
    let room = await this.roomRepo.findOne({
      where: { shopId, customerId },
      relations: ['shop', 'customer'],
    });
    if (!room) {
      room = await this.roomRepo.save(
        this.roomRepo.create({
          shopId,
          customerId,
          lastMessage: 'Bắt đầu cuộc trò chuyện với quán',
        }),
      );
      room = await this.roomRepo.findOneOrFail({
        where: { id: room.id },
        relations: ['shop', 'customer'],
      });
    }
    return room;
  }

  /**
   * Lấy danh sách phòng chat tư vấn khách hàng cho Chủ quán (Manager).
   */
  async getConsultRoomsForManager(managerUserId: string) {
    const shop = await this.shopRepo.findOne({
      where: { ownerId: managerUserId },
    });
    if (!shop) return [];
    return this.roomRepo.find({
      where: { shopId: shop.id },
      relations: ['customer', 'shop'],
      order: { updatedAt: 'DESC' },
    });
  }

  async getConsultRoomsForBarber(barberUserId: string) {
    // Dự phòng nếu gọi API cũ từ phía Manager hoặc Barber
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
    if (!barber) return [];
    return this.roomRepo.find({
      where: { shopId: barber.shopId },
      relations: ['customer', 'shop'],
      order: { updatedAt: 'DESC' },
    });
  }

  async getRoomMessages(roomId: string) {
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

  /**
   * Gửi tin nhắn trong phòng chat giữa Khách hàng và Chủ quán (Manager):
   * - Lưu tin nhắn vào DB.
   * - Phát sự kiện realtime qua Socket.IO.
   * - Tạo thông báo thật (NotificationEntity) gửi về cho Chủ quán (khi khách nhắn)
   *   hoặc gửi về cho Khách hàng (khi Chủ quán phản hồi).
   */
  async sendRoomMessage(roomId: string, senderId: string, content: string) {
    const cleanContent = content?.trim();
    if (!cleanContent) {
      throw new BadRequestException('Nội dung tin nhắn không được để trống');
    }

    const sender = await this.userRepo.findOne({ where: { id: senderId } });
    if (!sender) {
      throw new NotFoundException('Không tìm thấy tài khoản gửi tin nhắn');
    }

    const room = await this.roomRepo.findOne({
      where: { id: roomId },
      relations: ['shop', 'customer'],
    });
    if (!room) {
      throw new NotFoundException('Không tìm thấy phòng trò chuyện');
    }

    const saved = await this.msgRepo.save(
      this.msgRepo.create({
        roomId,
        senderId,
        content: cleanContent,
      }),
    );

    await this.roomRepo.update(roomId, {
      lastMessage: cleanContent,
    });

    if (room.shop && sender.id !== room.shop.ownerId) {
      await this.notificationsService.createAndPush({
        recipientId: room.shop.ownerId,
        title: `Tin nhắn mới từ khách hàng ${sender.fullName}`,
        body: cleanContent,
        type: NotificationType.CHAT_MESSAGE,
        metadata: { roomId: room.id, shopId: room.shopId },
      });
    } else if (room.customerId && sender.id !== room.customerId) {
      await this.notificationsService.createAndPush({
        recipientId: room.customerId,
        title: `Phản hồi từ quán ${room.shop?.name ?? 'BarberSmart'}`,
        body: cleanContent,
        type: NotificationType.CHAT_MESSAGE,
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
}

@Controller()
export class CommunityController {
  constructor(private readonly service: CommunityService) {}

  @Get('users/:userId/public-profile')
  getPublicUserProfile(@Param('userId') userId: string) {
    return this.service.getPublicUserProfile(userId);
  }

  @Get('posts')
  getAllFeedPosts() {
    return this.service.getAllFeedPosts();
  }

  @Get('posts/forum')
  getForumPosts() {
    return this.service.getForumPosts();
  }

  @Get('posts/user/:userId')
  getUserPosts(@Param('userId') userId: string) {
    return this.service.getUserPosts(userId);
  }

  @Get('shops/:shopId/reviews')
  getShopReviews(@Param('shopId') shopId: string) {
    return this.service.getShopReviews(shopId);
  }

  @Post('posts')
  @UseGuards(JwtAuthGuard)
  createPost(
    @CurrentUser() user: UserEntity,
    @Body() dto: { caption: string; imageUrls?: string[] },
  ) {
    return this.service.createPost(user.id, dto);
  }

  @Patch('posts/:postId')
  @UseGuards(JwtAuthGuard)
  updatePost(
    @Param('postId') postId: string,
    @CurrentUser() user: UserEntity,
    @Body() dto: { caption?: string; imageUrls?: string[] },
  ) {
    return this.service.updatePost(postId, user.id, dto);
  }

  @Delete('posts/:postId')
  @UseGuards(JwtAuthGuard)
  deletePost(
    @Param('postId') postId: string,
    @CurrentUser() user: UserEntity,
  ) {
    return this.service.deletePost(postId, user.id);
  }

  @Post('posts/:postId/comments')
  @UseGuards(JwtAuthGuard)
  addComment(
    @Param('postId') postId: string,
    @CurrentUser() user: UserEntity,
    @Body() body: { content: string },
  ) {
    return this.service.addComment(postId, user.id, body.content);
  }

  @Post('shops/:shopId/reviews')
  @UseGuards(JwtAuthGuard)
  addReview(
    @Param('shopId') shopId: string,
    @CurrentUser() user: UserEntity,
    @Body() dto: { rating: number; comment: string },
  ) {
    return this.service.addReview(shopId, user.id, dto);
  }

  @Post('chat/shops/:shopId/open')
  @UseGuards(JwtAuthGuard)
  openChat(
    @Param('shopId') shopId: string,
    @CurrentUser() user: UserEntity,
  ) {
    return this.service.openOrCreateShopGroupChat(shopId, user.id);
  }

  @Get('chat/manager/rooms')
  @UseGuards(JwtAuthGuard)
  getManagerRooms(@CurrentUser() user: UserEntity) {
    return this.service.getConsultRoomsForManager(user.id);
  }

  @Get('chat/barber/rooms')
  @UseGuards(JwtAuthGuard)
  getBarberRooms(@CurrentUser() user: UserEntity) {
    return this.service.getConsultRoomsForBarber(user.id);
  }

  @Get('chat/rooms/:roomId/messages')
  @UseGuards(JwtAuthGuard)
  getMessages(@Param('roomId') roomId: string) {
    return this.service.getRoomMessages(roomId);
  }

  @Post('chat/rooms/:roomId/messages')
  @UseGuards(JwtAuthGuard)
  sendMessage(
    @Param('roomId') roomId: string,
    @CurrentUser() user: UserEntity,
    @Body() body: { content: string },
  ) {
    return this.service.sendRoomMessage(roomId, user.id, body.content);
  }
}

@Module({
  imports: [
    TypeOrmModule.forFeature([
      PostEntity,
      PostCommentEntity,
      ReviewEntity,
      ShopEntity,
      ChatRoomEntity,
      ChatMessageEntity,
      BarberEntity,
      UserEntity,
    ]),
  ],
  controllers: [CommunityController],
  providers: [CommunityService],
})
export class CommunityModule {}
