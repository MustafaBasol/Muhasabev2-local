import { TenantPlanLimitService } from './tenant-plan-limits.service';
import { SubscriptionPlan } from '../tenants/entities/tenant.entity';

describe('TenantPlanLimitService', () => {
  it('FREE: kullanıcı, müşteri, tedarikçi limitleri uygulanmalı', () => {
    expect(TenantPlanLimitService.canAddUser(0, SubscriptionPlan.FREE)).toBe(
      true,
    );
    expect(TenantPlanLimitService.canAddUser(1, SubscriptionPlan.FREE)).toBe(
      false,
    );

    expect(
      TenantPlanLimitService.canAddCustomer(0, SubscriptionPlan.FREE),
    ).toBe(true);
    expect(
      TenantPlanLimitService.canAddCustomer(1, SubscriptionPlan.FREE),
    ).toBe(false);

    expect(
      TenantPlanLimitService.canAddSupplier(0, SubscriptionPlan.FREE),
    ).toBe(true);
    expect(
      TenantPlanLimitService.canAddSupplier(1, SubscriptionPlan.FREE),
    ).toBe(false);
  });

  it('FREE: banka hesabı limiti uygulanmalı (max 1)', () => {
    expect(
      TenantPlanLimitService.canAddBankAccount(0, SubscriptionPlan.FREE),
    ).toBe(true);
    expect(
      TenantPlanLimitService.canAddBankAccount(1, SubscriptionPlan.FREE),
    ).toBe(false);
  });

  it('FREE: aylık 5 fatura ve 5 gider limiti uygulanmalı', () => {
    expect(
      TenantPlanLimitService.canAddInvoiceThisMonth(4, SubscriptionPlan.FREE),
    ).toBe(true);
    expect(
      TenantPlanLimitService.canAddInvoiceThisMonth(5, SubscriptionPlan.FREE),
    ).toBe(false);

    expect(
      TenantPlanLimitService.canAddExpenseThisMonth(4, SubscriptionPlan.FREE),
    ).toBe(true);
    expect(
      TenantPlanLimitService.canAddExpenseThisMonth(5, SubscriptionPlan.FREE),
    ).toBe(false);
  });

  it('PRO (BASIC/PROFESSIONAL): max 3 kullanıcı, diğerleri sınırsız', () => {
    expect(TenantPlanLimitService.canAddUser(2, SubscriptionPlan.BASIC)).toBe(
      true,
    );
    expect(TenantPlanLimitService.canAddUser(3, SubscriptionPlan.BASIC)).toBe(
      false,
    );
    expect(
      TenantPlanLimitService.canAddCustomer(999, SubscriptionPlan.BASIC),
    ).toBe(true);
    expect(
      TenantPlanLimitService.canAddSupplier(999, SubscriptionPlan.PROFESSIONAL),
    ).toBe(true);
    expect(
      TenantPlanLimitService.canAddBankAccount(
        999,
        SubscriptionPlan.PROFESSIONAL,
      ),
    ).toBe(true);
    expect(
      TenantPlanLimitService.canAddInvoiceThisMonth(
        100,
        SubscriptionPlan.PROFESSIONAL,
      ),
    ).toBe(true);
    expect(
      TenantPlanLimitService.canAddExpenseThisMonth(
        100,
        SubscriptionPlan.PROFESSIONAL,
      ),
    ).toBe(true);
  });

  it('LOCAL_MODE tenant (isLocalMode=true): tüm limitler sınırsız olmalı', () => {
    const localTenant = {
      subscriptionPlan: SubscriptionPlan.FREE,
      settings: { isLocalMode: true },
    };
    expect(TenantPlanLimitService.getLimitsForTenant(localTenant).maxUsers).toBe(-1);
    expect(TenantPlanLimitService.getLimitsForTenant(localTenant).maxCustomers).toBe(-1);
    expect(TenantPlanLimitService.getLimitsForTenant(localTenant).maxSuppliers).toBe(-1);
    expect(TenantPlanLimitService.getLimitsForTenant(localTenant).maxBankAccounts).toBe(-1);
    expect(TenantPlanLimitService.getLimitsForTenant(localTenant).monthly.maxInvoices).toBe(-1);
    expect(TenantPlanLimitService.getLimitsForTenant(localTenant).monthly.maxExpenses).toBe(-1);
    expect(TenantPlanLimitService.canAddUserForTenant(9999, localTenant)).toBe(true);
    expect(TenantPlanLimitService.canAddCustomerForTenant(9999, localTenant)).toBe(true);
  });

  it('LOCAL_MODE env=true: stored plan FREE olsa bile tüm limitler global olarak bypass edilmeli', () => {
    const prev = process.env.LOCAL_MODE;
    process.env.LOCAL_MODE = 'true';
    try {
      // plan-bazlı kontroller de sınırsız olmalı
      expect(
        TenantPlanLimitService.canAddInvoiceThisMonth(9999, SubscriptionPlan.FREE),
      ).toBe(true);
      expect(
        TenantPlanLimitService.canAddExpenseThisMonth(9999, SubscriptionPlan.FREE),
      ).toBe(true);
      expect(TenantPlanLimitService.canAddUser(9999, SubscriptionPlan.FREE)).toBe(
        true,
      );
      expect(
        TenantPlanLimitService.canAddCustomer(9999, SubscriptionPlan.FREE),
      ).toBe(true);
      expect(
        TenantPlanLimitService.canAddBankAccount(9999, SubscriptionPlan.FREE),
      ).toBe(true);

      // tenant-bazlı: settings'te isLocalMode olmasa bile env yeterli
      const freeTenant = {
        subscriptionPlan: SubscriptionPlan.FREE,
        settings: null,
      };
      expect(
        TenantPlanLimitService.canAddInvoiceThisMonthForTenant(9999, freeTenant),
      ).toBe(true);
      expect(
        TenantPlanLimitService.getLimitsForTenant(freeTenant).monthly.maxInvoices,
      ).toBe(-1);
    } finally {
      if (prev === undefined) {
        delete process.env.LOCAL_MODE;
      } else {
        process.env.LOCAL_MODE = prev;
      }
    }
  });

  it('BUSINESS (ENTERPRISE): kullanıcı 10 ile sınırlı, diğerleri sınırsız', () => {
    // kullanıcı limiti 10
    expect(
      TenantPlanLimitService.canAddUser(9, SubscriptionPlan.ENTERPRISE),
    ).toBe(true);
    expect(
      TenantPlanLimitService.canAddUser(10, SubscriptionPlan.ENTERPRISE),
    ).toBe(false);
    // diğer varlıklar sınırsız
    expect(
      TenantPlanLimitService.canAddCustomer(1000, SubscriptionPlan.ENTERPRISE),
    ).toBe(true);
    expect(
      TenantPlanLimitService.canAddSupplier(1000, SubscriptionPlan.ENTERPRISE),
    ).toBe(true);
    expect(
      TenantPlanLimitService.canAddBankAccount(
        1000,
        SubscriptionPlan.ENTERPRISE,
      ),
    ).toBe(true);
    expect(
      TenantPlanLimitService.canAddInvoiceThisMonth(
        1000,
        SubscriptionPlan.ENTERPRISE,
      ),
    ).toBe(true);
    expect(
      TenantPlanLimitService.canAddExpenseThisMonth(
        1000,
        SubscriptionPlan.ENTERPRISE,
      ),
    ).toBe(true);
  });
});
