import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  OneToMany,
  OneToOne,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { UserEntity } from './user.entity';
import { BarberEntity } from './barber.entity';
import { ServiceEntity } from './service.entity';
import { ShopPackagePlan } from './enums';

@Entity('shops')
export class ShopEntity {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  // Ràng buộc: Một Manager CHỈ sở hữu tối đa 1 quán (unique owner_id)
  @Column({ name: 'owner_id', unique: true })
  ownerId!: string;

  @OneToOne(() => UserEntity, (user) => user.managedShop, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'owner_id' })
  owner!: UserEntity;

  @Column({ unique: true, length: 180 })
  name!: string;

  @Column({ unique: true, length: 255 })
  address!: string;

  @Column({ name: 'avatar_url', nullable: true })
  avatarUrl?: string;

  @Column({ name: 'cover_url', nullable: true })
  coverUrl?: string;

  @Column({ name: 'gallery_urls', type: 'jsonb', default: () => "'[]'" })
  galleryUrls!: string[];

  @Column({ name: 'open_time', length: 10, default: '08:30' })
  openTime!: string;

  @Column({ name: 'close_time', length: 10, default: '20:30' })
  closeTime!: string;

  @Column({ length: 25 })
  phone!: string;

  @Column({ type: 'text', default: '' })
  description!: string;

  @Column({ type: 'double precision', default: 20.9768 })
  latitude!: number;

  @Column({ type: 'double precision', default: 105.7724 })
  longitude!: number;

  @Column({ type: 'float', default: 0.0 })
  rating!: number;

  @Column({ name: 'review_count', type: 'int', default: 0 })
  reviewCount!: number;

  @Column({ name: 'is_active', default: true })
  isActive!: boolean;

  @Column({ name: 'highlight_expires_at', type: 'timestamptz', nullable: true })
  highlightExpiresAt?: Date | null;

  @Column({
    name: 'subscription_plan',
    type: 'enum',
    enum: ShopPackagePlan,
    nullable: true,
  })
  subscriptionPlan?: ShopPackagePlan | null;

  @Column({ name: 'is_cooperation', default: false })
  isCooperation!: boolean;

  @Column({ name: 'subscription_expires_at', type: 'timestamptz', nullable: true })
  subscriptionExpiresAt?: Date | null;

  @Column({ name: 'renewal_notified_at', type: 'timestamptz', nullable: true })
  renewalNotifiedAt?: Date | null;

  @OneToMany(() => BarberEntity, (barber) => barber.shop)
  barbers?: BarberEntity[];

  @OneToMany(() => ServiceEntity, (service) => service.shop)
  services?: ServiceEntity[];

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt!: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt!: Date;
}

