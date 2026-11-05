import pg from 'pg';
import path from 'node:path';
import fs from 'node:fs';
import { fileURLToPath } from 'node:url';

const { Pool } = pg;
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Configure TimescaleDB / PostgreSQL connection
export const pool = new Pool({
  connectionString: process.env.DATABASE_URL || 'postgres://bitloggers:bitloggers_password@127.0.0.1:5438/bit_loggers',
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
});

pool.on('error', (err) => {
  console.error('[DATABASE] Unexpected error on idle client:', err.message);
});

// Helper for single queries
export async function query(text, params) {
  const start = Date.now();
  const res = await pool.query(text, params);
  const duration = Date.now() - start;
  // Optional query trace for diagnostics
  if (process.env.DEBUG_SQL === 'true') {
    console.log('[SQL]', { text, duration, rows: res.rowCount });
  }
  return res;
}

// Transaction runner: acquires client, BEGIN -> callback -> COMMIT or ROLLBACK
export async function withTransaction(callback) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await callback(client);
    await client.query('COMMIT');
    return result;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

// Initialize database schema and default users
export async function initDatabase(maxRetries = 6, retryDelay = 2500) {
  let client;
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      client = await pool.connect();
      break;
    } catch (err) {
      if (err.code === 'ECONNREFUSED' && attempt < maxRetries) {
        console.warn(`[DATABASE] Connection to TimescaleDB (attempt ${attempt}/${maxRetries}) refused. Retrying in ${retryDelay / 1000}s... (Ensure Docker Desktop container bitloggers-timescaledb is started)`);
        await new Promise(r => setTimeout(r, retryDelay));
      } else {
        throw err;
      }
    }
  }
  try {
    // 1. Ensure TimescaleDB extension and tables exist
    const schemaPath = path.resolve(__dirname, 'schema.sql');
    if (fs.existsSync(schemaPath)) {
      const sql = fs.readFileSync(schemaPath, 'utf8');
      await client.query(sql);

      // Safe migration for FR-12 discussion enhancements
      await client.query(`
        ALTER TABLE discussions ADD COLUMN IF NOT EXISTS parent_message_id VARCHAR(64) REFERENCES discussions(message_id) ON DELETE CASCADE;
        ALTER TABLE discussions ADD COLUMN IF NOT EXISTS version_id VARCHAR(64) REFERENCES campaign_versions(version_id) ON DELETE SET NULL;
        ALTER TABLE discussions ADD COLUMN IF NOT EXISTS version_no INT;
        ALTER TABLE discussions ADD COLUMN IF NOT EXISTS mentions JSONB DEFAULT '[]'::jsonb;
        ALTER TABLE discussions ADD COLUMN IF NOT EXISTS is_internal_only BOOLEAN NOT NULL DEFAULT FALSE;
        CREATE INDEX IF NOT EXISTS idx_discussions_campaign_id ON discussions(campaign_id);
        CREATE INDEX IF NOT EXISTS idx_discussions_parent_id ON discussions(parent_message_id);
        CREATE INDEX IF NOT EXISTS idx_discussions_version_id ON discussions(version_id);
      `);
    }

    // 2. Seed default users if empty
    const usersCheck = await client.query('SELECT COUNT(*) as count FROM users');
    if (parseInt(usersCheck.rows[0].count, 10) === 0) {
      console.log('[DATABASE] Seeding default RBAC users into PostgreSQL...');
      const insertUser = `
        INSERT INTO users (user_id, name, email, role)
        VALUES ($1, $2, $3, $4)
        ON CONFLICT (user_id) DO NOTHING
      `;
      await client.query(insertUser, ['usr-marketer-1', 'Alice Cooper (Marketer)', 'alice.marketer@bitloggers.com', 'marketer']);
      await client.query(insertUser, ['usr-reviewer-1', 'Marcus Vance (Reviewer)', 'marcus.reviewer@bitloggers.com', 'reviewer']);
      await client.query(insertUser, ['usr-reviewer-2', 'Elena Rostova (Compliance)', 'elena.compliance@bitloggers.com', 'reviewer']);
      await client.query(insertUser, ['usr-admin-1', 'Sarah Jenkins (Admin)', 'sarah.admin@bitloggers.com', 'admin']);
    }

    console.log('✅ [DATABASE] PostgreSQL + TimescaleDB initialized & verified.');
  } finally {
    client.release();
  }

  return {
    query,
    withTransaction,
    pool,
  };
}
