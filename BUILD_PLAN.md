# BNI 121 Conclave — Complete Build Plan

> **For AI models:** Read this file AND `BNI_1to1_ENGINE_REFERENCE.md` (same directory)
> before writing any code. This plan covers *what to build*. The engine reference covers
> *how the matching algorithm works*.

---

## 0. Architecture Overview

| Surface | Tech | Who uses it |
|---|---|---|
| **Mobile app** (this repo) | Flutter + Dart | Members & Captains only |
| **Web dashboard** | Separate repo (TBD) | Admin only |
| **Backend** | Shared (Firebase / Supabase / custom — TBD) | Both apps hit the same backend |

> The mobile app does NOT have admin features. Admin gets a web dashboard (separate project).
> However, the **backend data model and APIs must support both** — so this plan defines
> the full backend schema and the mobile app screens/logic.

### App Identity
- **Name**: `121 Conclave` (display as "BNI 121 Conclave" with logo)
- **Splash footer**: "in association with Manuen Infotech"
- **Logo**: Will be provided by the client

---

## 1. User Roles (Mobile App Only)

| Role | Description |
|---|---|
| **Member** | A registered participant who rotates between tables each round. |
| **Captain** | A participant designated as a fixed table anchor for a specific conclave. Same view as member + can see table members' attendance. |

> Admin is web-only. The mobile app has NO admin screens.
> Captain vs Member is assigned **per conclave** by the admin, and can be switched
> before the conclave starts. Once started → roles are frozen.

---

## 2. Mobile App Screens & Flow

### 2.1 Splash Screen
```
App opens → Splash screen
  - BNI 121 Conclave logo (center)
  - Footer: "in association with Manuen Infotech"
  - Auto-navigate after 2-3 seconds
```

### 2.2 Auth Flow
```
Splash → Login / Register screen

LOGIN:
  - Email or Phone + Password
  - "Forgot password" link
  - "Register" link

REGISTER (enrollment):
  Step 1 — Credentials:
    - Email OR Phone number
    - Password + confirm password
    - If email → send verification link
    - If phone → send OTP → verify

  Step 2 — Profile (after verification):
    - Name (required)
    - Phone number / Email (autofilled from step 1, ask for the other)
    - Business name (required)
    - Business category (required, dropdown from the 74 BNI categories)
    - Chapter (optional, free text with suggestions)
    - Location (required, free text — normalized: lowercase, trimmed, 
      so "Guntur", "guntur", "GUNTUR", "  guntur  " all match)
    - Country (default: India)

  → On success → navigate to Conclaves List
```

### 2.3 Conclaves List (Home Screen)
```
After login → Conclaves List

Shows three sections/tabs:
  1. ONGOING — conclaves currently running (status = RUNNING)
  2. UPCOMING — conclaves accepting registration or announced (status = OPEN / ANNOUNCED)
  3. PAST — completed conclaves (status = COMPLETED)

Each conclave card shows:
  - Conclave name
  - Venue / location
  - Date & time
  - Status badge (Upcoming / Live / Completed)
  - Registration status (Open / Closed)
  - "Register" button (if open and user hasn't registered)
  - "View" button (if user is registered)

Pull-to-refresh to sync with server.
```

### 2.4 Conclave Registration
```
User taps "Register" on an upcoming conclave
  → Confirmation screen showing:
    - Conclave details (name, date, venue)
    - User's profile summary (name, business, category)
    - "Confirm Registration" button
  → On success → show "Registered" badge on card
```

### 2.5 Pre-Conclave View (Registered, Not Started)
```
User taps "View" on a conclave they've registered for (before it starts)
  → Shows:
    - Conclave info (name, date, venue, chief guests)
    - User's role: "Member" or "Captain" (assigned by admin)
    - Status: "Waiting to start"
    - If captain: show assigned table number
```

### 2.6 Active Conclave View (RUNNING) — Core Screen

This is the most important screen. It must work **offline**.

```
┌──────────────────────────────────────┐
│  ROUND 3 of 6          ⏱ 08:32     │  ← active round + countdown timer
├──────────────────────────────────────┤
│  TABLE 12                           │
│  Captain: 👑 Ganesh Reddy           │
│  ─────────────────────────────────── │
│  1. Sravan Naidu    [Boutique]    ✅ │  ← attendance status
│  2. Kartheek Rao    [Restaurant]  ✅ │
│  3. Bhanu Prasad    [Caterer]     ⏳ │
│  4. Prakash Reddy   [Real Estate] ✅ │
│  5. You (Samba)     [Software]    ✅ │
│  6. Dinesh Kumar    [Jeweller]    ⏳ │
├──────────────────────────────────────┤
│  [✅ Mark Attendance]               │  ← one-tap, once per round
├──────────────────────────────────────┤
│  REFERRALS THIS ROUND               │
│  [+ Give Referral]                  │  ← opens picker from tablemates
│  • You → Sravan Naidu    ✓ saved    │
│  • You → Kartheek Rao   ✓ saved    │
│  • Bhanu Prasad → You   ✓ received │
├──────────────────────────────────────┤
│  ⚡ Offline — will sync when online │  ← sync status bar
└──────────────────────────────────────┘
```

#### Member View:
- Active round number + total rounds
- Countdown timer (calculated from round config)
- Table number + list of all tablemates (name, business category)
- **Mark Attendance** button (once per round, cannot undo)
- **Give Referral** button → select one or more tablemates → confirm
  - Referrals are **immutable** after creation (can't modify/delete)
  - A can give multiple referrals to different people at the same table
- Sync status indicator (online/offline, pending sync count)

#### Captain View:
- Everything the member sees, PLUS:
- Can see each tablemate's attendance status (marked / not marked)
- Captain's own attendance is auto-marked (they're always at their table)

#### Round Timer Logic:
```
totalRoundTime = 15 minutes (fixed ceiling)
activeTime = personsPerTable * 1.5 minutes
transitionTime = totalRoundTime - activeTime

Example: P=8 → 12 min active + 3 min transition
Example: P=6 → 9 min active + 6 min transition
```
- Timer counts down the active portion.
- When active time ends → visual + audio alert ("Round complete! Move to next table")
- Transition time → show "Moving to next table..." with countdown.
- Alert admin (via backend) when round completes.

### 2.7 Post-Conclave View (COMPLETED)
```
User taps "View" on a completed conclave
  → Shows:
    - Conclave summary (name, date, rounds)
    - Per-round status:
      - Round N: Table X, Attended: ✅/❌, Synced: ✅/⏳
    - Referrals Summary:
      - Given: list of (person, round, table)
      - Received: list of (person, round, table)
      - Total referrals count
    - Overall sync status
```

### 2.8 Profile Screen
```
Accessible from nav/drawer:
  - View/edit profile (name, phone, email, business name, category, chapter, location)
  - Logout button
  - App version
```

---

## 3. Referral System (Detailed)

### 3.1 What is a referral?
Person A at a table can promise person B: "I'll give you a business lead." This is a
**referral from A to B**. It's a one-directional promise logged in the app.

### 3.2 Rules
- A referral is created by the GIVER (A gives to B).
- A can give referrals to **multiple** people at the same table in the same round.
- B automatically sees "received referral from A" on their side.
- If A→B and B→A both happen, both parties' referral count increases by 1 each.
- Referrals are **immutable** — once created, they cannot be modified or deleted.
- Referrals can only be created **during the active round** (within the time limit).
- Referrals are **scoped to a round + table** — you can only refer people at your current table.

### 3.3 Data Model
```
Referral {
  id: string (UUID)
  conclaveId: string
  roundNumber: int
  tableNumber: int
  giverId: string (user who promises the business)
  receiverId: string (user who will receive the business)
  createdAt: timestamp
  syncedAt: timestamp? (null if not yet synced)
}
```

### 3.4 Offline Behavior
- Referrals are stored **locally first** (SQLite / Hive / Isar).
- Each referral gets a client-generated UUID.
- When connectivity is available → batch-sync to server.
- Server deduplicates by UUID (idempotent upsert).
- UI shows sync status per referral (✓ synced / ⏳ pending).

---

## 4. Offline-First Architecture (CRITICAL)

### 4.1 The Problem
- 300-400 members at a venue with **no reliable internet**.
- Attendance marking and referral creation MUST work offline.
- Data must sync to server when connectivity returns.

### 4.2 Strategy

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│  Mobile App  │────▸│  Local DB    │────▸│  Sync Queue │──── when online ───▸ Server
│  (Flutter)   │     │  (SQLite/    │     │  (pending    │
│              │◂────│   Hive/Isar) │     │   writes)    │
└─────────────┘     └──────────────┘     └─────────────┘
```

#### What gets cached locally:
1. **Schedule** — the full round-by-round table assignments (downloaded once when conclave
   starts or when user opens the conclave). This is the biggest chunk — but it's read-only
   and only needs to be fetched once.
2. **Attendance records** — created offline, synced later.
3. **Referrals** — created offline, synced later.
4. **User profile** — cached on login.
5. **Conclave metadata** — name, config, status, timing.

#### What gets synced TO server (write queue):
1. Attendance: `{ conclaveId, roundNumber, userId, tableNumber, markedAt, clientId }`
2. Referrals: `{ id, conclaveId, roundNumber, tableNumber, giverId, receiverId, createdAt }`

#### Sync mechanism:
- Background sync service that runs periodically (every 30s when app is open).
- On each sync attempt:
  1. Push all pending writes (attendance + referrals) to server.
  2. Pull latest state (new referrals received, conclave status updates).
- Idempotent writes — server uses client-generated IDs to deduplicate.
- Show sync status in UI: "X items pending sync", "Last synced: 2 min ago".

#### Conflict resolution:
- Attendance: last-write-wins (but practically there are no conflicts — one user, one mark per round).
- Referrals: UUID-based dedup, no conflicts possible (append-only).

### 4.3 Admin Live Stats (Best Effort)
- If any members have connectivity, their synced data shows up on admin dashboard in near-real-time.
- Admin can see partial stats as data trickles in.
- Consider: local mesh / QR-code-based sync as a stretch goal (but not MVP).

---

## 5. Round Timing System

### 5.1 Configuration (set by admin)
```
personsPerTable (P): set by admin (default 7)
totalRoundDuration: 15 minutes (fixed)
activeTime: P * 1.5 minutes (the actual meeting time)
transitionTime: totalRoundDuration - activeTime (time to move to next table)
```

### 5.2 Timer Behavior
- Timer starts when admin advances to a new round (server pushes round start timestamp).
- Mobile app calculates remaining time from: `roundStartTime + activeTime - now`.
- Even if offline, the timer runs locally based on the downloaded `roundStartTime`.
- When active time expires:
  - Visual alert on member's app ("Round complete!")
  - Audio/haptic notification
  - Transition countdown begins
- When transition time expires:
  - New round info loads (next table assignment)
  - No new referrals can be created for the previous round

### 5.3 Round Lifecycle
```
Admin clicks "Start Round N"
  → Server records roundStartTime
  → Mobile apps (when synced) pick up the timestamp
  → Timer counts down activeTime
  → Alert: "Round complete, move to next table"
  → Timer counts down transitionTime
  → Next round ready

Admin can also manually advance rounds (override timer).
```

---

## 6. Backend Data Model

> This model supports BOTH the mobile app and the admin web dashboard.

### 6.1 Core Entities

```
User {
  id: string (UUID)
  name: string
  email: string?
  phone: string?
  passwordHash: string
  businessName: string
  businessCategory: string (from the 74 BNI categories)
  chapter: string?
  location: string (normalized: lowercase, trimmed)
  country: string (default "India")
  emailVerified: bool
  phoneVerified: bool
  createdAt: timestamp
  updatedAt: timestamp
}

Admin {
  id: string
  name: string
  email: string
  passwordHash: string
  createdAt: timestamp
  // Admins are manually created — no self-registration
}

Conclave {
  id: string (UUID)
  name: string
  venueLocation: string
  date: date
  startTime: timestamp?
  endTime: timestamp?
  chiefGuests: string[] (optional)
  personsPerTable: int (P, default 7)
  roundCount: int (R, within 4-8)
  autoLogoutHours: float (default 5)
  seed: int (for deterministic scheduling)
  status: enum (DRAFT, REGISTRATION_OPEN, REGISTRATION_CLOSED, 
                SNAPSHOTTED, SCHEDULED, LOCKED, RUNNING, COMPLETED, CANCELLED)
  isRegistrationOpen: bool
  createdAt: timestamp
  updatedAt: timestamp
  snapshotAt: timestamp?
  lockedAt: timestamp?
  startedAt: timestamp?
  completedAt: timestamp?
  currentRound: int? (null if not started, 1..R when running)
  currentRoundStartedAt: timestamp? (for timer sync)
}

ConclaveRegistration {
  id: string
  conclaveId: string
  userId: string
  role: enum (MEMBER, CAPTAIN)  // assigned by admin, default MEMBER
  tableNumber: int?  // assigned when captain, null for members
  registeredAt: timestamp
  isActive: bool  // based on login status + auto-logout
  lastActiveAt: timestamp?
}

Snapshot {
  conclaveId: string
  userId: string
  // Frozen active list at conclave start
}

Seat {
  id: string
  conclaveId: string
  roundNumber: int
  tableNumber: int
  userId: string
  isCaptain: bool
  // Unique constraint: (conclaveId, roundNumber, userId) — C3
}

Attendance {
  id: string (client-generated UUID)
  conclaveId: string
  roundNumber: int
  tableNumber: int
  userId: string
  markedAt: timestamp
  syncedAt: timestamp?
}

Referral {
  id: string (client-generated UUID)
  conclaveId: string
  roundNumber: int
  tableNumber: int
  giverId: string
  receiverId: string
  createdAt: timestamp
  syncedAt: timestamp?
}

RoundState {
  conclaveId: string
  roundNumber: int
  startedAt: timestamp
  activeTimeMinutes: float
  transitionTimeMinutes: float
  status: enum (PENDING, ACTIVE, TRANSITION, COMPLETED)
}
```

### 6.2 Indexes & Constraints
```
User: unique (email), unique (phone)
ConclaveRegistration: unique (conclaveId, userId)
Seat: unique (conclaveId, roundNumber, userId)  — enforces C3
Seat: index (conclaveId, roundNumber, tableNumber)
Attendance: unique (conclaveId, roundNumber, userId)  — one mark per round
Referral: unique (id)  — client UUID for dedup
Referral: index (conclaveId, roundNumber, giverId)
Referral: index (conclaveId, roundNumber, receiverId)
```

---

## 7. Conclave Lifecycle (Full State Machine)

```
DRAFT
  │
  ▼ (admin toggles registration)
REGISTRATION_OPEN  ◄──► REGISTRATION_CLOSED
  │                        │
  ▼ (admin clicks "Start") ▼
SNAPSHOTTED (freeze active user list)
  │
  ▼ (validation gate passes — see engine reference V1-V12)
SCHEDULED (schedule generated, admin reviews)
  │
  ▼ (admin locks)
LOCKED (roles + schedule frozen)
  │
  ▼ (admin clicks "Begin Round 1")
RUNNING (rounds in progress, currentRound = 1..R)
  │
  ▼ (all rounds complete)
COMPLETED
  
Any pre-LOCKED state → CANCELLED (admin cancels)
```

### Admin actions per state:
| State | Admin can... |
|---|---|
| DRAFT | Edit conclave details, toggle registration |
| REGISTRATION_OPEN | See registrations, assign roles, toggle registration |
| REGISTRATION_CLOSED | Same as above, close registration |
| SNAPSHOTTED | See snapshot, adjust captains (V8), re-snapshot if needed |
| SCHEDULED | Review schedule, manual overrides (re-validates), lock |
| LOCKED | Start round 1 |
| RUNNING | Advance rounds, see live stats, see attendance, see referrals |
| COMPLETED | View final reports |

---

## 8. Matching Engine (Dart Port)

The engine from the reference project must be ported to Dart. See
`BNI_1to1_ENGINE_REFERENCE.md` for the complete algorithm. Key files to port:

| TypeScript source | Dart equivalent | Purpose |
|---|---|---|
| `engine/rng.ts` | `lib/engine/rng.dart` | Mulberry32 PRNG (MUST match exactly) |
| `engine/types.ts` | `lib/engine/models.dart` | Participant, ConclaveConfig, Schedule, etc. |
| `engine/validation.ts` | `lib/engine/validation.dart` | Validation gate V1-V12, W1-W2 |
| `engine/captains.ts` | `lib/engine/captains.dart` | Auto/random captain selection |
| `engine/matcher.ts` | `lib/engine/matcher.dart` | Schedule generation algorithm |
| `engine/audit.ts` | `lib/engine/audit.dart` | Independent constraint verifier |

### Critical: Cross-platform determinism
The **Mulberry32 PRNG must produce identical output** in Dart and TypeScript for the same
seed. This ensures:
- Admin generates schedule on web dashboard → same schedule the mobile app displays.
- Use Dart's bitwise operators carefully (Dart ints are 64-bit; must mask to 32-bit).

### Where does the engine run?
- **Primary**: On the backend (server generates the schedule when admin clicks "Generate").
- **Secondary**: The schedule is sent to mobile apps as data (mobile does NOT regenerate).
- **Audit**: Can run on mobile for local verification (optional, nice-to-have).

---

## 9. API Endpoints (Backend)

### Auth
```
POST /auth/register          — email/phone + password + profile
POST /auth/verify-email      — verify email token
POST /auth/verify-otp        — verify phone OTP
POST /auth/login             — email/phone + password → JWT + refresh token
POST /auth/refresh           — refresh token → new JWT
POST /auth/logout            — invalidate session
```

### User
```
GET    /users/me             — get own profile
PUT    /users/me             — update profile
```

### Conclaves (user-facing)
```
GET    /conclaves            — list conclaves (ongoing, upcoming, past)
POST   /conclaves/:id/register  — register for a conclave
GET    /conclaves/:id        — get conclave details + user's role + schedule
GET    /conclaves/:id/schedule  — get full schedule (round-by-round assignments)
GET    /conclaves/:id/my-schedule  — get only my assignments per round
```

### Sync (offline-first endpoints)
```
POST   /conclaves/:id/sync   — batch sync endpoint
  Request body:
    {
      attendance: [ { id, roundNumber, tableNumber, markedAt } ],
      referrals: [ { id, roundNumber, tableNumber, receiverId, createdAt } ]
    }
  Response:
    {
      syncedAttendanceIds: [...],
      syncedReferralIds: [...],
      newReferralsReceived: [ { id, roundNumber, giverId, ... } ],
      conclaveStatus: { currentRound, currentRoundStartedAt, status },
      errors: [...]
    }
```

### Conclaves (admin-facing, web dashboard)
```
POST   /admin/conclaves                    — create conclave
PUT    /admin/conclaves/:id                — edit conclave
PUT    /admin/conclaves/:id/status         — change status
PUT    /admin/conclaves/:id/registration   — toggle registration open/closed
GET    /admin/conclaves/:id/registrations  — list registered users
PUT    /admin/conclaves/:id/roles          — assign/switch captain/member roles
POST   /admin/conclaves/:id/snapshot       — take active user snapshot
POST   /admin/conclaves/:id/generate       — run validation + generate schedule
POST   /admin/conclaves/:id/lock           — lock schedule
POST   /admin/conclaves/:id/start-round    — start/advance round
GET    /admin/conclaves/:id/dashboard      — live stats (registrations, attendance, referrals)
GET    /admin/conclaves/:id/schedule       — full schedule for review
PUT    /admin/conclaves/:id/schedule/override — manual seat override
```

---

## 10. Flutter App Architecture

### 10.1 Recommended Stack
```
State Management:  Riverpod (or BLoC)
Local Database:    Isar or Hive (for offline data)
Networking:        Dio (with retry + offline queue)
Auth:              Firebase Auth OR custom JWT
Push Notifications: Firebase Cloud Messaging (for round alerts)
Architecture:      Clean Architecture (data / domain / presentation layers)
```

### 10.2 Proposed Folder Structure
```
lib/
├── main.dart
├── app.dart                          # MaterialApp, routing, theme
├── core/
│   ├── constants/
│   │   ├── app_constants.dart        # app name, defaults
│   │   └── business_categories.dart  # the 74 BNI categories
│   ├── theme/
│   │   └── app_theme.dart
│   ├── network/
│   │   ├── api_client.dart           # Dio setup
│   │   └── sync_service.dart         # offline sync queue
│   ├── storage/
│   │   ├── local_db.dart             # Isar/Hive setup
│   │   └── secure_storage.dart       # tokens
│   └── utils/
│       └── location_normalizer.dart  # lowercase, trim for location matching
│
├── engine/                           # Dart port of the matching engine
│   ├── rng.dart                      # Mulberry32 PRNG
│   ├── models.dart                   # Participant, ConclaveConfig, Schedule, etc.
│   ├── validation.dart               # Validation gate V1-V12, W1-W2
│   ├── captains.dart                 # Auto/random captain selection
│   ├── matcher.dart                  # Schedule generation
│   └── audit.dart                    # Independent verifier
│
├── features/
│   ├── auth/
│   │   ├── data/                     # repositories, data sources
│   │   ├── domain/                   # entities, use cases
│   │   └── presentation/            # screens, widgets
│   │       ├── splash_screen.dart
│   │       ├── login_screen.dart
│   │       └── register_screen.dart
│   │
│   ├── conclaves/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │       ├── conclaves_list_screen.dart
│   │       ├── conclave_detail_screen.dart
│   │       └── conclave_register_screen.dart
│   │
│   ├── active_conclave/
│   │   ├── data/
│   │   │   ├── attendance_local_source.dart
│   │   │   ├── referral_local_source.dart
│   │   │   └── schedule_cache.dart
│   │   ├── domain/
│   │   │   ├── attendance_model.dart
│   │   │   ├── referral_model.dart
│   │   │   └── round_timer.dart
│   │   └── presentation/
│   │       ├── active_round_screen.dart    # THE core screen
│   │       ├── widgets/
│   │       │   ├── round_timer_widget.dart
│   │       │   ├── table_members_list.dart
│   │       │   ├── attendance_button.dart
│   │       │   ├── referral_section.dart
│   │       │   └── sync_status_bar.dart
│   │       └── captain_view_extras.dart    # captain-only additions
│   │
│   ├── post_conclave/
│   │   └── presentation/
│   │       ├── conclave_summary_screen.dart
│   │       ├── round_status_list.dart
│   │       └── referral_report_screen.dart
│   │
│   └── profile/
│       └── presentation/
│           └── profile_screen.dart
│
└── shared/
    ├── widgets/                       # reusable UI components
    └── models/                        # shared data models
```

---

## 11. Offline Sync Implementation Detail

### 11.1 Local Tables (Isar/Hive)

```dart
// Cached from server (read-only locally)
CachedSchedule { conclaveId, roundNumber, tableNumber, userId, isCaptain, userName, businessCategory }
CachedConclaveState { conclaveId, status, currentRound, currentRoundStartedAt, personsPerTable, roundCount }

// Created locally, synced to server (write queue)
PendingAttendance { clientId, conclaveId, roundNumber, tableNumber, userId, markedAt, synced: bool }
PendingReferral { clientId, conclaveId, roundNumber, tableNumber, giverId, receiverId, createdAt, synced: bool }

// Received from server during sync
ReceivedReferral { id, conclaveId, roundNumber, tableNumber, giverId, giverName, createdAt }
```

### 11.2 Sync Flow
```
Every 30 seconds (when app is foregrounded):
  1. Collect all PendingAttendance where synced == false
  2. Collect all PendingReferral where synced == false
  3. POST /conclaves/:id/sync with the batch
  4. On success:
     a. Mark synced items as synced = true
     b. Store any newReferralsReceived
     c. Update CachedConclaveState (currentRound, status, etc.)
  5. On network failure:
     a. Silently skip, retry next cycle
     b. Increment "pending sync" counter in UI
```

### 11.3 Schedule Download
```
When user opens a conclave that is LOCKED or RUNNING:
  1. Check if CachedSchedule exists for this conclaveId
  2. If not → fetch GET /conclaves/:id/my-schedule
  3. Cache all rounds locally
  4. This only needs to happen ONCE (schedule is frozen after lock)
```

---

## 12. Round Timer Implementation

```dart
class RoundTimer {
  final int personsPerTable;
  final DateTime roundStartedAt;
  
  // Total round = 15 minutes always
  static const totalMinutes = 15.0;
  
  // Active meeting time = P * 1.5 minutes
  double get activeMinutes => personsPerTable * 1.5;
  
  // Transition time = remaining
  double get transitionMinutes => totalMinutes - activeMinutes;
  
  // Current phase
  RoundPhase get currentPhase {
    final elapsed = DateTime.now().difference(roundStartedAt).inSeconds;
    if (elapsed < activeMinutes * 60) return RoundPhase.active;
    if (elapsed < totalMinutes * 60) return RoundPhase.transition;
    return RoundPhase.completed;
  }
  
  // Remaining seconds in current phase
  int get remainingSeconds { ... }
}

enum RoundPhase { active, transition, completed }
```

- Timer ticks locally — no server dependency.
- `roundStartedAt` comes from `CachedConclaveState.currentRoundStartedAt`.
- Even offline, the timer is accurate (based on device clock).
- During `transition` phase → disable referral creation for the previous round.
- Notifications/alerts at phase transitions.

---

## 13. Push Notifications

Use Firebase Cloud Messaging (FCM) for:
1. **Round started** — "Round 3 has started! Go to Table 12"
2. **Round ending soon** — "2 minutes remaining in this round"
3. **Round completed** — "Round 3 complete. Move to your next table"
4. **Conclave started** — "The conclave has begun!"
5. **Conclave completed** — "The conclave is over. Check your referral report!"

> These are best-effort (require connectivity). The app timer handles the UX
> independently even without push notifications.

---

## 14. Phased Delivery Plan

### Phase 1 — Foundation (Week 1-2)
- [ ] Flutter project setup, folder structure, theme, navigation
- [ ] Splash screen
- [ ] Auth flow (login, register, email/phone verification)
- [ ] Profile screen
- [ ] Core networking (Dio + API client)
- [ ] Local database setup (Isar/Hive)
- [ ] Business categories constant file

### Phase 2 — Conclaves List & Registration (Week 2-3)
- [ ] Conclaves list screen (ongoing, upcoming, past tabs)
- [ ] Conclave detail screen
- [ ] Register for conclave flow
- [ ] Pre-conclave view (role display, waiting state)

### Phase 3 — Engine Port (Week 3-4)
- [ ] Port Mulberry32 PRNG to Dart (with cross-platform tests)
- [ ] Port validation gate (V1-V12, W1-W2)
- [ ] Port captain auto-selection
- [ ] Port matcher algorithm
- [ ] Port audit verifier
- [ ] Unit tests matching TypeScript output

### Phase 4 — Active Conclave Core (Week 4-6) ⭐ MOST CRITICAL
- [ ] Active round screen (table view, timer, members list)
- [ ] Attendance marking (local-first)
- [ ] Referral creation (local-first)
- [ ] Captain view extras (see members' attendance)
- [ ] Round timer with phase transitions and alerts
- [ ] Offline data storage for attendance + referrals

### Phase 5 — Offline Sync (Week 6-7)
- [ ] Sync queue implementation
- [ ] Batch sync endpoint integration
- [ ] Schedule caching
- [ ] Sync status UI (pending count, last synced)
- [ ] Conflict resolution / dedup
- [ ] Background sync service

### Phase 6 — Post-Conclave & Reports (Week 7-8)
- [ ] Post-conclave summary screen
- [ ] Per-round status display (attended, synced)
- [ ] Referral report (given, received, totals)

### Phase 7 — Polish & Hardening (Week 8-9)
- [ ] Push notifications (FCM)
- [ ] Error handling and edge cases
- [ ] Auto-logout timer
- [ ] UI polish, animations, loading states
- [ ] Performance testing (300+ users)
- [ ] Offline stress testing

### Phase 8 — Backend (Parallel Track)
- [ ] User auth endpoints
- [ ] Conclave CRUD endpoints
- [ ] Registration endpoints
- [ ] Schedule generation endpoint (runs engine server-side)
- [ ] Sync endpoint
- [ ] Admin dashboard endpoints
- [ ] Real-time stats aggregation

---

## 15. Open Decisions (Need User Input)

| # | Question | Options | Impact |
|---|---|---|---|
| 1 | **Backend tech** | Firebase (Firestore + Auth + Functions) vs Supabase vs Custom (Node/Go) | Affects auth flow, sync architecture, hosting |
| 2 | **State management** | Riverpod vs BLoC vs Provider | Affects code structure |
| 3 | **Local DB** | Isar vs Hive vs SQLite (drift) | Affects offline storage implementation |
| 4 | **Auth provider** | Firebase Auth vs custom JWT | Affects registration flow (OTP, email verification) |
| 5 | **Schedule generation location** | Server-only vs server+mobile | If mobile, engine port is critical; if server-only, mobile just displays cached data |
| 6 | **Total round time** | Fixed 15 min or configurable by admin? | Affects timer logic |
| 7 | **Referral time window** | Only during active phase, or also during transition? | Affects referral creation logic |

---

*This plan was generated on 2026-07-03 based on the full requirements document provided
by the user. Reference: `BNI_1to1_ENGINE_REFERENCE.md` for engine algorithm details.*
