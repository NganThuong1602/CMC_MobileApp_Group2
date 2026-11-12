import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
  Unique,
  UpdateDateColumn,
} from 'typeorm';
import { ShopEntity } from './shop.entity';
import { UserEntity } from './user.entity';
import { NotificationType } from './enums';

@Entity('reviews')
export class ReviewEntity {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column({ name: 'shop_id' })
  shopId!: string;

  @ManyToOne(() => ShopEntity, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'shop_id' })
  shop!: ShopEntity;

  @Column({ name: 'customer_id' })
  customerId!: string;

  @ManyToOne(() => UserEntity, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'customer_id' })
  customer!: UserEntity;

  @Column({ type: 'int', default: 5 })
  rating!: number;

  @Column({ type: 'text' })
  comment!: string;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt!: Date;
}

@Entity('chat_rooms')
@Unique(['shopId', 'customerId'])
export class ChatRoomEntity {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column({ name: 'shop_id' })
  shopId!: string;

  @ManyToOne(() => ShopEntity, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'shop_id' })
  shop!: ShopEntity;

  @Column({ name: 'customer_id' })
  customerId!: string;

  @ManyToOne(() => UserEntity, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'customer_id' })
  customer!: UserEntity;

  @Column({ name: 'last_message', type: 'text', default: '' })
  lastMessage!: string;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt!: Date;
}

@Entity('chat_messages')
export class ChatMessageEntity {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column({ name: 'room_id' })
  roomId!: string;

  @ManyToOne(() => ChatRoomEntity, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'room_id' })
  room!: ChatRoomEntity;

  @Column({ name: 'sender_id' })
  senderId!: string;

  @ManyToOne(() => UserEntity, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'sender_id' })
  sender!: UserEntity;

  @Column({ type: 'text' })
  content!: string;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt!: Date;
}

@Entity('notifications')
export class NotificationEntity {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column({ name: 'recipient_id' })
  recipientId!: string;

  @ManyToOne(() => UserEntity, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'recipient_id' })
  recipient!: UserEntity;

  @Column({ length: 180 })
  title!: string;

  @Column({ type: 'text' })
  body!: string;

  @Column({
    type: 'enum',
    enum: NotificationType,
    default: NotificationType.SYSTEM,
  })
  type!: NotificationType;

  @Column({ name: 'is_read', default: false })
  isRead!: boolean;

  @Column({ type: 'jsonb', nullable: true })
  metadata?: Record<string, any>;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt!: Date;
}

