import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
  Index,
} from 'typeorm';
import { User } from '../../users/entities/user.entity';
import {
  timestampColumnType,
  uuidColumnType,
} from '../../database/database-driver';

@Entity('email_verification_tokens')
export class EmailVerificationToken {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: uuidColumnType() })
  @Index('idx_evt_user_id')
  userId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'userId' })
  user: User;

  // SHA-256(hex) of raw token
  @Column({ type: 'varchar', length: 128 })
  tokenHash: string;

  @Column()
  @Index('idx_evt_expires_at')
  expiresAt: Date;

  @Column({ type: timestampColumnType(), nullable: true })
  usedAt: Date | null;

  @CreateDateColumn({ type: timestampColumnType() })
  createdAt: Date;

  @Column({ type: 'varchar', length: 45, nullable: true })
  ip: string | null;

  @Column({ type: 'text', nullable: true })
  ua: string | null;
}
