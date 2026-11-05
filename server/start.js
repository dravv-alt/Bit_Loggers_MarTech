import 'dotenv/config';
import { createApp, seedDemoCampaigns, seedCalendarFlights } from './index.js';

const PORT = process.env.PORT || 3000;

async function bootstrap() {
  const { app, db, workflow, outbox } = await createApp();

  // Seed initial demo data and calendar flight schedules in PostgreSQL + TimescaleDB
  await seedDemoCampaigns(workflow, db);
  await seedCalendarFlights(workflow, db);

  // Background worker polling transactional outbox every 4 seconds
  setInterval(async () => {
    try {
      await outbox.processPendingEvents();
    } catch (err) {
      console.error('Error during background outbox poll:', err.message);
    }
  }, 4000);

  app.listen(PORT, () => {
    console.log(`\n🚀 Bit Loggers Backend API running on http://localhost:${PORT}`);
    console.log(`🐘 Connected to PostgreSQL + TimescaleDB`);
    console.log(`📡 Transactional Outbox Worker active (polling interval: 4s)`);
  });
}

bootstrap().catch((err) => {
  console.error('[FATAL] Failed to start server:', err);
  process.exit(1);
});
