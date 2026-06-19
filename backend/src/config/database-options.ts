import * as path from 'path';
import { mkdirSync } from 'fs';
import type { DataSourceOptions } from 'typeorm';
import type { PostgresConnectionOptions } from 'typeorm/driver/postgres/PostgresConnectionOptions';
import type { SqliteConnectionOptions } from 'typeorm/driver/sqlite/SqliteConnectionOptions';
import {
  getDatabaseDriver,
  isNativeLocalEdition,
} from '../database/database-driver';

type DatabasePaths = {
  entities: string[];
  postgresMigrations: string[];
  sqliteMigrations: string[];
  synchronizeOverride?: boolean;
  cliDefaults?: boolean;
};

const coercePort = (value: string | undefined, fallback: number): number => {
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
};

const requireAbsoluteSqlitePath = (): string => {
  const configured = String(process.env.DATABASE_PATH ?? '').trim();
  if (!configured) {
    if (
      !isNativeLocalEdition() &&
      (process.env.NODE_ENV === 'test' ||
        typeof process.env.JEST_WORKER_ID !== 'undefined')
    ) {
      return ':memory:';
    }
    throw new Error(
      'DATABASE_PATH is required when DATABASE_TYPE=sqlite and must be an absolute path',
    );
  }
  if (!path.isAbsolute(configured)) {
    throw new Error(`DATABASE_PATH must be absolute: ${configured}`);
  }
  return path.normalize(configured);
};

export const createDatabaseOptions = (
  paths: DatabasePaths,
): DataSourceOptions => {
  const driver = getDatabaseDriver();
  const isProd = process.env.NODE_ENV === 'production';

  if (driver === 'sqlite') {
    if (!isNativeLocalEdition() && isProd) {
      throw new Error(
        'Production SQLite is only supported with APP_EDITION=native-local',
      );
    }

    const databasePath = requireAbsoluteSqlitePath();
    if (databasePath !== ':memory:') {
      mkdirSync(path.dirname(databasePath), { recursive: true });
    }

    const options: SqliteConnectionOptions = {
      type: 'sqlite',
      database: databasePath,
      entities: paths.entities,
      migrations: paths.sqliteMigrations,
      migrationsTableName: 'native_local_migrations',
      synchronize: false,
      dropSchema: false,
      logging: process.env.DB_LOGGING === 'true',
      enableWAL: true,
      busyErrorRetry: 5000,
    };
    return options;
  }

  const isTest =
    process.env.NODE_ENV === 'test' ||
    typeof process.env.JEST_WORKER_ID !== 'undefined';
  const databaseUrl =
    (isTest ? process.env.TEST_DATABASE_URL : undefined) ||
    process.env.DATABASE_URL;
  let parsedUrl: URL | undefined;
  if (databaseUrl) {
    try {
      parsedUrl = new URL(databaseUrl);
    } catch {
      throw new Error('DATABASE_URL is not a valid URL');
    }
  }
  const devUser = paths.cliDefaults ? 'moneyflow' : 'postgres';
  const devPassword = paths.cliDefaults ? 'moneyflow123' : 'password123';
  const devDatabase = paths.cliDefaults ? 'moneyflow_dev' : 'postgres';
  const host =
    (isTest ? process.env.TEST_DATABASE_HOST : undefined) ||
    parsedUrl?.hostname ||
    process.env.DATABASE_HOST ||
    (isProd ? undefined : 'localhost');
  const port = coercePort(
    (isTest ? process.env.TEST_DATABASE_PORT : undefined) ||
      parsedUrl?.port ||
      process.env.DATABASE_PORT,
    5432,
  );
  const username =
    (isTest ? process.env.TEST_DATABASE_USER : undefined) ||
    (parsedUrl?.username ? decodeURIComponent(parsedUrl.username) : undefined) ||
    process.env.DATABASE_USER ||
    (isProd ? undefined : devUser);
  const password =
    (isTest ? process.env.TEST_DATABASE_PASSWORD : undefined) ||
    (parsedUrl?.password ? decodeURIComponent(parsedUrl.password) : undefined) ||
    process.env.DATABASE_PASSWORD ||
    (isProd ? undefined : devPassword);
  const database =
    (isTest ? process.env.TEST_DATABASE_NAME : undefined) ||
    parsedUrl?.pathname.replace(/^\//, '') ||
    process.env.DATABASE_NAME ||
    (isProd ? undefined : devDatabase);

  if (!host || !username || !password || !database) {
    throw new Error(
      'DATABASE_* environment variables are required for PostgreSQL connections',
    );
  }

  const synchronizeRequested = ['true', '1', 'yes', 'on'].includes(
    String(process.env.TYPEORM_SYNCHRONIZE ?? 'true')
      .trim()
      .toLowerCase(),
  );
  const localMode =
    String(process.env.LOCAL_MODE ?? '').trim().toLowerCase() === 'true';

  const options: PostgresConnectionOptions = {
    type: 'postgres',
    host,
    port,
    username,
    password,
    database,
    entities: paths.entities,
    migrations: paths.postgresMigrations,
    synchronize:
      paths.synchronizeOverride ?? (!localMode && synchronizeRequested),
    dropSchema: false,
    logging:
      process.env.DB_LOGGING === 'true' ||
      (!isProd && process.env.DB_LOGGING !== 'false'),
    ssl:
      (isTest ? process.env.TEST_DATABASE_SSL : process.env.DATABASE_SSL) ===
      'true'
        ? { rejectUnauthorized: false }
        : false,
  };
  return options;
};
