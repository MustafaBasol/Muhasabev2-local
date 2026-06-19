import { ServeStaticModule } from '@nestjs/serve-static';
import { join } from 'path';
import { Module, MiddlewareConsumer, NestModule } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { APP_INTERCEPTOR, APP_GUARD } from '@nestjs/core';
import { ThrottlerModule, ThrottlerGuard } from '@nestjs/throttler';
import { ApiRouteGuardMiddleware } from './common/api-route-guard.middleware';
import { AppController } from './app.controller';
import { HealthController } from './health/health.controller';
import { AppService } from './app.service';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { OrganizationsModule } from './organizations/organizations.module';
import { TenantsModule } from './tenants/tenants.module';
import { CustomersModule } from './customers/customers.module';
import { SuppliersModule } from './suppliers/suppliers.module';
import { ProductsModule } from './products/products.module';
import { InvoicesModule } from './invoices/invoices.module';
import { ExpensesModule } from './expenses/expenses.module';
import { SalesModule } from './sales/sales.module';
import { BankAccountsModule } from './bank-accounts/bank-accounts.module';
import { AdminModule } from './admin/admin.module';
import { AuditModule } from './audit/audit.module';
import { FiscalPeriodsModule } from './fiscal-periods/fiscal-periods.module';
import { CommonModule } from './common/common.module';
import { QuotesModule } from './quotes/quotes.module';
import { BillingModule } from './billing/billing.module';
import { SubprocessorsModule } from './subprocessors/subprocessors.module';
import { EmailModule } from './email/email.module';
import { SiteSettingsModule } from './site-settings/site-settings.module';
import { BlogModule } from './blog/blog.module';
import { WebhooksModule } from './webhooks/webhooks.module';
import { TenantInterceptor } from './common/interceptors/tenant.interceptor';
import { MaintenanceInterceptor } from './common/interceptors/maintenance.interceptor';
import { AuditInterceptor } from './audit/audit.interceptor';
import { SeedService } from './database/seed.service';
import { RateLimitMiddleware } from './common/rate-limit.middleware';
import { CSRFMiddleware } from './common/csrf.middleware';
import { EnsureAttributionColumnsService } from './audit/ensure-attribution-columns.service';
import { createDatabaseOptions } from './config/database-options';
import './database/patch-typeorm-for-tests';

@Module({
  imports: [
    ServeStaticModule.forRoot({
      serveRoot: '/assets',
      rootPath:
        process.env.NATIVE_ASSETS_DIR ||
        join(process.cwd(), 'public', 'assets'),
    }),
    ServeStaticModule.forRoot({
      rootPath: join(process.cwd(), 'public', 'dist'),
    }),
    ConfigModule.forRoot({
      isGlobal: true,
    }),
    ThrottlerModule.forRoot([
      {
        ttl: 60000,
        limit: 100,
      },
    ]),
    TypeOrmModule.forRootAsync({
      useFactory: () => ({
        ...createDatabaseOptions({
          entities: [__dirname + '/**/*.entity{.ts,.js}'],
          postgresMigrations: [__dirname + '/migrations/*{.ts,.js}'],
          sqliteMigrations: [
            __dirname + '/migrations/sqlite/*{.ts,.js}',
          ],
        }),
        autoLoadEntities: true,
      }),
    }),
    AuthModule,
    UsersModule,
    OrganizationsModule,
    TenantsModule,
    CustomersModule,
    SuppliersModule,
    ProductsModule,
    InvoicesModule,
    ExpensesModule,
    QuotesModule,
    SalesModule,
    BankAccountsModule,
    AdminModule,
    AuditModule,
    FiscalPeriodsModule,
    CommonModule,
    SubprocessorsModule,
    EmailModule,
    SiteSettingsModule,
    BlogModule,
    WebhooksModule,
    BillingModule,
  ],
  controllers: [AppController, HealthController],
  providers: [
    AppService,
    SeedService,
    EnsureAttributionColumnsService,
    {
      provide: APP_INTERCEPTOR,
      useClass: MaintenanceInterceptor,
    },
    {
      provide: APP_INTERCEPTOR,
      useClass: TenantInterceptor,
    },
    {
      provide: APP_INTERCEPTOR,
      useClass: AuditInterceptor,
    },
    {
      provide: APP_GUARD,
      useClass: ThrottlerGuard,
    },
  ],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer.apply(ApiRouteGuardMiddleware).forRoutes('*');
    consumer.apply(RateLimitMiddleware).forRoutes('*');
    consumer.apply(CSRFMiddleware).forRoutes('*');
  }
}
