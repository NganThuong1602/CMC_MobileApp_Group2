import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { OtpPurpose } from './enums';

@Entity('otp_verifications')
export class OtpVerificationEntity {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Index()
  @Column({ length: 180 })
  email!: string;

  @Column({ name: 'otp_code', length: 6 })
  otpCode!: string;

  @Column({ type: 'enum', enum: OtpPurpose })
  purpose!: OtpPurpose;

  @Column({ name: 'payload_json', type: 'jsonb', nullable: true })
  payloadJson?: Record<string, any>;

  @Column({ name: 'expires_at', type: 'timestamptz' })
  expiresAt!: Date;

  @Column({ name: 'is_used', default: false })
  isUsed!: boolean;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt!: Date;
}

