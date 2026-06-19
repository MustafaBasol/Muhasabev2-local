import type { ColumnType } from 'typeorm';

export type ComptarioDatabaseDriver = 'postgres' | 'sqlite';

const normalize = (value: string | undefined): string =>
  String(value ?? '').trim().toLowerCase();

export const isNativeLocalEdition = (): boolean =>
  normalize(process.env.APP_EDITION) === 'native-local';

export const getDatabaseDriver = (): ComptarioDatabaseDriver => {
  const explicitDriver = normalize(
    process.env.DATABASE_TYPE ||
      process.env.TEST_DATABASE_TYPE ||
      process.env.TEST_DB ||
      process.env.TYPEORM_CONNECTION ||
      process.env.TYPEORM_DRIVER,
  );

  if (explicitDriver === 'sqlite' || explicitDriver === 'better-sqlite3') {
    return 'sqlite';
  }
  if (explicitDriver === 'postgres' || explicitDriver === 'pg') {
    return 'postgres';
  }
  if (normalize(process.env.DB_SQLITE) === 'true') {
    return 'sqlite';
  }
  if (
    process.env.NODE_ENV === 'test' ||
    typeof process.env.JEST_WORKER_ID !== 'undefined'
  ) {
    return 'sqlite';
  }

  return 'postgres';
};

export const isSqliteDatabase = (): boolean =>
  getDatabaseDriver() === 'sqlite';

export const isPostgresDatabase = (): boolean =>
  getDatabaseDriver() === 'postgres';

export const uuidColumnType = (): ColumnType =>
  isSqliteDatabase() ? 'varchar' : 'uuid';

export const jsonColumnType = (): ColumnType =>
  isSqliteDatabase() ? 'simple-json' : 'jsonb';

export const enumColumnType = (): ColumnType =>
  isSqliteDatabase() ? 'simple-enum' : 'enum';

export const timestampColumnType = (): ColumnType =>
  isSqliteDatabase() ? 'datetime' : 'timestamp';

export const timestampWithTimeZoneColumnType = (): ColumnType =>
  isSqliteDatabase() ? 'datetime' : 'timestamptz';
