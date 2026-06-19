# Native Local SQLite Plan

## Phase 1 status

The backend now has an explicit Docker-free native-local database mode:

```text
APP_EDITION=native-local
DATABASE_TYPE=sqlite
DATABASE_PATH=C:\ComptarioLocal\data\comptario.db
```

`DATABASE_PATH` must be absolute. Native-local SQLite is allowed with
`NODE_ENV=production`, binds the HTTP server to `127.0.0.1`, does not require
Redis, and does not enable TypeORM schema synchronization.

SQLite uses its own versioned migration chain under
`backend/src/migrations/sqlite`. PostgreSQL and Docker installations continue
to use the existing PostgreSQL migration chain.

The SQLite connection enables WAL mode, foreign-key enforcement, and a busy
timeout. Database-specific entity types are selected through the shared
database-driver helper instead of test-environment checks.

The native-local validation command is:

```powershell
cd backend
npm run validate:native-local
```

It builds the backend, starts a production-mode native-local process with a
temporary absolute SQLite path and no Redis, checks HTTP health, registers the
first user, verifies local plan behavior, and creates and reads a customer.

## Current limitations

Phase 1 validates the startup and basic customer workflow only. Several
PostgreSQL-oriented support and administration paths still require
driver-specific work, particularly:

- admin system backup/restore database introspection and truncate logic;
- some user data export/deletion raw SQL;
- some admin schema inspection queries;
- demo-data seed scripts intended for PostgreSQL;
- PostgreSQL dump/restore scripts used by the Docker package;
- full feature-by-feature SQLite integration coverage.

These paths are not part of the initial native-local startup flow and remain
scheduled for later phases. New native-local releases must add SQLite
migrations rather than enabling `synchronize`.

SQLite native-local mode is intended for one computer and one backend process.
It is not yet a supported LAN server or high-concurrency deployment.

## Why Docker remains

The Docker/PostgreSQL package remains available as a support-managed technical
fallback. It preserves maximum compatibility with the SaaS PostgreSQL schema
and existing operational tooling. No Docker files, volumes, or deployment
architecture are removed by Phase 1.

## Why there is no native installer yet

This phase establishes database and backend compatibility only. A customer
installer still requires a fixed Windows Node runtime, prebuilt frontend and
backend artifacts, process supervision, stable data/assets directories,
SQLite-safe backup and restore, upgrade rules, code signing, and clean-machine
acceptance testing. Those belong to later phases.

