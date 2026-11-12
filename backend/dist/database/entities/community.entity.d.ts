import { ShopEntity } from './shop.entity';
import { UserEntity } from './user.entity';
import { NotificationType } from './enums';
export declare class ReviewEntity {
    id: string;
    shopId: string;
    shop: ShopEntity;
    customerId: string;
    customer: UserEntity;
    rating: number;
    comment: string;
    createdAt: Date;
}
export declare class ChatRoomEntity {
    id: string;
    shopId: string;
    shop: ShopEntity;
    customerId: string;
    customer: UserEntity;
    lastMessage: string;
    updatedAt: Date;
}
export declare class ChatMessageEntity {
    id: string;
    roomId: string;
    room: ChatRoomEntity;
    senderId: string;
    sender: UserEntity;
    content: string;
    createdAt: Date;
}
export declare class NotificationEntity {
    id: string;
    recipientId: string;
    recipient: UserEntity;
    title: string;
    body: string;
    type: NotificationType;
    isRead: boolean;
    metadata?: Record<string, any>;
    createdAt: Date;
}
