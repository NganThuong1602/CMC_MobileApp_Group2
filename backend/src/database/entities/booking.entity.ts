import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { BookingStatus, PaymentMethod } from './enums';
import { ShopEntity } from './shop.entity';
import { BarberEntity } from './barber.entity';
import { UserEntity } from './user.entity';

@Entity('bookings')
@Index(['barberId', 'bookingDate'])
export class BookingEntity {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column({ name: 'shop_id' })
  shopId!: string;

  @ManyToOne(() => ShopEntity, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'shop_id' })
  shop!: ShopEntity;

  @Column({ name: 'barber_id' })
  barberId!: string;

  @ManyToOne(() => BarberEntity, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'barber_id' })
  barber!: BarberEntity;

  @Column({ name: 'customer_id' })
  customerId!: string;

  @ManyToOne(() => UserEntity, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'customer_id' })
  customer!: UserEntity;

  @Column({ name: 'booking_date', type: 'date' })
  bookingDate!: string; // YYYY-MM-DD

  @Column({ name: 'start_minutes', type: 'int' })
  startMinutes!: number;

  @Column({ name: 'end_minutes', type: 'int' })
  endMinutes!: number;

  @Column({ name: 'total_duration_minutes', type: 'int' })
  totalDurationMinutes!: number;

  @Column({ name: 'total_price', type: 'int' })
  totalPrice!: number;

  @Column({ name: 'services_snapshot', type: 'jsonb', default: () => "'[]'" })
  servicesSnapshot!: Array<{
    id: string;
    name: string;
    price: number;
    durationMinutes: number;
  }>;

  @Column({
    name: 'payment_method',
    type: 'enum',
    enum: PaymentMethod,
    default: PaymentMethod.CASH_AT_SHOP,
  })
  paymentMethod!: PaymentMethod;

  @Column({ name: 'is_paid', default: false })
  isPaid!: boolean;

  @Column({
    type: 'enum',
    enum: BookingStatus,
    default: BookingStatus.CONFIRMED,
  })
  status!: BookingStatus;

  @Column({ name: 'completed_at', type: 'timestamptz', nullable: true })
  completedAt?: Date | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt!: Date;
}

