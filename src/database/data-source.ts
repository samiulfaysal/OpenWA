import { DataSource } from 'typeorm';
import { config } from 'dotenv';

// Load environment variables
config();

const dbType = process.env.DATABASE_TYPE || 'sqlite';

// SQLite configuration
const sqliteDataSource = new DataSource({
  type: 'sqlite',
  database: process.env.DATABASE_NAME || './data/openwa.sqlite',
  entities: [__dirname + '/../**/*.entity{.ts,.js}'],
  migrations: [__dirname + '/migrations/*{.ts,.js}'],
  synchronize: false,
  logging: process.env.DATABASE_LOGGING === 'true',
});

// PostgreSQL configuration
const postgresDataSource = new DataSource({
  type: 'postgres',
  host: 'rivescb.us-east.db.rivestack.io',
  port: 5432,
  username: 'rv_khghvr6v',
  password: process.env.DATABASE_PASSWORD,
  database: 'rv_khghvr6v',

  entities: [__dirname + '/../**/*.entity{.ts,.js}'],
  migrations: [__dirname + '/migrations/*{.ts,.js}'],

  synchronize: false,
  logging: false,

  ssl: false,

  extra: {
    max: 10,
  },
});

// Export the appropriate data source based on DATABASE_TYPE
export default dbType === 'postgres' ? postgresDataSource : sqliteDataSource;
