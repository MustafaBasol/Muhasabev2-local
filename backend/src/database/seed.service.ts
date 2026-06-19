import { Injectable, Logger } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import * as fs from 'fs';
import * as path from 'path';
import {
  SubscriptionPlan,
  Tenant,
} from '../tenants/entities/tenant.entity';
import {
  isNativeLocalEdition,
  isPostgresDatabase,
} from './database-driver';

@Injectable()
export class SeedService {
  private readonly logger = new Logger(SeedService.name);

  constructor(
    @InjectDataSource()
    private dataSource: DataSource,
  ) {}

  async seed() {
    try {
      // Şema uyumluluğunu sağla (idempotent düzeltmeler)
      await this.ensureSchemaCompatibility();

      if (
        isNativeLocalEdition() ||
        String(process.env.LOCAL_MODE).trim().toLowerCase() === 'true'
      ) {
        // Mevcut (fix öncesi oluşturulmuş) tenant'ları local/sınırsız olarak işaretle
        await this.bootstrapLocalTenants();
        this.logger.log(
          'Local mode: demo/default user seed skipped; first user registers through the UI',
        );
        return;
      }

      // Check if database is empty
      const existingUsers = await this.getExistingUserCount();

      if (existingUsers > 0) {
        this.logger.log('✅ Database already has data, skipping seed');
        return;
      }

      this.logger.log('📦 Seeding database with initial data...');

      const seedFile = path.join(__dirname, 'seeds', 'seed-data.sql');

      if (!fs.existsSync(seedFile)) {
        this.logger.warn('⚠️ Seed file not found, skipping seed');
        return;
      }

      const seedData = fs.readFileSync(seedFile, 'utf-8');

      // Execute seed data
      await this.dataSource.query(seedData);

      this.logger.log('✅ Database seeded successfully!');
    } catch (error) {
      this.logger.error(
        `❌ Error seeding database: ${this.getErrorMessage(error)}`,
      );
      // Don't throw - allow app to start even if seeding fails
    }
  }

  /**
   * LOCAL_MODE: Fix öncesinde FREE/Starter olarak oluşturulmuş mevcut tenant'ları
   * local/on-premise sınırsız lisansa yükseltir. Idempotent'tir; manuel SQL gerekmez.
   * settings içindeki diğer alanlar (vergi bilgileri vb.) korunur, sadece local
   * mod işaretleri merge edilir.
   */
  private async bootstrapLocalTenants() {
    try {
      const tenantRepo = this.dataSource.getRepository(Tenant);
      const tenants = await tenantRepo.find();
      if (tenants.length === 0) {
        return;
      }

      const unlimitedOverrides = {
        maxUsers: -1,
        maxCustomers: -1,
        maxSuppliers: -1,
        maxBankAccounts: -1,
        monthly: { maxInvoices: -1, maxExpenses: -1 },
      };

      let updated = 0;
      for (const tenant of tenants) {
        const currentSettings =
          tenant.settings && typeof tenant.settings === 'object'
            ? { ...tenant.settings }
            : {};

        const alreadyLocal =
          currentSettings['isLocalMode'] === true &&
          tenant.subscriptionPlan === SubscriptionPlan.ENTERPRISE &&
          tenant.maxUsers === -1;

        if (alreadyLocal) {
          continue;
        }

        currentSettings['isLocalMode'] = true;
        currentSettings['planOverrides'] = unlimitedOverrides;

        tenant.settings = currentSettings;
        tenant.subscriptionPlan = SubscriptionPlan.ENTERPRISE;
        tenant.maxUsers = -1;
        tenant.subscriptionExpiresAt = null;

        await tenantRepo.save(tenant);
        updated += 1;
      }

      if (updated > 0) {
        this.logger.log(
          `✅ Local mode: ${updated} mevcut tenant local/sınırsız lisansa yükseltildi`,
        );
      }
    } catch (error) {
      this.logger.warn(
        `⚠️ Local tenant bootstrap skipped: ${this.getErrorMessage(error)}`,
      );
    }
  }

  private async ensureSchemaCompatibility() {
    if (!isPostgresDatabase()) {
      return;
    }

    try {
      // Tenants tablosundaki yeni alanlar için güvenli (idempotent) eklemeler
      await this.dataSource.query(`
        DO $$
        BEGIN
          -- Website URL
          IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'tenants' AND column_name = 'website'
          ) THEN
            ALTER TABLE "tenants" ADD "website" character varying;
          END IF;

          -- Türkiye
          IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'tenants' AND column_name = 'taxOffice'
          ) THEN
            ALTER TABLE "tenants" ADD "taxOffice" character varying;
          END IF;
          IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'tenants' AND column_name = 'mersisNumber'
          ) THEN
            ALTER TABLE "tenants" ADD "mersisNumber" character varying;
          END IF;
          IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'tenants' AND column_name = 'kepAddress'
          ) THEN
            ALTER TABLE "tenants" ADD "kepAddress" character varying;
          END IF;

          -- Fransa
          IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'tenants' AND column_name = 'siretNumber'
          ) THEN
            ALTER TABLE "tenants" ADD "siretNumber" character varying;
          END IF;
          IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'tenants' AND column_name = 'sirenNumber'
          ) THEN
            ALTER TABLE "tenants" ADD "sirenNumber" character varying;
          END IF;
          IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'tenants' AND column_name = 'apeCode'
          ) THEN
            ALTER TABLE "tenants" ADD "apeCode" character varying;
          END IF;
          IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'tenants' AND column_name = 'tvaNumber'
          ) THEN
            ALTER TABLE "tenants" ADD "tvaNumber" character varying;
          END IF;
          IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'tenants' AND column_name = 'rcsNumber'
          ) THEN
            ALTER TABLE "tenants" ADD "rcsNumber" character varying;
          END IF;

          -- Almanya
          IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'tenants' AND column_name = 'steuernummer'
          ) THEN
            ALTER TABLE "tenants" ADD "steuernummer" character varying;
          END IF;
          IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'tenants' AND column_name = 'umsatzsteuerID'
          ) THEN
            ALTER TABLE "tenants" ADD "umsatzsteuerID" character varying;
          END IF;
          IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'tenants' AND column_name = 'handelsregisternummer'
          ) THEN
            ALTER TABLE "tenants" ADD "handelsregisternummer" character varying;
          END IF;
          IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'tenants' AND column_name = 'geschaeftsfuehrer'
          ) THEN
            ALTER TABLE "tenants" ADD "geschaeftsfuehrer" character varying;
          END IF;

          -- Amerika
          IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'tenants' AND column_name = 'einNumber'
          ) THEN
            ALTER TABLE "tenants" ADD "einNumber" character varying;
          END IF;
          IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'tenants' AND column_name = 'taxId'
          ) THEN
            ALTER TABLE "tenants" ADD "taxId" character varying;
          END IF;
          IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'tenants' AND column_name = 'salesTaxPermitNumber'
          ) THEN
            ALTER TABLE "tenants" ADD "salesTaxPermitNumber" character varying;
          END IF;
          IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'tenants' AND column_name = 'businessLicenseNumber'
          ) THEN
            ALTER TABLE "tenants" ADD "businessLicenseNumber" character varying;
          END IF;
          IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'tenants' AND column_name = 'stateOfIncorporation'
          ) THEN
            ALTER TABLE "tenants" ADD "stateOfIncorporation" character varying;
          END IF;
        END$$;`);
    } catch (error) {
      this.logger.warn(
        `⚠️ Schema compatibility check skipped: ${this.getErrorMessage(error)}`,
      );
    }
  }

  private async getExistingUserCount(): Promise<number> {
    const rowsResult: unknown = await this.dataSource.query(
      'SELECT COUNT(*) as count FROM users',
    );
    if (!Array.isArray(rowsResult) || rowsResult.length === 0) {
      return 0;
    }
    const firstRow = rowsResult[0] as Record<string, unknown> | undefined;
    const rawCount = firstRow?.count;
    if (typeof rawCount === 'number') {
      return rawCount;
    }
    if (typeof rawCount === 'string') {
      const parsed = Number(rawCount);
      return Number.isFinite(parsed) ? parsed : 0;
    }
    return 0;
  }

  private getErrorMessage(error: unknown): string {
    if (error instanceof Error) {
      return error.message;
    }
    if (typeof error === 'string') {
      return error;
    }
    try {
      return JSON.stringify(error);
    } catch {
      return String(error);
    }
  }
}
