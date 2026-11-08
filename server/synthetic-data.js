/**
 * ====================================================================
 * BIT LOGGERS MARTECH — ENTERPRISE SYNTHETIC DATA GENERATOR
 * Generates realistic, fully-interconnected marketing data:
 *   1. Multi-phase campaigns with real ad creatives, headlines & UTM links
 *   2. Granular targeting (geos, demographics, keyword lists, custom CRM cohorts)
 *   3. Real-world financial burn metrics (spent-to-date, daily caps, GL cost centers)
 *   4. Raw volume telemetry funnels (Impressions -> Clicks -> Visits -> Leads -> Purchases)
 *   5. Hourly time-series telemetry in TimescaleDB for Circuit Breaker simulation
 *   6. Multi-tier compliance reviews (Legal, Brand Safety, Privacy, Risk Tiers)
 *   7. Calendar flight schedules aligned with Q4 retail & corporate events
 *   8. Version-anchored discussion threads & @mentions
 * ====================================================================
 */

export async function generateEnterpriseSyntheticData(workflow, db, { force = true } = {}) {
  console.log('[SYNTHETIC DATA] Initializing Enterprise MarTech Data Simulation in PostgreSQL + TimescaleDB...');

  // Ensure DB connection is ready
  const marketer = await workflow.getUser('usr-marketer-1');
  const reviewer1 = await workflow.getUser('usr-reviewer-1'); // Marcus Vance
  const compliance = await workflow.getUser('usr-reviewer-2'); // Elena Rostova

  if (!marketer || !reviewer1) {
    throw new Error('Default users (marketer/reviewer) must be initialized before seeding.');
  }

  if (force) {
    console.log('[SYNTHETIC DATA] Performing clean purge of all prior demo/test campaigns...');
    await db.query('UPDATE campaigns SET current_version_id = NULL');
    await db.query('DELETE FROM campaigns');
    await db.query("DELETE FROM kpi_metric_snapshots WHERE snapshot_id LIKE 'synth-%'");
  }

  const now = Date.now();
  const dayMs = 86400000;
  const hourMs = 3600000;

  // ------------------------------------------------------------------
  // 1. CAMPAIGN 1: Cyber Week & Holiday Omnichannel Blitz 2026
  // Status: Scheduled / Running | Tier 2 High-Budget Approved ($68,000)
  // ------------------------------------------------------------------
  console.log('[SYNTHETIC DATA] Generating Campaign 1: Cyber Week & Holiday Blitz ($68,000 Tier 2)...');
  const camp1 = await workflow.createCampaign(marketer, {
    title: 'Cyber Week & Holiday Omnichannel Blitz 2026',
    objective: 'Drive peak Q4 direct-to-consumer revenue and acquire high-LTV gift buyers across North America and Europe with tiered promo mechanics.',
    target_audience: 'Urban digital consumers aged 22-44 with luxury e-commerce affinity; 1% Lookalike of top 10% repeat buyers.',
    channel: 'Social',
    budget: 68000.00,
    kpi_projected: { conversionRate: 4.5, ctr: 5.2, roi: 4.8, cpa: 22.0, aov: 145.0 },
    ai_summary: 'High-impact omnichannel Q4 seasonal flight with multi-creative asset rotation and dynamic retargeting.',
    creatives: [
      {
        id: 'cr-cw-01',
        name: 'Tech Audio Unboxing Reel',
        headline: 'Unwrap Studio-Grade Sound This Holiday',
        primary_text: 'Exclusive 48-hour member access. Get up to 35% off award-winning noise-canceling headphones before inventory sells out.',
        cta_type: 'Shop Now',
        asset_url: 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=800&q=80',
        aspect_ratio: '1:1 Square Feed',
        preview_type: 'VIDEO_FEED',
        status: 'APPROVED_BY_BRAND'
      },
      {
        id: 'cr-cw-02',
        name: 'The Gift Everyone Wants (Story)',
        headline: 'The Gift They Actually Keep',
        primary_text: 'Over 10,000 5-star reviews. Free expedited holiday delivery, complimentary gift wrap, and 60-day hassle-free returns.',
        cta_type: 'Get Offer',
        asset_url: 'https://images.unsplash.com/photo-1546868871-7041f2a55e12?w=800&q=80',
        aspect_ratio: '9:16 Story/Reels',
        preview_type: 'FULLSCREEN_STORY',
        status: 'APPROVED_BY_BRAND'
      },
      {
        id: 'cr-cw-03',
        name: 'Curated Holiday Vault Bundles',
        headline: 'Limited Holiday Vault Bundles',
        primary_text: 'Hand-crafted seasonal combinations with custom monogramming. Strictly limited to 1,500 units worldwide.',
        cta_type: 'Explore Bundles',
        asset_url: 'https://images.unsplash.com/photo-1583394838336-acd977736f90?w=800&q=80',
        aspect_ratio: '16:9 Landscape',
        preview_type: 'DESKTOP_BANNER',
        status: 'APPROVED_BY_BRAND'
      }
    ],
    targeting: {
      placements: ['Instagram Reels', 'Instagram Stories', 'TikTok In-Feed', 'Facebook Mobile Feed'],
      geos: ['United States (US-East, US-West)', 'United Kingdom', 'Canada', 'Germany'],
      demographics: { min_age: 22, max_age: 44, gender: 'All' },
      custom_cohort: { name: 'CRM_VIP_Holiday_Shoppers_54k', size: 54200, match_rate_pct: 88.4 }
    },
    financials: {
      total_budget: 68000.00,
      daily_spend_cap: 2400.00,
      spent_to_date: 44820.00,
      remaining_budget: 23180.00,
      burn_rate_pct: 65.9,
      pacing_mode: 'OPTIMAL_PACING',
      runway_days: 9.6,
      cost_center_code: 'CC-GL-MKTG-D2C-2026-Q4',
      currency: 'USD'
    },
    compliance: {
      brand_safety: 'VERIFIED_PASSED',
      legal_claims: 'VERIFIED_PASSED (35% discount claim audited with inventory backend)',
      privacy_consent: 'VERIFIED_PASSED (GDPR/CCPA double opt-in cohort)',
      risk_tier: 'HIGH_RISK (Budget >$50k and peak seasonal brand exposure)',
      checklist: [
        { item: 'Pricing claim verified with Finance', passed: true },
        { item: 'Trademark and music sync licensing attached', passed: true },
        { item: 'Pixel fire tested on checkout webhook', passed: true },
        { item: 'GDPR opt-out header configured', passed: true }
      ]
    },
    ad_network: {
      platform: 'META_MARKETING_API',
      remote_account_id: 'act_908129841',
      remote_campaign_id: 'camp_771092',
      delivery_status: 'ACTIVE_OPTIMIZED',
      pixel_status: 'HEALTHY (8.4 events/sec)',
      algorithm_mode: 'VALUE_OPTIMIZATION'
    },
    flight_phases: [
      { phase_name: 'Phase 1: Creative QA Freeze', starts_at: new Date(now - 7 * dayMs).toISOString(), ends_at: new Date(now - 4 * dayMs).toISOString(), budget_pct: 0 },
      { phase_name: 'Phase 2: Soft Launch Pixel Test', starts_at: new Date(now - 3 * dayMs).toISOString(), ends_at: new Date(now - 1 * dayMs).toISOString(), budget_pct: 8 },
      { phase_name: 'Phase 3: Peak Scale Flight', starts_at: new Date(now - 1 * dayMs).toISOString(), ends_at: new Date(now + 12 * dayMs).toISOString(), budget_pct: 75 },
      { phase_name: 'Phase 4: Cooldown Retargeting', starts_at: new Date(now + 13 * dayMs).toISOString(), ends_at: new Date(now + 18 * dayMs).toISOString(), budget_pct: 17 }
    ],
    tracking: {
      destination_url: 'https://shop.bitloggers.com/holiday-vault',
      utm_source: 'instagram',
      utm_medium: 'paid_social',
      utm_campaign: 'q4_holiday_blitz_2026',
      utm_content: 'tech_audio_unboxing_v1'
    }
  });

  await workflow.submitCampaign(camp1.campaign_id, marketer, { idempotencyKey: `synth-submit-${camp1.campaign_id}` });
  await workflow.makeDecision(camp1.campaign_id, reviewer1, {
    versionId: camp1.current_version_id,
    decision: 'APPROVED',
    reason: 'Approved for Tier-1 Creative & Strategy and Tier-2 Finance Executive ($68,000 budget sign-off verified under CC-GL-MKTG-D2C-2026-Q4 with expected 4.8x ROI).'
  });

  const camp1Start = new Date(now - 1 * dayMs);
  const camp1End = new Date(now + 14 * dayMs);
  await workflow.scheduleCampaign(camp1.campaign_id, marketer, {
    versionId: camp1.current_version_id,
    channel: 'Social',
    startsAt: camp1Start.toISOString(),
    endsAt: camp1End.toISOString()
  });

  // Discussions on Camp 1
  const m1 = await workflow.postDiscussionMessage(camp1.campaign_id, marketer, {
    content: 'Creative assets uploaded for 3 hero angles. @Marcus Vance please verify if the 35% discount badge satisfies FTC display contrast.',
    versionId: camp1.current_version_id
  });
  await workflow.postDiscussionMessage(camp1.campaign_id, reviewer1, {
    content: 'Verified with legal counsel. Font ratio is 18pt bold with dark background, fully compliant with FTC guidance.',
    parentMessageId: m1.message_id,
    versionId: camp1.current_version_id
  });
  await workflow.postDiscussionMessage(camp1.campaign_id, compliance, {
    content: 'Finance sign-off complete. Daily spend cap confirmed at $2,400 with automatic pacing throttles.',
    isInternalOnly: true,
    versionId: camp1.current_version_id
  });

  // ------------------------------------------------------------------
  // 2. CAMPAIGN 2: Enterprise MarTech AI Platform Launch
  // Status: Approved | Search B2B Intent ($38,000)
  // ------------------------------------------------------------------
  console.log('[SYNTHETIC DATA] Generating Campaign 2: Enterprise MarTech AI Launch ($38,000 Search)...');
  const camp2 = await workflow.createCampaign(marketer, {
    title: 'Enterprise MarTech AI Platform Launch',
    objective: 'Drive enterprise B2B inbound demo requests from VP of Marketing and Marketing Ops leaders at high-growth tech companies.',
    target_audience: 'VP Marketing, CMOs, and Marketing Ops directors at Mid-Market SaaS ($20M-$150M ARR).',
    channel: 'Search',
    budget: 38000.00,
    kpi_projected: { conversionRate: 5.2, ctr: 6.8, roi: 6.2, cpa: 65.0, aov: 320.0 },
    ai_summary: 'Targeting commercial search keywords with dedicated landing pages emphasizing compliance and circuit breakers.',
    creatives: [
      {
        id: 'cr-b2b-01',
        name: 'Compliance Slippage Search Ad',
        headline: 'Stop Marketing Compliance Slippage | Bit Loggers MarTech',
        primary_text: 'Eliminate accidental ad spend overruns with immutable campaign governance and multi-tier sign-off workflows. Enterprise audit-ready.',
        cta_type: 'Schedule Demo',
        asset_url: 'https://images.unsplash.com/photo-1460925895917-afdab827c52f?w=800&q=80',
        aspect_ratio: 'Responsive Search Text',
        preview_type: 'SEARCH_SERP',
        status: 'APPROVED_BY_BRAND'
      },
      {
        id: 'cr-b2b-02',
        name: 'Automated Circuit Breakers Ad',
        headline: 'Automated Ad Spend Circuit Breakers',
        primary_text: 'Auto-pause fatigue campaigns in seconds with real-time TimescaleDB telemetry when CPA spikes 4x. Protect your burn rate.',
        cta_type: 'Watch Demo',
        asset_url: 'https://images.unsplash.com/photo-1551836022-d5d88e9218df?w=800&q=80',
        aspect_ratio: 'Responsive Search Text',
        preview_type: 'SEARCH_SERP',
        status: 'APPROVED_BY_BRAND'
      }
    ],
    targeting: {
      keywords: [
        { text: 'enterprise campaign management platform', match_type: 'EXACT', max_cpc: 7.50 },
        { text: 'martech governance workflow software', match_type: 'PHRASE', max_cpc: 6.20 },
        { text: 'ad spend approval workflow', match_type: 'PHRASE', max_cpc: 5.80 },
        { text: 'automated cpa circuit breaker marketing', match_type: 'BROAD', max_cpc: 4.90 }
      ],
      negative_keywords: ['free', 'open source', 'jobs', 'salary', 'internship', 'templates'],
      placements: ['Google Search Network', 'Search Partners'],
      geos: ['United States', 'United Kingdom', 'Canada']
    },
    financials: {
      total_budget: 38000.00,
      daily_spend_cap: 1250.00,
      spent_to_date: 0.00,
      remaining_budget: 38000.00,
      burn_rate_pct: 0.0,
      pacing_mode: 'STANDARD_PACING',
      cost_center_code: 'CC-GL-B2B-DEMANDGEN-2026',
      currency: 'USD'
    },
    compliance: {
      brand_safety: 'VERIFIED_PASSED',
      legal_claims: 'VERIFIED_PASSED (SLA guarantees cross-checked with legal terms)',
      risk_tier: 'MEDIUM_RISK',
      checklist: [
        { item: 'B2B Case study permissions granted', passed: true },
        { item: 'Privacy Shield & SOC2 compliance statement included', passed: true },
        { item: 'Landing page demo calendar webhook verified', passed: true }
      ]
    },
    ad_network: {
      platform: 'GOOGLE_ADS_API',
      remote_account_id: 'gads_cust_3819',
      remote_campaign_id: 'camp_55012',
      delivery_status: 'SCHEDULED_READY',
      pixel_status: 'HEALTHY'
    },
    flight_phases: [
      { phase_name: 'Soft Launch Keyword Testing', starts_at: new Date(now).toISOString(), ends_at: new Date(now + 3 * dayMs).toISOString(), budget_pct: 12 },
      { phase_name: 'Scale High-Intent Keywords', starts_at: new Date(now + 3 * dayMs).toISOString(), ends_at: new Date(now + 21 * dayMs).toISOString(), budget_pct: 88 }
    ],
    tracking: {
      destination_url: 'https://bitloggers.com/enterprise-demo',
      utm_source: 'google',
      utm_medium: 'cpc',
      utm_campaign: 'enterprise_ai_launch_2026',
      utm_content: 'compliance_slippage_v1'
    }
  });

  await workflow.submitCampaign(camp2.campaign_id, marketer, { idempotencyKey: `synth-submit-${camp2.campaign_id}` });

  // ------------------------------------------------------------------
  // 3. CAMPAIGN 3: VIP Loyalty Secret Vault Access (High CPA Watch)
  // Status: Running | Email Channel ($16,500) | Simulates Live Breaker Telemetry
  // ------------------------------------------------------------------
  console.log('[SYNTHETIC DATA] Generating Campaign 3: VIP Loyalty Vault ($16,500 Email)...');
  const camp3 = await workflow.createCampaign(marketer, {
    title: 'VIP Loyalty Secret Vault Access',
    objective: 'Reward top 5% brand advocates with 48-hour early shopping pass for exclusive limited archive items before general public release.',
    target_audience: 'Top 5% lifetime spenders with minimum $400 historical spend and >4 purchases in past 12 months (14,200 verified emails).',
    channel: 'Email',
    budget: 16500.00,
    kpi_projected: { conversionRate: 6.8, ctr: 8.5, roi: 5.8, cpa: 16.0, aov: 165.0 },
    creatives: [
      {
        id: 'cr-vip-01',
        name: 'Private Key VIP HTML Mailer',
        headline: 'Your Private Key: The Archive Vault is Open',
        primary_text: 'As a Gold Circle member, your personal 20% privilege code is active for 48 hours. Only 250 units reserved for this cohort.',
        cta_type: 'Unlock My Vault',
        asset_url: 'https://images.unsplash.com/photo-1513519245088-0e12902e5a38?w=800&q=80',
        aspect_ratio: 'Responsive Email Template',
        preview_type: 'EMAIL_NEWSLETTER',
        status: 'APPROVED_BY_BRAND'
      }
    ],
    targeting: {
      cohort_id: 'cohort_gold_circle_vip_14k',
      audience_size: 14200,
      suppression_lists: ['unsubscribed_all', 'bounced_hard_90d', 'recent_purchased_48h'],
      open_rate_expected: 48.5
    },
    financials: {
      total_budget: 16500.00,
      daily_spend_cap: 2800.00,
      spent_to_date: 11200.00,
      remaining_budget: 5300.00,
      burn_rate_pct: 67.8,
      pacing_mode: 'ACCELERATED_48H',
      cost_center_code: 'CC-GL-CRM-RETENTION-2026',
      currency: 'USD'
    },
    compliance: {
      brand_safety: 'VERIFIED_PASSED',
      legal_claims: 'VERIFIED_PASSED (Unsubscribe links & physical mailing address confirmed)',
      risk_tier: 'LOW_RISK',
      checklist: [
        { item: 'CAN-SPAM & GDPR one-click unsubscribe included', passed: true },
        { item: 'List hygiene suppression scrub verified', passed: true }
      ]
    },
    ad_network: {
      platform: 'SENDGRID_ENTERPRISE_API',
      remote_account_id: 'sg_mktg_live_01',
      remote_campaign_id: 'blast_99014',
      delivery_status: 'ACTIVE_DISPATCHING',
      pixel_status: 'HEALTHY'
    },
    flight_phases: [
      { phase_name: 'VIP Cohort Early Access', starts_at: new Date(now - 1 * dayMs).toISOString(), ends_at: new Date(now + 2 * dayMs).toISOString(), budget_pct: 100 }
    ],
    tracking: {
      destination_url: 'https://shop.bitloggers.com/vip-vault',
      utm_source: 'email',
      utm_medium: 'crm_newsletter',
      utm_campaign: 'vip_vault_early_access',
      utm_content: 'gold_circle_invitation_v1'
    }
  });

  await workflow.submitCampaign(camp3.campaign_id, marketer, { idempotencyKey: `synth-submit-${camp3.campaign_id}` });
  await workflow.makeDecision(camp3.campaign_id, reviewer1, {
    versionId: camp3.current_version_id,
    decision: 'APPROVED',
    reason: 'Approved. Segmented VIP audience with clean suppression lists and verified early access inventory reserve.'
  });

  const camp3Start = new Date(now - 1 * dayMs);
  const camp3End = new Date(now + 3 * dayMs);
  await workflow.scheduleCampaign(camp3.campaign_id, marketer, {
    versionId: camp3.current_version_id,
    channel: 'Email',
    startsAt: camp3Start.toISOString(),
    endsAt: camp3End.toISOString()
  });

  // ------------------------------------------------------------------
  // 4. CAMPAIGN 4: Weekend Flash Doorbuster Blitz
  // Status: Submitted (Awaiting Review) | Display ($18,500)
  // ------------------------------------------------------------------
  console.log('[SYNTHETIC DATA] Generating Campaign 4: Weekend Flash Doorbuster ($18,500 Submitted)...');
  const camp4 = await workflow.createCampaign(marketer, {
    title: 'Weekend Flash Doorbuster Blitz',
    objective: 'Drive urgency-driven conversion of active window shoppers with countdown timer banner ads over 72-hour weekend.',
    target_audience: 'Cart abandoners and users who viewed product pages >3 times in the last 7 days.',
    channel: 'Display',
    budget: 18500.00,
    kpi_projected: { conversionRate: 3.8, ctr: 2.9, roi: 3.4, cpa: 28.0, aov: 98.0 },
    creatives: [
      {
        id: 'cr-db-01',
        name: '72H Countdown HTML5 Leaderboard',
        headline: 'Going, Going, Gone — 72-Hour Flash Deals',
        primary_text: 'Up to 45% off surplus seasonal gear. Live countdown timer active. Grab doorbuster prices before midnight Sunday.',
        cta_type: 'Claim Deal',
        asset_url: 'https://images.unsplash.com/photo-1607082348824-0a96f2a4b9da?w=800&q=80',
        aspect_ratio: '728x90 Leaderboard & 300x250 Medium Rectangle',
        preview_type: 'HTML5_BANNER',
        status: 'PENDING_REVIEW'
      }
    ],
    targeting: {
      retargeting_window_days: 7,
      frequency_cap: '3 impressions per user per 24 hours',
      placements: ['Google Display Network Top Tier Publishers', 'Programmatic Private Marketplace']
    },
    financials: {
      total_budget: 18500.00,
      daily_spend_cap: 6100.00,
      spent_to_date: 0.00,
      remaining_budget: 18500.00,
      cost_center_code: 'CC-GL-PERF-RETARGETING-2026'
    },
    compliance: {
      risk_tier: 'MEDIUM_RISK',
      checklist: [
        { item: 'Inventory depth validated (>500 units)', passed: true },
        { item: 'Countdown timer synchronized to UTC server clock', passed: true }
      ]
    }
  });

  await workflow.submitCampaign(camp4.campaign_id, marketer, { idempotencyKey: `synth-submit-${camp4.campaign_id}` });

  // Thread discussion on Camp 4
  const c4Msg = await workflow.postDiscussionMessage(camp4.campaign_id, reviewer1, {
    content: 'Reviewing proposal. @Alice Cooper please verify that the countdown banner automatically degrades to standard sale creative once midnight UTC passes.',
    versionId: camp4.current_version_id
  });
  await workflow.postDiscussionMessage(camp4.campaign_id, marketer, {
    content: 'Configured! The Google Studio creative feed automatically swaps to "Sale Concluded" fallback image at 23:59:59 UTC.',
    parentMessageId: c4Msg.message_id,
    versionId: camp4.current_version_id
  });

  // ------------------------------------------------------------------
  // 5. CAMPAIGN 5: Creator Ambassador Partnership (High Budget Tier 2 Flag)
  // Status: ChangesRequested (Version 1 -> Version 2) | Influencer ($52,000)
  // ------------------------------------------------------------------
  console.log('[SYNTHETIC DATA] Generating Campaign 5: Creator Ambassador ($52,000 Changes Requested)...');
  const camp5 = await workflow.createCampaign(marketer, {
    title: 'Creator Ambassador Seasonal Partnership',
    objective: 'Co-create authentic video content with 12 prominent tech and lifestyle YouTubers to establish organic trust.',
    target_audience: 'Gen-Z and Millennial consumers seeking creator unboxing reviews and real-world durability tests.',
    channel: 'Influencer',
    budget: 52000.00,
    kpi_projected: { conversionRate: 3.2, ctr: 4.8, roi: 3.5, cpa: 36.0, aov: 140.0 }
  });

  await workflow.submitCampaign(camp5.campaign_id, marketer, { idempotencyKey: `synth-submit-${camp5.campaign_id}-v1` });
  await workflow.makeDecision(camp5.campaign_id, compliance, {
    versionId: camp5.current_version_id,
    decision: 'CHANGES_REQUESTED',
    reason: 'Rejected under compliance guideline: The creator contract templates lack mandatory FTC #ad sponsorship disclosure covenants. Additionally, at $52,000 this exceeds the Tier-2 $50k threshold and requires attached usage rights sign-off for digital whitelisting.'
  });

  // Marketer updates to Version 2 addressing feedback
  const camp5_v2 = await workflow.updateCampaign(camp5.campaign_id, marketer, {
    budget: 48500.00, // Trimmed budget to $48.5k to stay within agile Tier-1 allocation
    objective: 'Co-create authentic video content with 10 prominent creators, incorporating mandatory FTC #ad guidelines and 90-day digital whitelisting rights.',
    compliance: {
      risk_tier: 'LOW_RISK',
      ftc_covenants_attached: true,
      usage_rights_period_days: 90
    }
  });

  await workflow.postDiscussionMessage(camp5.campaign_id, compliance, {
    content: 'Please make sure all creator contracts include explicit clauses granting 90-day Spark Ads and Meta whitelisting rights.',
    versionId: camp5.current_version_id
  });
  await workflow.postDiscussionMessage(camp5.campaign_id, marketer, {
    content: 'Updated contracts in v2! Trimmed roster to 10 verified creators with full whitelisting rights and trimmed budget to $48,500.',
    versionId: camp5_v2.current_version_id
  });

  // ------------------------------------------------------------------
  // 6. CAMPAIGN 6: Crypto Cashback Loyalty Experiment
  // Status: Rejected | Clear Regulatory Compliance Justification
  // ------------------------------------------------------------------
  console.log('[SYNTHETIC DATA] Generating Campaign 6: Crypto Cashback Loyalty (Rejected)...');
  const camp6 = await workflow.createCampaign(marketer, {
    title: 'Crypto Cashback Loyalty Experiment',
    objective: 'Test 5% cryptocurrency token rebates at checkout to attract speculative Web3 consumers.',
    target_audience: 'Retail shoppers looking for speculative token incentives.',
    channel: 'Display',
    budget: 15000.00,
    kpi_projected: { conversionRate: 1.5, ctr: 1.2, roi: 1.8, cpa: 55.0, aov: 60.0 }
  });

  await workflow.submitCampaign(camp6.campaign_id, marketer, { idempotencyKey: `synth-submit-${camp6.campaign_id}` });
  await workflow.makeDecision(camp6.campaign_id, compliance, {
    versionId: camp6.current_version_id,
    decision: 'REJECTED',
    reason: 'Rejected under Corporate Policy POL-FIN-882: Cryptocurrency-denominated cashback carries regulatory ambiguity, tax reporting liabilities, and volatile brand risk in target jurisdictions.'
  });

  // ------------------------------------------------------------------
  // 7. CAMPAIGN 7: High-Intent Retargeting Wave
  // Status: Submitted (Awaiting Review) | Social ($22,000)
  // ------------------------------------------------------------------
  console.log('[SYNTHETIC DATA] Generating Campaign 7: Retargeting Wave ($22,000 Submitted)...');
  const camp7 = await workflow.createCampaign(marketer, {
    title: 'High-Intent Retargeting Wave',
    objective: 'Drive dynamic retargeting to abandoned cart shoppers with localized creative units and personalized checkout incentives.',
    target_audience: 'Users who added items to cart in the past 72 hours without completing purchase (38,000 pixel tracked users).',
    channel: 'Social',
    budget: 22000.00,
    kpi_projected: { conversionRate: 4.9, ctr: 5.5, roi: 5.0, cpa: 22.50, aov: 115.00 },
    creatives: [
      {
        id: 'cr-retarget-01',
        name: 'Saved Bag Reminder Carousel',
        headline: 'Your Cart is Waiting — Enjoy Free Express Shipping',
        primary_text: 'Complete your order within 24 hours to secure reserved inventory and complimentary priority fulfillment.',
        cta_type: 'Complete Checkout',
        preview_type: 'CAROUSEL_FEED'
      }
    ],
    financials: {
      total_budget: 22000.00,
      daily_spend_cap: 1100.00,
      spent_to_date: 0.00,
      remaining_budget: 22000.00,
      cost_center_code: 'CC-GL-PERF-RETARGET-2026'
    }
  });
  await workflow.submitCampaign(camp7.campaign_id, marketer, { idempotencyKey: `synth-submit-${camp7.campaign_id}` });

  // ------------------------------------------------------------------
  // 8. CAMPAIGN 8: Black Friday Super Savings Pass
  // Status: ChangesRequested | Display ($32,000)
  // ------------------------------------------------------------------
  console.log('[SYNTHETIC DATA] Generating Campaign 8: Black Friday Savings Pass ($32,000 Changes Requested)...');
  const camp8 = await workflow.createCampaign(marketer, {
    title: 'Black Friday Super Savings Pass',
    objective: 'Promote an early-access holiday shopping pass guaranteed across programmatic display placements.',
    target_audience: 'Broad international consumer audience with interest in tech accessories.',
    channel: 'Display',
    budget: 32000.00,
    kpi_projected: { conversionRate: 3.9, ctr: 3.1, roi: 4.0, cpa: 31.00, aov: 125.00 }
  });
  await workflow.submitCampaign(camp8.campaign_id, marketer, { idempotencyKey: `synth-submit-${camp8.campaign_id}` });
  await workflow.makeDecision(camp8.campaign_id, reviewer1, {
    versionId: camp8.current_version_id,
    decision: 'CHANGES_REQUESTED',
    reason: 'The proposed international targeting lacks regional pricing disclaimers for EU VAT compliance. Please attach localized terms.'
  });

  // ------------------------------------------------------------------
  // 9. CAMPAIGN 9: Q1 Global Brand Anthem
  // Status: Draft | Video ($55,000)
  // ------------------------------------------------------------------
  console.log('[SYNTHETIC DATA] Generating Campaign 9: Q1 Global Brand Anthem ($55,000 Draft)...');
  const camp9 = await workflow.createCampaign(marketer, {
    title: 'Q1 Global Brand Anthem',
    objective: 'Produce cinematic 60s and 30s anthem spots celebrating creator endurance stories for Q1 top-of-funnel brand awareness.',
    target_audience: 'Broad digital video consumers aged 18-35 across YouTube and connected TV platforms.',
    channel: 'Video',
    budget: 55000.00,
    kpi_projected: { conversionRate: 3.2, ctr: 3.8, roi: 4.1, cpa: 34.00, aov: 140.00 },
    creatives: [
      {
        id: 'cr-video-01',
        name: 'The Relentless Pursuit 60s Cut',
        headline: 'Built for the Unbroken Journey',
        primary_text: 'Discover the engineering philosophy that powers peak performance in every condition.',
        cta_type: 'Watch Full Film',
        preview_type: 'VIDEO_ANTHEM'
      }
    ],
    financials: {
      total_budget: 55000.00,
      daily_spend_cap: 3500.00,
      spent_to_date: 0.00,
      remaining_budget: 55000.00,
      cost_center_code: 'CC-GL-BRAND-MEDIA-2027'
    }
  });

  // ------------------------------------------------------------------
  // 10. CAMPAIGN 10: Affiliate Partner Spring Accelerator
  // Status: Draft | Affiliate ($12,500)
  // ------------------------------------------------------------------
  console.log('[SYNTHETIC DATA] Generating Campaign 10: Affiliate Accelerator ($12,500 Draft)...');
  const camp10 = await workflow.createCampaign(marketer, {
    title: 'Affiliate Partner Spring Accelerator',
    objective: 'Incentivize vetted affiliate blogs and review publications with elevated 18% tier commission rates for Spring product previews.',
    target_audience: 'Affiliate publishers, coupon aggregators, and tech editorial review sites.',
    channel: 'Affiliate',
    budget: 12500.00,
    kpi_projected: { conversionRate: 5.1, ctr: 4.6, roi: 5.4, cpa: 19.50, aov: 105.00 },
    financials: {
      total_budget: 12500.00,
      daily_spend_cap: 800.00,
      spent_to_date: 0.00,
      remaining_budget: 12500.00,
      cost_center_code: 'CC-GL-AFFILIATE-PARTNERS-2027'
    }
  });

  // ------------------------------------------------------------------
  // 11. CAMPAIGN 11: Summer Solar Eco Wave
  // Status: Scheduled | Search ($25,000)
  // ------------------------------------------------------------------
  console.log('[SYNTHETIC DATA] Generating Campaign 11: Summer Solar Eco Wave ($25,000 Scheduled)...');
  const camp11 = await workflow.createCampaign(marketer, {
    title: 'Summer Solar Eco Wave',
    objective: 'Drive commercial search intent adoption for clean outdoor solar charging systems and portable power storage.',
    target_audience: 'High-intent searchers querying solar generators, portable power stations, and off-grid camping accessories.',
    channel: 'Search',
    budget: 25000.00,
    kpi_projected: { conversionRate: 4.4, ctr: 5.1, roi: 4.5, cpa: 26.00, aov: 118.00 },
    creatives: [
      {
        id: 'cr-solar-01',
        name: 'Responsive Google Search Text Ad',
        headline: 'Portable Solar Power Systems | Instant $50 Eco Rebate',
        primary_text: 'Harness clean energy anywhere. Lightweight, rugged solar panels with rapid charge USB-C PD outputs.',
        cta_type: 'Order With Free Shipping',
        preview_type: 'SEARCH_TEXT_AD'
      }
    ],
    financials: {
      total_budget: 25000.00,
      daily_spend_cap: 1800.00,
      spent_to_date: 0.00,
      remaining_budget: 25000.00,
      cost_center_code: 'CC-GL-PERF-SEARCH-2026'
    }
  });
  await workflow.submitCampaign(camp11.campaign_id, marketer, { idempotencyKey: `synth-submit-${camp11.campaign_id}` });
  await workflow.makeDecision(camp11.campaign_id, reviewer1, {
    versionId: camp11.current_version_id,
    decision: 'APPROVED',
    reason: 'Approved for early summer commercial search slot. High seasonal intent search queries backed by inventory reservation.'
  });
  const camp11Start = new Date(now + 4 * dayMs);
  const camp11End = new Date(now + 11 * dayMs);
  await workflow.scheduleCampaign(camp11.campaign_id, marketer, {
    versionId: camp11.current_version_id,
    channel: 'Search',
    startsAt: camp11Start.toISOString(),
    endsAt: camp11End.toISOString()
  });

  // ------------------------------------------------------------------
  // 7. SEED TIMESCALEDB HYPERTABLE: 30-DAY DAILY & 24-HOUR HOURLY TELEMETRY
  // Full conversion funnels: Impressions -> Clicks -> Visits -> Leads -> Purchases
  // ------------------------------------------------------------------
  console.log('[SYNTHETIC DATA] Seeding TimescaleDB Hypertable with multi-tier conversion funnels...');
  const activeChannels = [
    { channel: 'Social', campId: camp1.campaign_id, baseImpr: 45000, convRate: 4.8, ctr: 5.4, roi: 4.9, cpa: 21.0, aov: 148.0 },
    { channel: 'Search', campId: camp2.campaign_id, baseImpr: 28000, convRate: 5.2, ctr: 6.8, roi: 6.2, cpa: 58.0, aov: 295.0 },
    { channel: 'Email', campId: camp3.campaign_id, baseImpr: 18000, convRate: 6.5, ctr: 7.9, roi: 5.5, cpa: 17.5, aov: 160.0 },
    { channel: 'Display', campId: camp4.campaign_id, baseImpr: 65000, convRate: 2.1, ctr: 1.8, roi: 2.4, cpa: 38.0, aov: 82.0 },
    { channel: 'Video', campId: camp9.campaign_id, baseImpr: 36000, convRate: 3.2, ctr: 3.8, roi: 4.1, cpa: 34.0, aov: 140.0 }
  ];

  for (let dayOffset = 30; dayOffset >= 0; dayOffset--) {
    const timestamp = new Date(now - dayOffset * dayMs).toISOString();

    for (const item of activeChannels) {
      const jitter = (Math.sin(dayOffset * 0.65 + item.channel.length) * 0.18);
      const impressions = Math.round(item.baseImpr * (1 + jitter));
      const ctr = Math.max(0.8, (item.ctr * (1 + jitter * 0.8)).toFixed(2));
      const clicks = Math.round(impressions * (ctr / 100));
      const convRate = Math.max(0.5, (item.convRate * (1 + jitter * 0.6)).toFixed(2));
      const conversions = Math.round(clicks * (convRate / 100));
      const cpa = Math.max(5.0, (item.cpa * (1 - jitter * 0.7)).toFixed(2));
      const spend = Math.round(conversions * cpa);
      const aov = Math.max(20.0, (item.aov * (1 + jitter * 0.4)).toFixed(2));
      const revenue = Math.round(conversions * aov);
      const roi = spend > 0 ? Number(((revenue - spend) / spend).toFixed(2)) : item.roi;

      await db.query(
        `INSERT INTO kpi_metric_snapshots 
         (snapshot_id, recorded_at, campaign_id, channel, conversion_rate, ctr, roi, cpa, aov, is_actual, impressions, clicks, spend, conversions, revenue)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
         ON CONFLICT DO NOTHING`,
        [
          `synth-snap-${item.channel}-${dayOffset}`,
          timestamp,
          item.campId,
          item.channel,
          convRate,
          ctr,
          roi,
          cpa,
          aov,
          true,
          impressions,
          clicks,
          spend,
          conversions,
          revenue
        ]
      );
    }
  }

  // ------------------------------------------------------------------
  // 8. SEED 24-HOUR HOURLY TELEMETRY (For Live Circuit Breaker & Real-time Graph)
  // Demonstrates hourly spend dynamics and peak-time performance
  // ------------------------------------------------------------------
  console.log('[SYNTHETIC DATA] Seeding 24-Hour Hourly Telemetry Stream for real-time monitoring...');
  for (let hourOffset = 24; hourOffset >= 0; hourOffset--) {
    const hourTimestamp = new Date(now - hourOffset * hourMs).toISOString();
    const hourOfDay = new Date(now - hourOffset * hourMs).getHours();

    // Diurnal curve: peaks at 14:00 (lunch) and 20:00 (evening shopping)
    const diurnalFactor = 0.4 + 0.6 * Math.sin(((hourOfDay - 6) / 24) * 2 * Math.PI);
    const hourlyImpr = Math.round(3200 * Math.max(0.2, diurnalFactor));
    const hourlyCtr = 5.4;
    const hourlyClicks = Math.round(hourlyImpr * (hourlyCtr / 100));
    const hourlyConversions = Math.round(hourlyClicks * 0.052);
    const hourlySpend = Math.round(hourlyConversions * 21.5);
    const hourlyRevenue = Math.round(hourlyConversions * 148.0);
    const hourlyRoi = hourlySpend > 0 ? Number(((hourlyRevenue - hourlySpend) / hourlySpend).toFixed(2)) : 4.8;

    await db.query(
      `INSERT INTO kpi_metric_snapshots 
       (snapshot_id, recorded_at, campaign_id, channel, conversion_rate, ctr, roi, cpa, aov, is_actual, impressions, clicks, spend, conversions, revenue)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
       ON CONFLICT DO NOTHING`,
      [
        `synth-hourly-${hourOffset}`,
        hourTimestamp,
        camp1.campaign_id,
        'Social',
        5.2,
        hourlyCtr,
        hourlyRoi,
        21.5,
        148.0,
        true,
        hourlyImpr,
        hourlyClicks,
        hourlySpend,
        hourlyConversions,
        hourlyRevenue
      ]
    );
  }

  console.log('✅ [SYNTHETIC DATA] Enterprise MarTech synthetic data generation complete!');
  return {
    campaignCount: 11,
    activeCampaigns: [camp1.campaign_id, camp3.campaign_id, camp11.campaign_id],
    success: true
  };
}
