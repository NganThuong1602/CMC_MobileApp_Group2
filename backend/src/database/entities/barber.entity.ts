import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  ManyToOne,
  OneToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { UserEntity } from './user.entity';
import { ShopEntity } from './shop.entity';

@Entity('barbers')
export class BarberEntity {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  // Ràng buộc: Một Barber chỉ được thuộc về 1 quán duy nhất tại một thời điểm
  @Column({ name: 'user_id', unique: true })
  userId!: string;

  @OneToOne(() => UserEntity, (user) => user.barberProfile, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user!: UserEntity;

  @Column({ name: 'shop_id' })
  shopId!: string;

  @ManyToOne(() => ShopEntity, (shop) => shop.barbers, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'shop_id' })
  shop!: ShopEntity;

  @Column({ name: 'base_salary', type: 'int', default: 0 })
  baseSalary!: number;

  @Column({ name: 'is_active', default: true })
  isActive!: boolean;

  @Column({ type: 'text', default: '' })
  bio!: string;

  @Column({ type: 'float', default: 5.0 })
  rating!: number;

  @Column({
    name: 'joined_at',
    type: 'timestamptz',
    default: () => 'CURRENT_TIMESTAMP',
  })
  joinedAt!: Date;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt!: Date;
}

