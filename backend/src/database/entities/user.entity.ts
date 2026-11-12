import {
  Column,
  CreateDateColumn,
  Entity,
  OneToMany,
  OneToOne,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { DEFAULT_AVATAR_URL, Gender, UserRole } from './enums';
import { ShopEntity } from './shop.entity';
import { BarberEntity } from './barber.entity';
import { FcmTokenEntity } from './fcm-token.entity';

@Entity('users')
export class UserEntity {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column({ unique: true, length: 180 })
  email!: string;

  @Column({ unique: true, length: 20 })
  phone!: string;

  @Column({ name: 'password_hash' })
  passwordHash!: string;

  @Column({ name: 'full_name', length: 120 })
  fullName!: string;

  @Column({
    type: 'enum',
    enum: UserRole,
    default: UserRole.USER,
  })
  role!: UserRole;

  @Column({
    name: 'avatar_url',
    nullable: true,
    default: DEFAULT_AVATAR_URL,
  })
  avatarUrl?: string;

  @Column({ name: 'cover_url', nullable: true })
  coverUrl?: string;

  @Column({ name: 'birth_date', type: 'date', nullable: true })
  birthDate?: string;

  @Column({
    type: 'enum',
    enum: Gender,
    default: Gender.MALE,
  })
  gender!: Gender;

  @OneToOne(() => ShopEntity, (shop) => shop.owner)
  managedShop?: ShopEntity;

  @OneToOne(() => BarberEntity, (barber) => barber.user)
  barberProfile?: BarberEntity;

  @OneToMany(() => FcmTokenEntity, (token) => token.user)
  fcmTokens?: FcmTokenEntity[];

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt!: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt!: Date;
}

