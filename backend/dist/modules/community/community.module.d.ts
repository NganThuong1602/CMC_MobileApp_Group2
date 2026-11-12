import { Repository } from 'typeorm';
import { BarberEntity, ChatMessageEntity, ChatRoomEntity, PostCommentEntity, PostEntity, ReviewEntity, ShopEntity, UserEntity, UserRole } from '../../database/entities';
import { NotificationsService } from '../notifications/notifications.module';
import { RealtimeGateway } from '../realtime/realtime.module';
export declare class CommunityService {
    private readonly postRepo;
    private readonly commentRepo;
    private readonly reviewRepo;
    private readonly shopRepo;
    private readonly roomRepo;
    private readonly msgRepo;
    private readonly barberRepo;
    private readonly userRepo;
    private readonly notificationsService;
    private readonly realtimeGateway;
    constructor(postRepo: Repository<PostEntity>, commentRepo: Repository<PostCommentEntity>, reviewRepo: Repository<ReviewEntity>, shopRepo: Repository<ShopEntity>, roomRepo: Repository<ChatRoomEntity>, msgRepo: Repository<ChatMessageEntity>, barberRepo: Repository<BarberEntity>, userRepo: Repository<UserEntity>, notificationsService: NotificationsService, realtimeGateway: RealtimeGateway);
    getPublicUserProfile(userId: string): Promise<{
        id: string;
        email: string;
        phone: string;
        fullName: string;
        role: UserRole;
        gender: import("../../database/entities").Gender;
        birthDate: string | undefined;
        avatarUrl: string;
        coverUrl: string;
    }>;
    getAllFeedPosts(): Promise<PostEntity[]>;
    getForumPosts(): Promise<{
        authorShopId: string | null;
        authorShopName: string;
        id: string;
        authorId: string;
        author: UserEntity;
        caption: string;
        imageUrls: string[];
        comments?: PostCommentEntity[];
        createdAt: Date;
    }[]>;
    getUserPosts(userId: string): Promise<PostEntity[]>;
    createPost(authorId: string, dto: {
        caption: string;
        imageUrls?: string[];
    }): Promise<PostEntity>;
    updatePost(postId: string, userId: string, dto: {
        caption?: string;
        imageUrls?: string[];
    }): Promise<PostEntity>;
    deletePost(postId: string, userId: string): Promise<{
        deleted: boolean;
        id: string;
    }>;
    addComment(postId: string, authorId: string, content: string): Promise<PostCommentEntity>;
    getShopReviews(shopId: string): Promise<ReviewEntity[]>;
    addReview(shopId: string, customerId: string, dto: {
        rating: number;
        comment: string;
    }): Promise<ReviewEntity>;
    openOrCreateShopGroupChat(shopId: string, customerId: string): Promise<ChatRoomEntity>;
    getConsultRoomsForManager(managerUserId: string): Promise<ChatRoomEntity[]>;
    getConsultRoomsForBarber(barberUserId: string): Promise<ChatRoomEntity[]>;
    getRoomMessages(roomId: string): Promise<{
        id: string;
        roomId: string;
        senderId: string;
        senderName: string;
        senderAvatar: string;
        senderRole: UserRole;
        content: string;
        createdAt: Date;
    }[]>;
    sendRoomMessage(roomId: string, senderId: string, content: string): Promise<{
        id: string;
        roomId: string;
        senderId: string;
        senderName: string;
        senderAvatar: string;
        senderRole: UserRole;
        content: string;
        createdAt: Date;
    }>;
}
export declare class CommunityController {
    private readonly service;
    constructor(service: CommunityService);
    getPublicUserProfile(userId: string): Promise<{
        id: string;
        email: string;
        phone: string;
        fullName: string;
        role: UserRole;
        gender: import("../../database/entities").Gender;
        birthDate: string | undefined;
        avatarUrl: string;
        coverUrl: string;
    }>;
    getAllFeedPosts(): Promise<PostEntity[]>;
    getForumPosts(): Promise<{
        authorShopId: string | null;
        authorShopName: string;
        id: string;
        authorId: string;
        author: UserEntity;
        caption: string;
        imageUrls: string[];
        comments?: PostCommentEntity[];
        createdAt: Date;
    }[]>;
    getUserPosts(userId: string): Promise<PostEntity[]>;
    getShopReviews(shopId: string): Promise<ReviewEntity[]>;
    createPost(user: UserEntity, dto: {
        caption: string;
        imageUrls?: string[];
    }): Promise<PostEntity>;
    updatePost(postId: string, user: UserEntity, dto: {
        caption?: string;
        imageUrls?: string[];
    }): Promise<PostEntity>;
    deletePost(postId: string, user: UserEntity): Promise<{
        deleted: boolean;
        id: string;
    }>;
    addComment(postId: string, user: UserEntity, body: {
        content: string;
    }): Promise<PostCommentEntity>;
    addReview(shopId: string, user: UserEntity, dto: {
        rating: number;
        comment: string;
    }): Promise<ReviewEntity>;
    openChat(shopId: string, user: UserEntity): Promise<ChatRoomEntity>;
    getManagerRooms(user: UserEntity): Promise<ChatRoomEntity[]>;
    getBarberRooms(user: UserEntity): Promise<ChatRoomEntity[]>;
    getMessages(roomId: string): Promise<{
        id: string;
        roomId: string;
        senderId: string;
        senderName: string;
        senderAvatar: string;
        senderRole: UserRole;
        content: string;
        createdAt: Date;
    }[]>;
    sendMessage(roomId: string, user: UserEntity, body: {
        content: string;
    }): Promise<{
        id: string;
        roomId: string;
        senderId: string;
        senderName: string;
        senderAvatar: string;
        senderRole: UserRole;
        content: string;
        createdAt: Date;
    }>;
}
export declare class CommunityModule {
}
