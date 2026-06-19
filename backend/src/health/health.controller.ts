import { Controller, Get } from '@nestjs/common';
import { DataSource } from 'typeorm';

interface HealthStatus {
  status: 'ok' | 'degraded';
  appEdition: string;
  databaseType: string;
  databaseReachable: boolean;
  version: string;
  appStatus: 'ok';
  dbStatus: 'ok' | 'error';
  dbLatencyMs?: number;
  timestamp: string;
}

@Controller('health')
export class HealthController {
  constructor(private dataSource: DataSource) {}

  @Get()
  async root(): Promise<HealthStatus> {
    const start = Date.now();
    let dbStatus: 'ok' | 'error' = 'ok';
    try {
      await this.dataSource.query('SELECT 1');
    } catch {
      dbStatus = 'error';
    }
    const latency = Date.now() - start;
    return {
      status: dbStatus === 'ok' ? 'ok' : 'degraded',
      appEdition: process.env.APP_EDITION || 'cloud',
      databaseType: this.dataSource.options.type,
      databaseReachable: dbStatus === 'ok',
      version: process.env.APP_VERSION || '1.0.0',
      appStatus: 'ok',
      dbStatus,
      dbLatencyMs: latency,
      timestamp: new Date().toISOString(),
    };
  }
  @Get('email')
  getEmailHealth() {
    const provider = (process.env.MAIL_PROVIDER || 'log').toLowerCase();
    const from = process.env.MAIL_FROM || '';
    const frontendUrl =
      process.env.FRONTEND_URL || process.env.APP_PUBLIC_URL || '';
    const sandboxNote =
      provider === 'mailersend'
        ? 'Ensure MAILERSEND_API_KEY is set, sender domain is verified, and webhook secret is configured'
        : '';
    const mailerSendKeyPresent = Boolean(
      process.env.MAILERSEND_API_KEY || process.env.MAILERSEND_TOKEN,
    );
    const envFlag = (process.env.EMAIL_VERIFICATION_REQUIRED ?? '')
      .trim()
      .toLowerCase();
    const verificationRequired =
      envFlag === '' || ['true', '1', 'yes', 'on'].includes(envFlag);
    return {
      provider,
      fromConfigured: !!from,
      from,
      frontendUrl,
      note: sandboxNote,
      verificationRequired,
      mailerSendKeyPresent:
        provider === 'mailersend' ? mailerSendKeyPresent : undefined,
    };
  }
}
