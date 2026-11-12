import { OnGatewayConnection, OnGatewayDisconnect } from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { Repository } from 'typeorm';
import { ChatMessageEntity, ChatRoomEntity, UserEntity } from '../../database/entities';
import { NotificationsService } from '../notifications/notifications.module';
export declare class RealtimeGateway implements OnGatewayConnection, OnGatewayDisconnect {
    private readonly roomRepo;
    private readonly msgRepo;
    private readonly userRepo;
    private readonly notificationsService;
    server: Server;
    private readonly logger;
    constructor(roomRepo: Repository<ChatRoomEntity>, msgRepo: Repository<ChatMessageEntity>, userRepo: Repository<UserEntity>, notificationsService: NotificationsService);
    handleConnection(client: Socket): void;
    handleDisconnect(client: Socket): void;
    emitPaymentSuccess(userId: string, payload: Record<string, any>): void;
    emitUserRoleUpdated(userId: string, payload: Record<string, any>): void;
    emitChatRoomMessage(roomId: string, payload: Record<string, any>): void;
    handleJoinRoom(client: Socket, data: {
        roomId: string;
    }): {
        joined: string;
    };
    handleSendMessage(data: {
        roomId: string;
        senderId: string;
        content: string;
    }): Promise<{
        id: string;
        roomId: string;
        senderId: string;
        senderName: string;
        senderAvatar: string;
        senderRole: import("../../database/entities").UserRole;
        content: string;
        createdAt: Date;
    } | undefined>;
}
export declare class RealtimeModule {
}
