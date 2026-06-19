import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { Tenant } from '../../tenants/entities/tenant.entity';
import { Supplier } from '../../suppliers/entities/supplier.entity';
import { User } from '../../users/entities/user.entity';
import {
  enumColumnType,
  timestampColumnType,
  uuidColumnType,
} from '../../database/database-driver';

export enum ExpenseCategory {
  OTHER = 'other',
  RENT = 'rent',
  UTILITIES = 'utilities',
  SALARIES = 'salaries',
  PERSONNEL = 'personnel',
  SUPPLIES = 'supplies',
  EQUIPMENT = 'equipment',
  MARKETING = 'marketing',
  TRAVEL = 'travel',
  INSURANCE = 'insurance',
  TAXES = 'taxes',
}

export enum ExpenseStatus {
  PENDING = 'pending',
  APPROVED = 'approved',
  PAID = 'paid',
  REJECTED = 'rejected',
}

@Entity('expenses')
export class Expense {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  expenseNumber: string;

  @Column({ type: uuidColumnType() })
  tenantId: string;

  @ManyToOne(() => Tenant)
  @JoinColumn({ name: 'tenantId' })
  tenant: Tenant;

  @Column({ type: uuidColumnType(), nullable: true })
  supplierId: string | null;

  @ManyToOne(() => Supplier, { nullable: true })
  @JoinColumn({ name: 'supplierId' })
  supplier: Supplier;

  @Column()
  description: string;

  @Column({ type: 'date' })
  expenseDate: Date;

  @Column({ type: 'decimal', precision: 10, scale: 2 })
  amount: number;

  @Column({
    type: enumColumnType(),
    enum: ExpenseCategory,
    default: ExpenseCategory.OTHER,
  })
  category: ExpenseCategory;

  @Column({
    type: enumColumnType(),
    enum: ExpenseStatus,
    default: ExpenseStatus.PENDING,
  })
  status: ExpenseStatus;

  @Column({ type: 'text', nullable: true })
  notes: string | null;

  @Column({ type: 'varchar', nullable: true })
  receiptUrl: string | null;

  // Soft delete columns
  @Column({ name: 'is_voided', type: 'boolean', default: false })
  isVoided: boolean;

  @Column({ name: 'void_reason', type: 'text', nullable: true })
  voidReason: string | null;

  @Column({
    name: 'voided_at',
    type: timestampColumnType(),
    nullable: true,
  })
  voidedAt: Date | null;

  @Column({ name: 'voided_by', type: uuidColumnType(), nullable: true })
  voidedBy: string | null;

  @ManyToOne(() => User, { nullable: true })
  @JoinColumn({ name: 'voided_by' })
  voidedByUser: User | null;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;

  // Attribution
  @Column({ type: uuidColumnType(), nullable: true })
  createdById: string | null;

  @ManyToOne(() => User, { nullable: true, onDelete: 'SET NULL' })
  @JoinColumn({ name: 'createdById' })
  createdByUser: User | null;

  @Column({ type: 'varchar', length: 255, nullable: true })
  createdByName: string | null;

  @Column({ type: uuidColumnType(), nullable: true })
  updatedById: string | null;

  @ManyToOne(() => User, { nullable: true, onDelete: 'SET NULL' })
  @JoinColumn({ name: 'updatedById' })
  updatedByUser: User | null;

  @Column({ type: 'varchar', length: 255, nullable: true })
  updatedByName: string | null;
}
