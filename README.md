# Bit Loggers — Campaign Management & Intelligence Platform

> **Domain:** Marketing Technology (MarTech)  
> **Product:** Mobile-First Campaign Platform (Flutter & Web)  
> **Users:** Marketers & Campaign Reviewers  
> **Architecture Style:** Modular Monolith with Event-Driven Background Processing (ACID Persistence, Transactional Outbox & Flutter Mobile/Desktop/Web Frontend)

---

## ⚡ Overview & Vision

**Bit Loggers** is an intelligent, auditable, and version-aware campaign management platform built to unify the marketing lifecycle across proposal drafting, reviewer governance, scheduling, multi-channel alerting, and performance intelligence.

### Complete Flutter Migration
The entire presentation layer is now built in **Flutter (Dart 3.5+)**, providing native performance, smooth animations, and a unified codebase across:
- **Android & iOS Mobile** (Optimized touch targets, bottom navigation, gestures)
- **Windows Desktop** (Desktop window frame, keyboard navigation)
- **Web** (Release bundle compiled with CanvasKit / HTML renderer and served directly by the server)

---

## 📱 How to Run the Flutter Application

### Option A: Run Natively via Flutter CLI
```bash
# Navigate to the Flutter app directory
cd bit_loggers_app

# Run on Chrome / Web
flutter run -d chrome

# Run on Windows Desktop
flutter run -d windows

# Run on connected Android / Emulator
flutter run
```

### Option B: Run Fullstack Server (Serves Flutter Web Release)
```bash
# Starts Express server on http://localhost:3000 serving the Flutter Web Release
npm start
```
Open **[http://localhost:3000](http://localhost:3000)** in your browser to interact with the Flutter application!

### Option C: Run Automated Architecture Tests
```bash
# 1. Run Backend LLD Architecture Tests (14/14 tests)
npm test

# 2. Run Flutter App Widget & Smoke Tests
cd bit_loggers_app
flutter test
```

---

## 🏛️ 5 Core Pillars & Capabilities

| Pillar | Capabilities |
| :--- | :--- |
| **Pillar 1: Workflow & Access** | • Flutter Kanban board with role filters (`Draft`, `Submitted`, `ChangesRequested`, `Approved`, `Scheduled`, `Rejected`)<br>• Backend RBAC & Self-Approval Prevention (Marketer cannot approve own proposal)<br>• Review/Approval workflow with **mandatory written justification reason**<br>• Atomic scheduling validation |
| **Pillar 2: Intelligence & Analytics** | • 5 Mandatory MarTech KPIs: **Conversion Rate (%)**, **Click-Through Rate (CTR %)**, **Return on Investment (ROI x)**, **Cost Per Acquisition (CPA $)**, **Average Order Value (AOV $)**<br>• Projected vs Actual comparisons with delta percentage indicators<br>• Channel yield breakdowns (Social, Email, Search, Display, Influencer, Video) |
| **Pillar 3: Governance & Integrity** | • Internal Marketing Calendar with flight timeline & collision conflict checks<br>• Strict immutable version history & visual snapshot diff viewer<br>• Append-only tamper-resistant audit registry<br>• Hybrid concurrency: Temporary Edit Leases (`EDIT_LOCK`) + Optimistic Version Concurrency (`expected_version`) |
| **Pillar 4: Collaboration & AI** | • In-context discussion streams with replies and `@mentions`<br>• Multi-channel notifications: In-App, Push alerts, and durable Email dispatch<br>• Transactional Outbox pattern with exponential backoff retry and deduplication key (`event_id:recipient:channel`)<br>• **Gemini Argon AI Proposal Strategist**: Generates marketing briefs, audience profiles, and forecast KPIs with mandatory human-in-the-loop verification |
| **Pillar 5: Reliability & Testing** | • ACID-compliant durable persistence (survives process restarts)<br>• Idempotent submission endpoint (`Idempotency-Key` header with database uniqueness constraints)<br>• Standard diagnostic vocabulary logging (`CAMPAIGN_SUBMITTED`, `CAMPAIGN_APPROVED`, `VERSION_CONFLICT`, `SCHEDULE_BLOCKED`, etc.)<br>• Complete automated architecture test suite (14/14 tests pass) |

---

## 🧪 Architecture Acceptance Matrix (LLD Section 14)

All 14 tests defined in the Low-Level Design (LLD) specification are implemented and verified:

| Test ID | Test Scenario | Target Quality Attribute | Expected Result | Status |
| :---: | :--- | :---: | :--- | :---: |
| **T-01** | Approve V1. Edit budget to create V2. Schedule V2. | **QA-01 Data Consistency** | `409 SCHEDULE_BLOCKED; event recorded` | **✅ PASS** |
| **T-02** | Approve without a reason, or with whitespace only | **QA-01 Data Consistency** | `422 REASON_REQUIRED; nothing stored` | **✅ PASS** |
| **T-03** | Request changes without a reason | **QA-01 Data Consistency** | `422 REASON_REQUIRED` | **✅ PASS** |
| **T-04** | Reject without a reason | **QA-01 Data Consistency** | `422 REASON_REQUIRED` | **✅ PASS** |
| **T-05** | Approve V3 using V1's version_id on different campaign | **QA-01 Data Consistency** | `422 VERSION_MISMATCH` | **✅ PASS** |
| **T-06** | Marketer calls approve; marketer approves own campaign | **QA-03 Security & Privacy** | `403 FORBIDDEN (Self-approval violation)` | **✅ PASS** |
| **T-07** | Reviewer approves; verify audit trail | **QA-03 Security & Privacy** | `Decision, actor, and timestamp recorded` | **✅ PASS** |
| **T-08** | Repeat submission with same idempotency key after lost response | **QA-02 Reliability & Recovery** | `One submission; original response returned` | **✅ PASS** |
| **T-09** | Two reviewers approve the same version concurrently | **QA-01 & QA-02** | `First commit succeeds; second gets 409 NOT_AWAITING_REVIEW` | **✅ PASS** |
| **T-10** | Two users request the edit lease simultaneously | **QA-01 Data Consistency** | `Second denied; current active editor shown` | **✅ PASS** |
| **T-11** | Save proposal with stale `expected_version` | **QA-01 Data Consistency** | `409 VERSION_CONFLICT; no silent overwrite` | **✅ PASS** |
| **T-12** | Email provider down during approval | **QA-02 Reliability & Recovery** | `Approval succeeds; event retried from outbox with backoff` | **✅ PASS** |
| **T-13** | Gemini AI unavailable during proposal creation | **QA-02 Reliability & Recovery** | `Manual workflow continues uninterrupted` | **✅ PASS** |
| **T-14** | Restart the application | **QA-02 Reliability & Recovery** | `Campaigns, versions, decisions and outbox survive restart` | **✅ PASS** |

---

## 🚀 Running the Application

### 1. Run Automated Test Suite
To verify all 14 architectural scenarios from the command line:
```bash
npm test
# or
node tests/run-all-tests.js
```

### 2. Start Backend & Fullstack Application
The production server serves both the Express REST API and the bundled React web application:
```bash
npm start
```
Open **[http://localhost:3000](http://localhost:3000)** in your browser.

### 3. Development Mode
To run Vite with hot-reloading:
```bash
# Terminal 1: Run Backend API
npm run server

# Terminal 2: Run Vite Dev Client
npm run dev:client
```

---

## 📱 Mobile-First Experience
In the top header, click the **"Mobile Frame" / "Desktop View"** toggle to switch between responsive widescreen mode and a realistic mobile mockup (iPhone 15 Pro, 390x844). Both Marketer and Reviewer flows are fully optimized for touchscreen ergonomics and high-density information architecture.

