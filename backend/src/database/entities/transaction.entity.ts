import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
} from 'typeorm';
import {
  HighlightPlan,
  ShopPackagePlan,
  TransactionStatus,
  TransactionType,
} from './enums';

@Entity('transactions')
export class TransactionEntity {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Index({ unique: true })
  @Column({ name: 'payment_code', unique: true, length: 40 })
  paymentCode!: string; // VD: PAYSHOP849201, PAYHL392012, PAYBK992011

  @Column({ name: 'transfer_content', length: 80 })
  transferContent!: string; // VD: PAY SHOP 849201

  @Column({ name: 'user_id' })
  userId!: string;

  @Column({ name: 'shop_id', nullable: true })
  shopId?: string;

  @Column({ name: 'booking_id', nullable: true })
  bookingId?: string;

  @Column({ type: 'enum', enum: TransactionType })
  type!: TransactionType;

  @Column({
    name: 'highlight_plan',
    type: 'enum',
    enum: HighlightPlan,
    nullable: true,
  })
  highlightPlan?: HighlightPlan;

  @Column({
    name: 'package_plan',
    type: 'enum',
    enum: ShopPackagePlan,
    nullable: true,
  })
  packagePlan?: ShopPackagePlan;

  @Column({ type: 'int' })
  amount!: number;

  @Column({ name: 'qr_image_url', type: 'text' })
  qrImageUrl!: string;

  @Column({
    type: 'enum',
    enum: TransactionStatus,
    default: TransactionStatus.PENDING,
  })
  status!: TransactionStatus;

  @Column({ name: 'sepay_reference_id', nullable: true })
  sepayReferenceId?: string;

  @Column({ name: 'metadata_json', type: 'jsonb', nullable: true })
  metadataJson?: Record<string, any>;

  @Column({ name: 'paid_at', type: 'timestamptz', nullable: true })
  paidAt?: Date;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt!: Date;
}

