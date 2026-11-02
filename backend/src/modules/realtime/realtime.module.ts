import { Global, Injectable, Logger, Module } from '@nestjs/common';
import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayDisconnect,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { InjectRepository, TypeOrmModule } from '@nestjs/typeorm';
import { Server, Socket } from 'socket.io';
import { Repository } from 'typeorm';
import {
  ChatMessageEntity,
  ChatRoomEntity,
  UserEntity,
} from '../../database/entities';

@WebSocketGateway({
  cors: { origin: '*' },
  namespace: '/realtime',
})
@Injectable()
export class RealtimeGateway
  implements OnGatewayConnection, OnGatewayDisconnect
{
  @WebSocketServer()
  server!: Server;

  private readonly logger = new Logger(RealtimeGateway.name);

  constructor(
    @InjectRepository(ChatRoomEntity)
    private readonly roomRepo: Repository<ChatRoomEntity>,
    @InjectRepository(ChatMessageEntity)
    private readonly msgRepo: Repository<ChatMessageEntity>,
    @InjectRepository(UserEntity)
    private readonly userRepo: Repository<UserEntity>,
  ) {}

  handleConnection(client: Socket) {
    const userId = client.handshake.query.userId as string | undefined;
    if (userId) {
      client.join(`user:${userId}`);
      this.logger.log(`Socket connected: ${client.id} -> joined user:${userId}`);
    }
  }

  handleDisconnect(client: Socket) {
    this.logger.log(`Socket disconnected: ${client.id}`);
  }

  /**
   * Đẩy sự kiện thanh toán SePay thành công ngay lập tức về thiết bị của User
   * (Không cần chờ duyệt tay hay reload trang).
   */
  emitPaymentSuccess(userId: string, payload: Record<string, any>) {
    this.server.to(`user:${userId}`).emit('payment.success', payload);
  }

  emitUserRoleUpdated(userId: string, payload: Record<string, any>) {
    this.server.to(`user:${userId}`).emit('user.role_updated', payload);
  }

  @SubscribeMessage('chat.join_room')
  handleJoinRoom(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { roomId: string },
  ) {
    client.join(`chat:${data.roomId}`);
    return { joined: data.roomId };
  }

  @SubscribeMessage('chat.send_message')
  async handleSendMessage(
    @MessageBody()
    data: {
      roomId: string;
      senderId: string;
      content: string;
    },
  ) {
    if (!data.content?.trim()) return;
    const sender = await this.userRepo.findOne({ where: { id: data.senderId } });
    if (!sender) return;

    const saved = await this.msgRepo.save(
      this.msgRepo.create({
        roomId: data.roomId,
        senderId: data.senderId,
        content: data.content.trim(),
      }),
    );

    await this.roomRepo.update(data.roomId, {
      lastMessage: data.content.trim(),
    });

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
}

@Global()
@Module({
  imports: [
    TypeOrmModule.forFeature([ChatRoomEntity, ChatMessageEntity, UserEntity]),
  ],
  providers: [RealtimeGateway],
  exports: [RealtimeGateway],
})
export class RealtimeModule {}

