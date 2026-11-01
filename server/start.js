import { createApp, seedDemoCampaigns } from './index.js';

const PORT = process.env.PORT || 3000;
const { app, db, workflow, outbox } = createApp();

// Seed initial demo data
seedDemoCampaigns(workflow, db);

// Background worker polling outbox every 4 seconds
setInterval(() => {
  try {
    outbox.processPendingEvents();
  } catch (err) {
    console.error('Error during background outbox poll:', err.message);
  }
}, 4000);

app.listen(PORT, () => {
  console.log(`\n🚀 Bit Loggers Backend API running on http://localhost:${PORT}`);
  console.log(`📡 Transactional Outbox Worker active (polling interval: 4s)`);
});

