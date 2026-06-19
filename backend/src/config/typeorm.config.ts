import { DataSource } from 'typeorm';
import { config } from 'dotenv';
import { createDatabaseOptions } from './database-options';

config();

const isProd = process.env.NODE_ENV === 'production';

export default new DataSource(
  createDatabaseOptions({
    entities: [
      isProd ? 'dist/src/**/*.entity.js' : 'src/**/*.entity{.ts,.js}',
    ],
    postgresMigrations: [
      isProd
        ? 'dist/src/migrations/*.js'
        : 'src/migrations/*{.ts,.js}',
    ],
    sqliteMigrations: [
      isProd
        ? 'dist/src/migrations/sqlite/*.js'
        : 'src/migrations/sqlite/*{.ts,.js}',
    ],
    synchronizeOverride: false,
    cliDefaults: true,
  }),
);
