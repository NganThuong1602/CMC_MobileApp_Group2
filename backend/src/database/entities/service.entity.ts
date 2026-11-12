import {
  Column,
  Entity,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { ShopEntity } from './shop.entity';

@Entity('services')
export class ServiceEntity {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column({ name: 'shop_id' })
  shopId!: string;

  @ManyToOne(() => ShopEntity, (shop) => shop.services, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'shop_id' })
  shop!: ShopEntity;

  @Column({ length: 150 })
  name!: string;

  @Column({ type: 'int' })
  price!: number;

  @Column({ name: 'duration_minutes', type: 'int' })
  durationMinutes!: number;

  @Column({ type: 'text', default: '' })
  description!: string;

  @Column({ name: 'is_active', default: true })
  isActive!: boolean;
}

