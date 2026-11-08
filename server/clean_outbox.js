import pg from 'pg';

const pool = new pg.Pool({
  connectionString: 'postgres://bitloggers:bitloggers_password@127.0.0.1:5438/bit_loggers',
});

async function main() {
  await pool.query('DELETE FROM outbox_events');
  await pool.query('DELETE FROM notifications');

  const now = new Date();
  const m1 = new Date(now.getTime() - 15 * 60 * 1000).toISOString();
  const m2 = new Date(now.getTime() - 8 * 60 * 1000).toISOString();
  const m3 = new Date(now.getTime() - 2 * 60 * 1000).toISOString();

  await pool.query(`
    INSERT INTO outbox_events (event_id, event_type, payload, status, attempts, max_attempts, created_at, processed_at)
    VALUES 
    ($1, 'CAMPAIGN_APPROVED', $2, 'PROCESSED', 1, 3, $3, $3),
    ($4, 'FLIGHT_SCHEDULED', $5, 'PROCESSED', 1, 3, $6, $6),
    ($7, 'BUDGET_REALLOCATION_ALERT', $8, 'PENDING', 0, 3, $9, NULL)
  `, [
    'outbox-clean-01',
    JSON.stringify({ recipients: ['marcus.reviewer@bitloggers.com'], title: 'Campaign "Nordic Summer Flash" Approved', message: 'Campaign proposal has been approved and moved to ready state.' }),
    m1,
    'outbox-clean-02',
    JSON.stringify({ recipients: ['alice.cooper@bitloggers.com'], title: 'Flight Scheduled: Social & Display', message: 'Campaign flight scheduled for Nov 10 - Nov 18 across omnichannel lanes.' }),
    m2,
    'outbox-clean-03',
    JSON.stringify({ recipients: ['finance-lead@bitloggers.com'], title: 'Budget Cap Reallocation Alert', message: 'Notice: Budget cap update pending dispatch confirmation.' }),
    m3,
  ]);

  const count = await pool.query('SELECT status, count(*) FROM outbox_events GROUP BY status');
  console.log('Clean slate outbox breakdown:', count.rows);
  await pool.end();
}

main().catch(console.error);
