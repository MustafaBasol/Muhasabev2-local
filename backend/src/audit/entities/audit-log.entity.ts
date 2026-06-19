import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { User } from '../../users/entities/user.entity';
import { Tenant } from '../../tenants/entities/tenant.entity';
import {
  enumColumnType,
  jsonColumnType,
  uuidColumnType,
} from '../../database/database-driver';

export enum AuditAction {
  CREATE = 'CREATE',
  UPDATE = 'UPDATE',
  DELETE = 'DELETE',
}

@Entity('audit_log')
export class AuditLog {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: uuidColumnType(), nullable: true })
  userId: string;

  @Column({ type: uuidColumnType() })
  tenantId: string;

  @Column({ type: 'varchar', length: 100 })
  entity: string;

  @Column({ type: uuidColumnType(), nullable: true })
  entityId: string;

  @Column({
    type: enumColumnType(),
    enum: AuditAction,
  })
  action: AuditAction;

  @Column({ type: jsonColumnType(), nullable: true })
  diff: Record<string, any>;

  @Column({ type: 'varchar', length: 45, nullable: true })
  ip: string;

  @Column({ type: 'text', nullable: true })
  userAgent: string;

  @CreateDateColumn()
  createdAt: Date;

  // Relations
  @ManyToOne(() => User, { onDelete: 'SET NULL' })
  @JoinColumn({ name: 'userId' })
  user: User;

  @ManyToOne(() => Tenant, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'tenantId' })
  tenant: Tenant;
}
