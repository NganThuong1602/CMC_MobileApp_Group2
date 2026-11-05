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
import { Repository } from 'typeorm';
import { CurrentUser, JwtAuthGuard } from '../../common/auth.guards';
import {
  BarberEntity,
  ChatMessageEntity,
  ChatRoomEntity,
  DEFAULT_AVATAR_URL,
  PostCommentEntity,
  PostEntity,
  ReviewEntity,
  ShopEntity,
  UserEntity,
} from '../../database/entities';

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
      allReviews.reduce((s, r) => s + r.rating, 0) / allReviews.length;
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
          lastMessage: 'Bắt đầu cuộc trò chuyện tư vấn kiểu tóc',
        }),
      );
      room = await this.roomRepo.findOneOrFail({
        where: { id: room.id },
        relations: ['shop', 'customer'],
      });
    }
    return room;
  }

  async getConsultRoomsForBarber(barberUserId: string) {
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
}

@Controller()
export class CommunityController {
  constructor(private readonly service: CommunityService) {}

  @Get('posts')
  getAllFeedPosts() {
    return this.service.getAllFeedPosts();
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

