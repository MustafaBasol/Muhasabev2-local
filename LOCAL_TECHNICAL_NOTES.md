# Local/On-Premise Technical Notes

## Architecture

`docker-compose.local.yml` runs:

- PostgreSQL 16 with a persistent named volume.
- Redis 7 with append-only persistence for login-attempt tracking.
- One application container that builds Vite with `VITE_API_URL=/api`, builds
  NestJS, and serves the SPA and API from `http://localhost:3000`.
- Optional pgAdmin under the `support` profile.

All published ports bind to `127.0.0.1`. Containers communicate through the
Compose network using service names and internal ports.

## Local Mode

`LOCAL_MODE=true` is additive and does not remove SaaS code. It changes only
local runtime behavior:

- Secure cookies and HSTS are disabled so HTTP localhost works even with
  `NODE_ENV=production`.
- Cookie-based CSRF enforcement is disabled for the same-origin local runtime;
  the remaining validation, authentication, authorization, and security headers
  stay active.
- Stripe startup is optional. Billing operations and webhooks return a clear
  unavailable response when Stripe is disabled.
- Turnstile is disabled by leaving its secret empty.
- Email uses `MAIL_PROVIDER=log`, and email verification is not required.
- Demo/default customer seeding is skipped. The first user registers in the UI.

## Environment Files

`.env.local` supplies Compose-level PostgreSQL and optional pgAdmin values.
`backend\.env.local` supplies application runtime values.

The startup script creates missing files from their examples but never replaces
an existing file. It only replaces recognized placeholder values for
`JWT_SECRET`, `JWT_REFRESH_SECRET`, and `CSRF_SECRET`.

Important values:

- `TYPEORM_SYNCHRONIZE=false`: mandatory for customer data.
- `FRONTEND_URL=http://localhost:3000`
- `CORS_ORIGINS=http://localhost:3000`
- `STRIPE_ENABLED=false`
- `MAIL_PROVIDER=log`
- `EMAIL_VERIFICATION_REQUIRED=false`

Database connection values passed by Compose override matching backend env
entries so the app and PostgreSQL service remain aligned.

## Database Lifecycle

The Nest runtime DataSource registers compiled migrations from
`dist/src/migrations`. Startup checks for pending migrations and runs them before
seeding or accepting traffic. Local mode forces TypeORM synchronization off,
regardless of the environment file.

The earliest migration is a static baseline generated from the current entity
model. It creates a fresh customer database without schema synchronization.
Existing incremental migrations remain registered for compatibility and future
upgrades.

`SeedService` may run idempotent system/schema compatibility checks, but local
mode does not create demo users or a default customer account.

## Backup and Restore

`backup-local.ps1` uses `pg_dump -Fc` inside the PostgreSQL container and copies
the resulting file to `local-backups`.

`restore-local.ps1`:

1. Requires explicit confirmation.
2. Stops only the app container.
3. Keeps PostgreSQL running.
4. Recreates the configured database.
5. Restores with `pg_restore --no-owner --no-privileges`.
6. Restarts the app so migration checks and health checks run normally.

Stopping the local stack never removes Docker volumes.

## Disabled External Features

The local defaults do not require or contact MailerSend, Stripe, Cloudflare
Turnstile, Codespaces, or cloud deployment services. Their implementation stays
in the repository for non-local deployments. Enabling one later requires its
normal provider credentials and an explicit environment change.
