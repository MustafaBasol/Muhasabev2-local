import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  UpdateDateColumn,
} from 'typeorm';
import { jsonColumnType } from '../../database/database-driver';

@Entity('admin_config')
export class AdminConfig {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'varchar', length: 100 })
  username: string;

  @Column({ type: 'varchar', length: 255 })
  passwordHash: string;

  @Column({ type: 'boolean', default: false })
  twoFactorEnabled: boolean;

  @Column({ type: 'varchar', length: 255, nullable: true })
  twoFactorSecret: string | null;

  @Column({ type: jsonColumnType(), nullable: true })
  recoveryCodes: string[] | null;

  @UpdateDateColumn()
  updatedAt: Date;
}
