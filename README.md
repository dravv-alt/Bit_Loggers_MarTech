# Bit Loggers — Campaign Management & Intelligence Platform (CampaignGrid)

> **Domain:** Marketing Technology (MarTech) & Enterprise Campaign Governance  
> **Frontend:** Cross-Platform Flutter Application (Web, Desktop, iOS & Android) adhering to Apple Human Interface Guidelines (HIG)  
> **Backend:** Modular Monolith with Event-Driven Background Processing (Node.js, Express, PostgreSQL & TimescaleDB)  
> **Quality Attributes:** ACID Consistency, Idempotency, Concurrency Control, Zero Silent Overwrites, Audit Governance

---

## ⚡ Executive Summary & Vision

**Bit Loggers (CampaignGrid)** is a mission-critical campaign management and marketing intelligence platform designed for high-velocity marketing teams and rigorous campaign reviewers. It resolves the core operational challenges of multi-channel marketing:

1. **Eliminating Silent Overwrites & State Corruption**: Dual-layer concurrency combining temporary exclusive edit leases (`EDIT_LOCK`) with optimistic version headers (`expected_version`).
2. **Strict Multi-Tier Governance**: Non-negotiable review checkpoints with mandatory written justifications and cryptographic self-approval prevention (marketers cannot approve their own campaigns).
3. **Collision-Free Multi-Channel Scheduling**: Internal marketing calendar backed by conflict-detection engines ensuring no overlapping flights on the same channel window.
4. **Resilient Transactional Messaging**: Transactional Outbox pattern providing at-least-once durable notification dispatch with exponential backoff and deduplication keys (`event_id:recipient:channel`).
5. **Human Interface Craftsmanship**: Client interface built from the ground up in Flutter adhering to **Apple Human Interface Guidelines (HIG) Foundations**—featuring dual-layer ambient depth, organic squircles, Inset Grouped Tables, and tabular numerals.

---

## 🏛️ System Architecture

Bit Loggers operates as an event-driven modular monolith backed by relational persistence for transactional state and TimescaleDB hypertables for time-series analytics, audit logs, and diagnostic events.

```mermaid
flowchart TD
    subgraph Clients["Presentation Tier (Flutter Multi-Platform)"]
        WEB["Flutter Web CanvasKit"]
        DESK["Windows Desktop"]
        MOB["iOS / Android Mobile"]
    end

    subgraph Gateway["API & Middleware Tier (Express.js)"]
        AUTH["Auth & RBAC Middleware\nMarketer vs Reviewer vs Admin"]
        IDEMP["Idempotency Filter\nSHA-256 Payload Hash + 7-Day Store"]
        CORR["Correlation ID & Diagnostic Tracer"]
    end

    subgraph CoreServices["Domain Service Layer"]
        WORKFLOW["Workflow & Governance Engine\nStatus Transitions & Reason Validation"]
        SCHEDULER["Flight Scheduling Engine\nConflict Detector & Version Guard"]
        LEASE["Concurrency Manager\nHeartbeat Edit Leases (120s TTL)"]
        AI_STRAT["Gemini Argon AI Strategist\nBrief & KPI Synthesis"]
    end

    subgraph AsyncTier["Asynchronous Dispatch Tier"]
        OUTBOX_WORKER["Transactional Outbox Worker\nFOR UPDATE SKIP LOCKED"]
        RETRY["Exponential Backoff Engine\nMax 5 Attempts + DLQ"]
        DISPATCH["Multi-Channel Dispatcher\nEmail (Mock SMTP) / In-App / Push"]
    end

    subgraph Storage["Persistence Tier (PostgreSQL + TimescaleDB)"]
        RELATIONAL[("PostgreSQL Relational Tables\nusers, campaigns, campaign_versions\napproval_decisions, schedules, edit_locks")]
        HYPERTABLES[("TimescaleDB Hypertables\naudit_events (Append-Only)\ncampaign_version_history\nkpi_metric_snapshots\ndiagnostic_logs")]
    end

    Clients -->|"REST API / HTTPS"| Gateway
    Gateway --> CoreServices
    CoreServices -->|"ACID Transaction"| RELATIONAL
    CoreServices -->|"Audit & Metrics Stream"| HYPERTABLES
    CoreServices -->|"Atomic Event Enqueue"| AsyncTier
    AsyncTier -->|"Poll Pending Events"| RELATIONAL
    AsyncTier -->|"Diagnostic Trace"| HYPERTABLES
```

---

## 🔄 Core User & System Flows

### 1. Proposal Drafting & Gemini Argon AI Assist Flow

```mermaid
sequenceDiagram
    autonumber
    actor Marketer
    participant Flutter as Flutter App
    participant API as Express API
    participant AI as Gemini Argon AI
    participant DB as PostgreSQL

    Marketer->>Flutter: Enter Campaign Wizard & Request Draft
    Flutter->>API: POST /campaigns (Acquire initial state)
    API->>DB: INSERT into campaigns (Status: Draft)
    DB-->>API: Campaign created
    API-->>Flutter: 201 Created (campaign_id)

    Marketer->>Flutter: Request AI Proposal Brief
    Flutter->>API: POST /campaigns/:id/ai-assist
    API->>AI: Synthesize Brief & Target KPIs
    alt AI Service Available
        AI-->>API: Brief, Channel Mix & Projected KPIs
        API-->>Flutter: 200 OK (Generated Proposal Draft)
    else AI Service Down / Offline
        API-->>Flutter: 200 OK (Fallback Rule-Based Baseline)
    end

    Marketer->>Flutter: Edit Budget & Performance Targets
    Flutter->>API: POST /campaigns/:id/versions (expected_version: 0)
    API->>DB: INSERT campaign_versions (v1.0 snapshot)
    API->>DB: UPDATE campaigns (Status: Submitted)
    API->>DB: INSERT outbox_events (CAMPAIGN_SUBMITTED)
    API-->>Flutter: 200 OK (v1.0 Immutable Snapshot)
```

---

### 2. Governance Review & Multi-Tier Approval Flow

```mermaid
sequenceDiagram
    autonumber
    actor Reviewer
    actor Marketer
    participant Flutter as Flutter App
    participant API as Express API
    participant DB as PostgreSQL / TimescaleDB
    participant Outbox as Outbox Worker

    Reviewer->>Flutter: Open Review Queue & Inspect Proposal
    Reviewer->>Flutter: Select "Approve" (Provide Written Justification)
    Flutter->>API: POST /campaigns/:id/versions/:vid/decisions
    
    rect rgb(240, 248, 255)
    Note over API,DB: ACID Transaction Scope
    API->>DB: Check self-approval: reviewer_id != owner_id
    alt Self-Approval Attempted
        API-->>Flutter: 403 Forbidden (Self-approval violation)
    else Valid Governance
        API->>DB: Verify version_id matches current submitted version
        API->>DB: INSERT approval_decisions (Decision: APPROVED, Reason)
        API->>DB: UPDATE campaigns (Status: Approved)
        API->>DB: INSERT audit_events (Hypertable ledger)
        API->>DB: INSERT outbox_events (CAMPAIGN_APPROVED)
        API-->>Flutter: 200 OK (Decision Committed)
    end
    end

    par Async Dispatch
        Outbox->>DB: Claim PENDING outbox events (SKIP LOCKED)
        Outbox->>Marketer: Dispatch Email Notification (Mock SMTP)
        Outbox->>DB: UPDATE outbox_events (Status: PROCESSED)
    end
```

---

### 3. Collision-Free Flight Scheduling Flow

```mermaid
sequenceDiagram
    autonumber
    actor Marketer
    participant Flutter as Flutter App
    participant API as Express API
    participant DB as PostgreSQL

    Marketer->>Flutter: Select Approved Campaign & Desired Date Window
    Flutter->>API: POST /campaigns/:id/schedules
    
    rect rgb(245, 255, 245)
    Note over API,DB: Schedule Validation & Conflict Guard
    API->>DB: Verify campaign status is APPROVED
    API->>DB: Verify version_id matches the approved decision_id
    API->>DB: SELECT schedules WHERE channel = target AND dates OVERLAP
    alt Conflict Detected (Slot Occupied)
        API-->>Flutter: 409 Conflict (SCHEDULE_BLOCKED: Slot Occupied)
    else Slot Clear & Approved
        API->>DB: INSERT schedules (Status: ACTIVE)
        API->>DB: UPDATE campaigns (Status: Scheduled)
        API->>DB: INSERT audit_events (FLIGHT_SCHEDULED)
        API-->>Flutter: 201 Created (Flight Confirmed)
    end
    end
```

---

## 🗄️ Relational & Time-Series Data Architecture

```mermaid
erDiagram
    users ||--o{ campaigns : owns
    users ||--o{ approval_decisions : reviews
    users ||--o{ schedules : schedules
    campaigns ||--|{ campaign_versions : contains
    campaigns ||--o{ edit_locks : holds
    campaigns ||--o{ discussions : anchors
    campaign_versions ||--o| approval_decisions : evaluated_by
    campaign_versions ||--o{ schedules : booked_for
    campaigns ||--o{ audit_events : logs
    campaigns ||--o{ kpi_metric_snapshots : measures
    campaigns ||--o{ outbox_events : dispatches

    users {
        string user_id PK
        string name
        string email UK
        string role "marketer | reviewer | admin"
        timestamptz created_at
    }

    campaigns {
        string campaign_id PK
        string title
        string owner_id FK
        string status "Draft|Submitted|Approved|ChangesRequested|Rejected|Scheduled"
        string current_version_id FK
        timestamptz updated_at
    }

    campaign_versions {
        string version_id PK
        string campaign_id FK
        int version_no
        string channel
        numeric budget
        jsonb kpi_projected
        jsonb kpi_actual
        text ai_summary
        timestamptz created_at
    }

    approval_decisions {
        string decision_id PK
        string campaign_id FK
        string version_id FK,UK
        string reviewer_id FK
        string decision_type "APPROVED|CHANGES_REQUESTED|REJECTED"
        text reason "Mandatory Justification"
        timestamptz created_at
    }

    schedules {
        string schedule_id PK
        string campaign_id FK
        string version_id FK
        string decision_id FK
        string channel
        timestamptz starts_at
        timestamptz ends_at
        string status "ACTIVE|CANCELLED|COMPLETED"
    }

    edit_locks {
        string campaign_id PK,FK
        string user_id FK
        timestamptz acquired_at
        timestamptz expires_at
    }

    outbox_events {
        string event_id PK
        string event_type
        jsonb payload
        string status "PENDING|PROCESSING|PROCESSED|FAILED"
        int attempts
        int max_attempts
        timestamptz next_retry_at
        timestamptz processed_at
    }

    audit_events {
        string event_id PK
        timestamptz created_at PK
        string campaign_id
        string version_id
        string actor_id
        string event_type
        text summary
        jsonb details
    }

    kpi_metric_snapshots {
        string snapshot_id PK
        timestamptz recorded_at PK
        string campaign_id
        string channel
        numeric conversion_rate
        numeric ctr
        numeric roi
        numeric cpa
        numeric aov
        boolean is_actual
    }
```

---

## 🎨 Presentation Layer: Apple Human Interface Guidelines (HIG)

The client presentation layer is implemented entirely in **Flutter (Dart 3.5+)** and strictly incorporates the **Apple Human Interface Guidelines (HIG) Foundations**:

```mermaid
flowchart LR
    HIG["Apple HIG Foundations"]
    
    HIG --> M["Materials & Elevation\nDual-layer ambient depth\n2.5% occlusion + 4.0% key light\nZero flat wireframe borders"]
    HIG --> T["Typography\nSF Pro dynamic type hierarchy\nTabular numerals for all metrics\nOptical letter tracking"]
    HIG --> C["Components & Structure\nInset Grouped Tables (0.5pt)\nSegmented Controls\nModal sheets with 36x5pt grabber"]
    HIG --> G["Gestures & Ergonomics\nMinimum 44x44pt hit targets\nTactile ink feedback\nAdaptive switches"]
    HIG --> W["Human Writing & Copy\nZero engineering leaks\nSentence-case microcopy\nActionable blameless alerts"]
```

### Complete Screen Implementation Portfolio (12 Screens)

| Screen | File Path | Key Capabilities |
| :--- | :--- | :--- |
| **Main Navigation** | [`lib/main.dart`](file:///c:/Users/bhavv/OneDrive/Desktop/Dravvya(4th%20Sem)/Projects/Bit_Loggers/bit_loggers_app/lib/main.dart) | Apple Inset Grouped Tab Bar, user profile switcher, real-time sync pill badge with tabular figures. |
| **Kanban Pipeline** | [`lib/screens/kanban_screen.dart`](file:///c:/Users/bhavv/OneDrive/Desktop/Dravvya(4th%20Sem)/Projects/Bit_Loggers/bit_loggers_app/lib/screens/kanban_screen.dart) | Visual lifecycle columns (`Draft` → `Scheduled`), portfolio spend burn tracker, channel flight distribution. |
| **Campaign Wizard** | [`lib/screens/campaign_wizard_screen.dart`](file:///c:/Users/bhavv/OneDrive/Desktop/Dravvya(4th%20Sem)/Projects/Bit_Loggers/bit_loggers_app/lib/screens/campaign_wizard_screen.dart) | 4-step draft builder, interactive channel cards, Vitruvian budget pacing bar, projected KPI inputs. |
| **Campaign Dossier** | [`lib/screens/campaign_detail_screen.dart`](file:///c:/Users/bhavv/OneDrive/Desktop/Dravvya(4th%20Sem)/Projects/Bit_Loggers/bit_loggers_app/lib/screens/campaign_detail_screen.dart) | Immutable proposal header, governance decision sheet, version filter chips, context-anchored discussions with `@mentions`. |
| **Flight Calendar** | [`lib/screens/calendar_screen.dart`](file:///c:/Users/bhavv/OneDrive/Desktop/Dravvya(4th%20Sem)/Projects/Bit_Loggers/bit_loggers_app/lib/screens/calendar_screen.dart) | Monthly grid with channel occupancy dots, weekly Gantt-style flight lanes, collision conflict checker. |
| **Analytics & KPIs** | [`lib/screens/analytics_screen.dart`](file:///c:/Users/bhavv/OneDrive/Desktop/Dravvya(4th%20Sem)/Projects/Bit_Loggers/bit_loggers_app/lib/screens/analytics_screen.dart) | Live telemetry charts (Conv Rate, CTR, ROI, CPA, AOV), projected vs. actual delta badges, channel yield matrix. |
| **Sync Hub & Outbox** | [`lib/screens/sync_hub_screen.dart`](file:///c:/Users/bhavv/OneDrive/Desktop/Dravvya(4th%20Sem)/Projects/Bit_Loggers/bit_loggers_app/lib/screens/sync_hub_screen.dart) | Offline toggle simulation, transactional outbox inspection, exponential retry triggers, SMTP failure toggling. |
| **Audit Ledger** | [`lib/screens/audit_screen.dart`](file:///c:/Users/bhavv/OneDrive/Desktop/Dravvya(4th%20Sem)/Projects/Bit_Loggers/bit_loggers_app/lib/screens/audit_screen.dart) | Tamper-resistant append-only governance trail, actor role filter, JSON payload inspector modal sheet. |
| **System Diagnostics** | [`lib/screens/diagnostics_screen.dart`](file:///c:/Users/bhavv/OneDrive/Desktop/Dravvya(4th%20Sem)/Projects/Bit_Loggers/bit_loggers_app/lib/screens/diagnostics_screen.dart) | Standard diagnostic event viewer (`CAMPAIGN_SUBMITTED`, `VERSION_CONFLICT`), latency monitors. |
| **Notifications** | [`lib/screens/notifications_screen.dart`](file:///c:/Users/bhavv/OneDrive/Desktop/Dravvya(4th%20Sem)/Projects/Bit_Loggers/bit_loggers_app/lib/screens/notifications_screen.dart) | Multi-channel alert stream, unread indicators, channel filter chips, batch mark-as-read. |
| **Gemini Argon AI** | [`lib/screens/gemini_argon_screen.dart`](file:///c:/Users/bhavv/OneDrive/Desktop/Dravvya(4th%20Sem)/Projects/Bit_Loggers/bit_loggers_app/lib/screens/gemini_argon_screen.dart) | Editorial AI strategist studio, verified snapshot locking, lease controls, audience profile generation. |
| **Architecture Runner** | [`lib/screens/test_runner_screen.dart`](file:///c:/Users/bhavv/OneDrive/Desktop/Dravvya(4th%20Sem)/Projects/Bit_Loggers/bit_loggers_app/lib/screens/test_runner_screen.dart) | In-app LLD Section 14 test runner (14/14 architectural scenarios verified with visual pass badges). |

---

## 🧪 Architecture Acceptance Matrix (14/14 Verified)

All 14 test scenarios specified in the Low-Level Design (LLD Section 14) are implemented and continuously verified:

| Test ID | Scenario Description | Quality Attribute | Expected Behavior | Status |
| :---: | :--- | :---: | :--- | :---: |
| **T-01** | Approve V1. Edit budget to create V2. Schedule V2. | **QA-01 Data Consistency** | Blocked with `409 SCHEDULE_BLOCKED`; audit event recorded. | **✅ PASS** |
| **T-02** | Approve without a reason, or whitespace only. | **QA-01 Data Consistency** | Rejected with `422 REASON_REQUIRED`; nothing stored. | **✅ PASS** |
| **T-03** | Request changes without a written explanation. | **QA-01 Data Consistency** | Rejected with `422 REASON_REQUIRED`. | **✅ PASS** |
| **T-04** | Reject a proposal without an explanation reason. | **QA-01 Data Consistency** | Rejected with `422 REASON_REQUIRED`. | **✅ PASS** |
| **T-05** | Approve V3 using V1's version ID on different campaign. | **QA-01 Data Consistency** | Rejected with `422 VERSION_MISMATCH`. | **✅ PASS** |
| **T-06** | Marketer attempts to approve own campaign proposal. | **QA-03 Security & Privacy** | Denied with `403 FORBIDDEN` (Self-approval prevented). | **✅ PASS** |
| **T-07** | Reviewer approves; verify full audit trail recorded. | **QA-03 Security & Privacy** | Decision, actor ID, and ISO timestamp immutably logged. | **✅ PASS** |
| **T-08** | Re-send submission with same `Idempotency-Key`. | **QA-02 Reliability & Recovery** | Exactly one entity created; original response replayed. | **✅ PASS** |
| **T-09** | Two reviewers approve the same version concurrently. | **QA-01 & QA-02** | First succeeds; second receives `409 NOT_AWAITING_REVIEW`. | **✅ PASS** |
| **T-10** | Two users attempt to acquire the edit lease simultaneously. | **QA-01 Data Consistency** | Second denied; active leaseholder identity returned. | **✅ PASS** |
| **T-11** | Save proposal with stale `expected_version` header. | **QA-01 Data Consistency** | Rejected with `409 VERSION_CONFLICT`; no silent overwrite. | **✅ PASS** |
| **T-12** | Simulated external email outage during approval. | **QA-02 Reliability & Recovery** | Approval commits; message enqueued in outbox for retry. | **✅ PASS** |
| **T-13** | Gemini AI service unavailable during brief synthesis. | **QA-02 Reliability & Recovery** | Fallback baseline generated; workflow uninterrupted. | **✅ PASS** |
| **T-14** | Process restarts and crashes. | **QA-02 Reliability & Recovery** | All entities, versions, decisions, and outbox survive restart. | **✅ PASS** |

---

## 📋 Project Status & Capability Checklist

### ✅ Completed & Production Ready

- [x] **Relational Core Schema**: PostgreSQL DDL for Users, Campaigns, Versions, Decisions, Schedules, Edit Locks, and Outbox.
- [x] **TimescaleDB Hypertables**: Append-only partition tables for `audit_events`, `campaign_version_history`, `diagnostic_logs`, and `kpi_metric_snapshots`.
- [x] **Concurrency & Lease Control**: Heartbeat-renewed exclusive edit locks (`120s` TTL) and `expected_version` optimistic locking.
- [x] **Transactional Outbox Worker**: Background processor using `FOR UPDATE SKIP LOCKED`, exponential backoff retry schedule (`1s`, `2s`, `4s`, `8s`), and dead-letter queue.
- [x] **Full LLD Architecture Test Suite**: 14 automated tests verifying all edge cases and failure modes (`npm test`).
- [x] **Complete Flutter Client Migration**: Unified codebase for Web, Windows Desktop, and Mobile.
- [x] **Apple HIG Foundations Design System**:
  - [x] Dual-layer ambient depth (`appleCardShadow`) replacing all 1px flat wireframe borders (`borderSage`).
  - [x] Tabular numerals (`FontFeature.tabularFigures()`) across all currencies, metrics, and dates.
  - [x] Inset Grouped Tables with `0.5pt` hairlines (`separator`).
  - [x] iOS Segmented Controls replacing raw pill buttons.
  - [x] Modal bottom sheets with standard `36x5pt` grabbers.
  - [x] Strict 44x44pt minimum interactive hit targets.
  - [x] Purge of all engineering tokens (`[FR-xx]`, `[ACID]`, `[SKIP LOCKED]`, `[HYPERTABLE]`) from client UI.
- [x] **AI Proposal Synthesis**: Gemini Argon integration with graceful offline fallback.
- [x] **Multi-Channel Creative Mockups**: High-fidelity visual previews for Social, Search SERP, Email Newsletter, and Display Ads.

### 🔮 Roadmap & Upcoming Enhancements

- [ ] **Production SMTP & Push Adapters**: Integration with AWS SES / SendGrid and Firebase Cloud Messaging (FCM) beyond the durable mock SMTP transport.
- [ ] **Multi-Signature Approval Hierarchy (Tier 2)**: Dual-reviewer sign-off flow for campaigns with budgets exceeding \$50,000.
- [ ] **TimescaleDB Continuous Aggregations**: Automated background materialization of hourly and daily KPI rollups.
- [ ] **Redis Read-Through Cache**: High-density cache layer for sub-5ms Kanban dashboard rendering under high concurrent read loads.
- [ ] **Advanced Audience Segment Importer**: Direct CSV/Parquet bulk ingestion into target audience cohorts.

---

## 🚀 Getting Started

### Prerequisites
- **Node.js**: v18.0.0 or higher
- **PostgreSQL / TimescaleDB**: PostgreSQL 14+ with TimescaleDB extension enabled (or Docker Desktop)
- **Flutter SDK**: v3.24+ (with Dart 3.5+)

### 1. Database Setup (Docker or Local Postgres)
If using Docker, start the pre-configured TimescaleDB container:
```bash
docker run -d --name bitloggers-timescaledb \
  -p 5438:5432 \
  -e POSTGRES_USER=bitloggers \
  -e POSTGRES_PASSWORD=bitloggers_password \
  -e POSTGRES_DB=bit_loggers \
  timescale/timescaledb:latest-pg15
```

### 2. Backend Server & Architecture Tests
```bash
# Install root dependencies
npm install

# Run the 14/14 automated LLD architecture test suite
npm test

# Start the Express backend server (serves API on http://localhost:3000)
npm start
```

### 3. Running the Flutter Application
```bash
# Navigate to the Flutter client directory
cd bit_loggers_app

# Fetch Flutter dependencies
flutter pub get

# Run on Chrome (Web)
flutter run -d chrome

# Run on Windows Desktop
flutter run -d windows

# Run on connected Mobile Device or Emulator
flutter run
```

---

## 🔒 Security, RBAC & Governance Invariants

1. **Self-Approval Ban**: Marketer identities cannot approve proposals they authored. Violations fail closed with `403 FORBIDDEN`.
2. **Mandatory Explanations**: Any approval, rejection, or change request requires a non-empty written reason. Whitespace-only submissions fail with `422 REASON_REQUIRED`.
3. **Strict Version Immutability**: Historical versions are sealed; any update produces a new sequential version number (`v2.0`, `v3.0`).
4. **Schedule Integrity**: Flights can only be booked against currently approved versions. If a new draft is submitted, older schedules cannot be duplicated or corrupted.
5. **Idempotency Guarantee**: Submitting proposals with identical `Idempotency-Key` headers will return the cached original response without side effects.

---

## 📄 License & Attribution
Proprietary software developed by the **Bit Loggers** engineering team. All rights reserved.
Built in compliance with the **Apple Human Interface Guidelines Foundations**.
