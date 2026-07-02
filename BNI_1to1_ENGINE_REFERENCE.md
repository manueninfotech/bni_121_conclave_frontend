# BNI 1-to-1 Conclave — Complete Engine & Spec Reference

> **Purpose of this document:** This file captures the *complete* understanding of the
> reference web project at `/Users/eb/Documents/web/bni-1-1`. Any AI model working on the
> Flutter app (`conclave_1_2_1`) should read this file first and build according to it.
> **Do NOT modify the reference web project.**

---

## 1. What Is This?

A **BNI (Business Network International) Conclave** is a large networking event where
members do structured **1-to-1 meetings**. The goal: over several rounds, each person
sits at different tables so they meet as many *unique* people as possible, while **never
sharing a table with someone in the same business category**.

The reference project is a **Vite + React + Tailwind v4 + TypeScript** web app that
implements a **matching engine** (the schedule generator) plus a **tester UI** to
exercise and visually verify it. The engine is pure TypeScript with zero React/DOM
dependencies, designed to be unit-tested in isolation.

---

## 2. Domain Glossary

| Term | Meaning |
|---|---|
| **Participant / Member** | A registered person. Has a mandatory **business category**. |
| **Captain** | A participant designated as a fixed table anchor. Stays at the same physical table for ALL rounds. Captains are a **disjoint pool** from rotating members. |
| **Business category** | The member's profession (e.g. "Real Estate", "Software Development"). The core diversity dimension — controlled dropdown, NOT free text. |
| **Conclave** | A single event instance with its own config, snapshot, and schedule. |
| **Round** | One rotation cycle. Every active participant is seated at exactly one table. |
| **Table** | A seat group of capacity **P** (1 captain + up to P-1 members). |
| **Snapshot** | The frozen list of active users captured when the conclave starts. Immutable after capture. |
| **Schedule** | The complete set of (round → table → occupants) assignments, precomputed at start. |
| **Lock** | The moment the schedule and roles become immutable; round 1 can then begin. |

---

## 3. Roles & Capabilities

### 3.1 Admin
- CRUD participants (name, phone, business name, business category **required**, location, optional chapter).
- Designate / undesignate captains; switch captain ⇄ member **before lock**.
- Configure conclave: `personsPerTable (P)`, `roundCount (R)`, `autoLogoutHours`.
- Start the conclave (take the active snapshot).
- Trigger schedule generation; review and manually override any seat (with re-validation).
- Lock the conclave and run rounds (advance round, optional timer).
- After lock: roles and schedule are **frozen**.

### 3.2 Member (regular user)
- Log in (becomes active; auto-logout timer starts).
- View own schedule: per round → table number, captain, and tablemates.
- (Optional) mark attendance / acknowledge.

---

## 4. Configurable Parameters

| Param | Symbol | Default | Notes |
|---|---|---|---|
| Persons per table (incl. captain) | `P` | 7 | Must be >= 2 |
| Round count | `R` | — | Within [minRounds, maxRounds] |
| Min rounds | — | 4 | |
| Max rounds | — | 8 | |
| Auto-logout hours | `autoLogoutHours` | 5 | Must be > 0 |
| Tables | `T` | *derived* | `T = ceil(A / P)` where A = active snapshot count |
| Seed | `seed` | — | For deterministic, reproducible schedules |

**Captains required = T.** Admin must designate exactly T captains before generation.

---

## 5. Constraint System (The Matching Problem)

This is a **Social Golfer / round-robin scheduling problem** with a hard coloring constraint.

### 5.1 Per-conclave setup
1. Snapshot active users → `A`
2. `T = ceil(A / P)` tables
3. Verify designated captains == T
4. Members pool `M = A - T` (everyone not a captain)

### 5.2 Constraints

| ID | Constraint | Type | Rationale |
|---|---|---|---|
| **C1** | No two people at the same table share a **business category** (captain included) | **HARD** | Table diversity is the whole point |
| **C2** | A given member-pair should not share a table more than once across rounds | **SOFT** | Maximize unique meetings; relaxed only if forced |
| **C3** | Every active member seated **exactly once per round** | **HARD** | No clashes / no gaps |
| **C4** | Table occupancy <= P | **HARD** | Physical capacity |
| **C5** | Captains stay at their assigned table every round | **HARD** | Fixed-anchor model |

### 5.3 Objective
**Maximize the number of distinct people each member meets** over all R rounds, subject to
C1, C3-C5, while minimizing C2 violations (repeat pairings, including repeat
member-captain meetings).

---

## 6. Validation Gate (runs BEFORE schedule generation)

Generation is **blocked** with actionable messages if any hard check fails.

### 6.1 Data-integrity (V1-V3)
- **V1**: Every participant has a non-empty business category.
- **V2**: Participant IDs are unique.
- **V3**: Captain IDs must all be valid existing participants (and unique list, no duplicates).

### 6.2 Configuration (V4-V6)
- **V4**: `P >= 2`.
- **V5**: `minRounds <= R <= maxRounds` (default 4-8).
- **V6**: `autoLogoutHours > 0`.

### 6.3 Capacity (V7-V9)
- **V7**: `A >= P` (enough people for one table) AND `A > T` (members exist after captains).
- **V8**: `captainIds.length == T`. Actionable messages: "Designate N more" or "Remove N".
- **V9**: `A <= T * P` (defensive capacity assertion, guaranteed by ceil formula).

### 6.4 Diversity-feasibility (V10-V12)
- **V10**: `distinctBusinessCategories >= P`. A table of size P needs P different categories.
- **V11**: For **every** business category b: `count(people of type b) <= T`. In any single round, each table holds at most one person of type b.
- **V12** *(advisory warning)*: Captains clustered in few categories tighten V11 — warns but doesn't block.

### 6.5 Advisory warnings (don't block)
- **W1**: `R > ceil((A-1)/(P-1))` → later rounds will force repeat pairings.
- **W2**: `A % P != 0` → some tables seat P-1 (uneven).

### Implementation
File: `src/engine/validation.ts`
- `tableCountFor(activeCount, personsPerTable)` → `ceil(A/P)`
- `validate(participants, captainIds, config)` → `ValidationResult { ok, errors[], warnings[], derived }`
- `derived` contains: `activeCount`, `tableCount`, `rotatingMembers`, `distinctCategories`, `captainsRequired`, `captainsDesignated`

---

## 7. Schedule Generation Algorithm

File: `src/engine/matcher.ts`

### 7.1 Core function
```
generateSchedule(participants, captainIds, config) → Schedule
```

### 7.2 Data structures (performance-critical)
- **Dense index mapping**: Participant IDs → indices `[0..A)`. Category strings → category indices.
- **Met bit-matrix**: `Uint8Array(A * A)` — O(1) lookup for "have these two met?". ~88KB at A=300.
- **Category frequency array**: `Int32Array(catCount)` — used to order most-constrained members first.
- **Degree array**: `Int32Array(A)` — distinct people each index has met (for stats).

### 7.3 Algorithm per round
```
for r in 1..R:
  1. Create fresh WorkingTable[] from captain assignments
     Each table = { captainIdx, occupants: [captainIdx], cats: Set{captainCatIdx} }

  2. Create round-specific RNG: makeRng(seed + r * 0x1000193)

  3. Order members: shuffle with round RNG, then stable-sort DESCENDING by
     global category frequency (most-constrained category first)

  4. Shuffle table evaluation order with round RNG

  5. For each member m in ordered list:
     - Find candidate tables where: size < P AND m.category NOT in table.cats (C1 hard)
     - Among candidates, pick the one with:
       a) Fewest existing met-pairs with current occupants (minimize C2)
       b) Most empty seats (balance / W2 handling)
       c) Deterministic tiebreak via seeded table order
     - If no candidate: attempt REPAIR (see below)
     - If repair fails: throw InfeasibleRoundError

  6. Record pairings: for each table, all occupant pairs → update met matrix,
     degree counts, uniquePairsMet, repeatPairings
```

### 7.4 Repair step
When member m has no open category-safe table:
1. Find a table that has a free seat but is blocked because a **non-captain member** there
   shares m's category.
2. Find an alternative table where that blocker can be relocated (has space, doesn't violate
   C1 for the blocker's category).
3. Move the blocker, seat m. Keeps C1 intact.
4. Only skips if the blocker is the captain (can't move captains).

### 7.5 Infeasibility handling
- C1 is **never** violated. If a round can't satisfy C1 even with repair, it throws
  `InfeasibleRoundError`.
- C2 is soft: the solver is allowed to repeat a pairing. Repeats are counted and reported.

### 7.6 Determinism
Same snapshot + same config + same seed => **identical schedule**. The seed is stored with
the conclave. Each round uses a derived sub-seed: `seed + r * 0x1000193` (FNV prime).

### 7.7 Output
```typescript
Schedule {
  config: ConclaveConfig
  tableCount: number
  rounds: RoundSeating[]
  stats: ScheduleStats
}

RoundSeating { roundNumber, tables: TableSeating[] }
TableSeating { tableNumber, captainId, memberIds: number[] }

ScheduleStats {
  participants, tables, rounds,
  totalPairsPossible,   // C(A,2)
  uniquePairsMet,       // distinct pairs that shared a table >= 1 time
  repeatPairings,       // extra times a pair shared a table beyond the first
  avgUniqueMetPerMember,
  minUniqueMetPerMember,
  maxUniqueMetPerMember,
  coverage              // uniquePairsMet / totalPairsPossible (0..1)
}
```

---

## 8. RNG (Deterministic PRNG)

File: `src/engine/rng.ts`

- **Algorithm**: Mulberry32 (seeded 32-bit PRNG).
- `makeRng(seed)` → `Rng` (function returning 0..1 on each call)
- `shuffle<T>(arr, rng)` → Fisher-Yates shuffle into a **new** array (original untouched).

### Mulberry32 implementation (MUST match exactly for cross-platform determinism):
```
function makeRng(seed):
  a = seed >>> 0  (unsigned 32-bit)
  return function next():
    a = (a | 0)
    a = (a + 0x6D2B79F5) | 0
    t = Math.imul(a ^ (a >>> 15), 1 | a)
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
```

---

## 9. Captain Auto-Selection

File: `src/engine/captains.ts`

Two strategies:
1. **`autoSelectCaptains(participants, P, seed)`** — category-spread selection.
   - Seeds RNG with `seed ^ 0x9E3779B9` (golden ratio).
   - Buckets participants by category (shuffled).
   - Round-robins across shuffled category buckets: takes one from each category before
     taking a second from any category. Maximizes captain category diversity.
   - Deterministic for given seed.

2. **`randomSelectCaptains(participants, P, seed)`** — uniformly random selection.
   - Shuffle all participants, take first T.
   - Deterministic for given seed.

Both compute `T = ceil(A/P)` and return `number[]` (captain IDs).

---

## 10. Independent Audit Verifier

File: `src/engine/audit.ts`

`auditSchedule(participants, schedule)` → `AuditReport`

Re-checks every hard constraint from scratch, intentionally decoupled from the matcher:
- **C1**: No table has two of the same category (including captain). Counts `categoryCollisions`.
- **C3**: Each participant seated exactly once per round. Counts `seatingErrors`.
- **C4**: No table exceeds P. Counts `oversizedTables`.
- **C5**: Captains anchored to the same table number every round. Counts `captainDrift`.
- **C2** (soft, reported not failed): Pairs that shared a table >1 time. Counts `repeatPairings`.

`ok = true` only if all HARD constraint violation counts are 0.

---

## 11. Participant Data Model

```typescript
interface Participant {
  id: number;
  name: string;
  phone: string;
  businessName: string;
  businessCategory: string;     // controlled dropdown from BUSINESS_CATEGORIES
  location: {
    withinGuntur: boolean;
    place?: string;             // only when withinGuntur is false
  };
  chapter?: string;             // optional BNI chapter (e.g. "Atoms", "Bytes")
}
```

### Business Categories (74 total)
A controlled dropdown list. The full list:
```
Real Estate, Chartered Accountant, Software Development, Web Design & Development,
Digital Marketing, Interior Designer, Architect, Civil Contractor,
Electrical Contractor, Plumbing & Sanitary, Tiles & Flooring, Modular Kitchen,
Furniture, Home Appliances, Solar Energy, Caterer, Restaurant,
Bakery & Confectionery, Event Management, Wedding Planner,
Photography & Videography, Travel Agent, Hotel & Resorts, Insurance Advisor,
Financial Planner, Stock Broker, Mutual Funds Advisor, Banking & Loans,
Advocate / Lawyer, Doctor - General Physician, Dentist, Dermatologist, Pharmacy,
Diagnostic Lab, Hospital & Healthcare, Ayurveda & Wellness, Fitness & Gym,
Yoga Trainer, Boutique & Fashion, Textiles, Jeweller, Footwear,
Cosmetics & Beauty, Salon & Spa, Printing & Packaging, Signage & Branding,
Advertising Agency, Gifting & Corporate Gifts, Stationery, Automobiles - Cars,
Two Wheeler Dealer, Auto Service & Repair, Tyres & Batteries, Packers & Movers,
Logistics & Courier, Hardware & Paints, Cement & Building Material,
Borewells & Drilling, Pest Control, Housekeeping Services, Security Services,
Manpower & Recruitment, Education & Coaching, Play School,
Study Abroad Consultant, IT Hardware & Networking, Mobile & Electronics,
CCTV & Security Systems, Agriculture & Seeds, Dairy & Food Products,
Organic Foods, Catering Equipment, Aluminium & Glass
```

### BNI Chapter Names (for optional field)
```
Atoms, Bytes, Titans, Eagles, Pioneers, Catalysts, Vibgyor, Summit
```

### Sample Data Generator
`generateSeedParticipants(count=300, seed=20260627)`:
- Deterministic roster of Indian (Telugu/Andhra-leaning) participants.
- Categories distributed via round-robin over shuffled category list.
- ~85% within Guntur, ~15% outside (Vijayawada, Hyderabad, Chennai, etc.).
- ~75% have a chapter assigned.
- Phone numbers: Indian mobile format (+91 XXXXXXXXXX).

---

## 12. Conclave State Machine

```
DRAFT --(start)--> SNAPSHOTTED --(validate ok)--> SCHEDULED
SCHEDULED --(admin edits)--> SCHEDULED   (re-validate)
SCHEDULED --(lock)--> LOCKED --(begin)--> RUNNING --(finish)--> COMPLETED
Any --(admin cancel before lock)--> DRAFT
```

Roles/schedule mutable only in DRAFT / SNAPSHOTTED / SCHEDULED. **Frozen from LOCKED onward.**

---

## 13. Application Flow

### 13.1 Admin happy path
1. Admin signs in.
2. Register/import members (business category required) → V1, V2.
3. Designate captain pool → V3.
4. Configure P, R, autoLogoutHours → V4, V5, V6.
5. Members log in → become "active".
6. Admin clicks START CONCLAVE → snapshot active list (A) → freeze.
7. Compute T = ceil(A/P); prompt to fix captains to T → V8.
8. Run VALIDATION GATE — fail → show actionable errors; pass → continue.
9. GENERATE SCHEDULE (seeded).
10. Admin REVIEWS schedule; optional manual seat overrides → each override re-validates.
11. Admin LOCKS the conclave → roles + schedule frozen.
12. Run rounds: show Round 1..R seating; advance/stop; optional per-round timer + repeat report.

### 13.2 Member happy path
1. Member logs in (active; auto-logout timer starts).
2. After lock: views own schedule → per round: table #, captain, tablemates.
3. (Optional) marks attendance per round.

---

## 14. Test Suite Guarantees

### Hard constraint tests
- The original 6-person example: two "Software Dev" participants never share a table (C1).
- ZERO repeat pairings when rounds fit comfortably (300 people, 2 rounds).
- Never seats two of the same category together across 300 participants x 6 rounds.
- Every participant seated exactly once per round, captains anchored (213 x 5 rounds).

### Objective tests
- High coverage and healthy minimum per person (300 x 7 rounds).
- Repeat rate < 15% of total meetings.
- Auditor's repeat count matches the engine's reported stat.

### Determinism tests
- Same seed + same inputs => identical schedule (JSON equality).
- Input participants array is never mutated.

### Performance tests
- 300 people x 8 rounds completes in < 500ms (typically single-digit ms).

### Validation tests
- Healthy 300-person conclave passes all validations.
- V10: too few distinct categories for table size → error.
- V11: category has more people than tables → error.
- V8: wrong captain count → error.
- V7: not enough people → error.
- V5: round count outside 4-8 → error.
- W2: uneven tables → warning but still passes.

---

## 15. Data Model (for backend/database)

```
User        : id, name, businessType, contact, isAdmin
Conclave    : id, name, status, P, R, autoLogoutHours, seed, createdAt, snapshotAt, lockedAt
LoginSession: id, userId, loginAt, expiresAt(=loginAt+autoLogoutHours), isActive
Snapshot    : conclaveId, userId            (the frozen active list)
CaptainAssignment : conclaveId, userId, tableNumber   (fixed anchor)
Seat        : conclaveId, roundNumber, tableNumber, userId, isCaptain
MetPair     : conclaveId, userIdA, userIdB, firstRound  (for C2 / reporting)
```

Key indexes:
- `Seat (conclaveId, roundNumber, tableNumber)` — lookup per round/table.
- Unique `Seat (conclaveId, roundNumber, userId)` — enforces C3 (exactly once per round).

---

## 16. Key Implementation Details for the Flutter App

### Things the Flutter app MUST replicate exactly:
1. **The matching algorithm** from `matcher.ts` — greedy most-constrained-first placement
   with met bit-matrix, repair step, and per-round seeded RNG.
2. **The validation gate** from `validation.ts` — all V1-V12 and W1-W2 checks.
3. **The audit verifier** from `audit.ts` — independent post-generation constraint check.
4. **Mulberry32 PRNG** from `rng.ts` — exact same algorithm so same seed gives same schedule
   across web and mobile.
5. **Captain auto-selection** — category-spread round-robin algorithm.
6. **The 74 business categories** from `businessCategories.ts`.
7. **Constraint priorities**: C1 is HARD (never violated), C2 is SOFT (minimized, allowed).
8. **The state machine**: DRAFT → SNAPSHOTTED → SCHEDULED → LOCKED → RUNNING → COMPLETED.

### Things the Flutter app should extend beyond the tester:
- Full auth system (admin + member login).
- Real backend / Firestore (not localStorage).
- The conclave lifecycle (start, snapshot, lock, run rounds, complete).
- Member-facing schedule view (per-round personal assignments).
- No-show handling, attendance tracking.
- Timer per round (optional).
- Manual seat override with re-validation.
- Post-event reporting.

---

## 17. File Map of the Reference Project

```
bni-1-1/
├── BNI-1to1-Conclave-Spec.md       # Full product spec, rulebook, flow
├── initial-requirement-understanding.txt  # Original raw requirements
├── README.md                        # Project overview
├── package.json                     # Vite + React 19 + Tailwind v4 + Vitest
├── vite.config.ts                   # Vite config with React + Tailwind plugins
├── tsconfig.json / tsconfig.*.json  # TypeScript configs
├── index.html                       # Entry HTML
└── src/
    ├── main.tsx                     # React root
    ├── App.tsx                      # Main app: participant state, captain toggling, tab nav
    ├── index.css                    # Tailwind import
    ├── engine/                      # PURE matching engine (no React dependency)
    │   ├── index.ts                 # Barrel export
    │   ├── types.ts                 # Participant, ConclaveConfig, Schedule, etc.
    │   ├── validation.ts            # Validation gate (V1-V12, W1-W2)
    │   ├── captains.ts              # Auto/random captain selection
    │   ├── matcher.ts               # Schedule generation algorithm
    │   ├── audit.ts                 # Independent constraint verifier
    │   ├── rng.ts                   # Mulberry32 seeded PRNG + Fisher-Yates shuffle
    │   └── __tests__/
    │       ├── matcher.test.ts      # Hard constraints, objective, determinism, perf
    │       └── validation.test.ts   # Validation gate coverage
    ├── components/                  # React UI (tester harness)
    │   ├── ui.tsx                   # Shared: Card, Badge, Button, Field, Stat
    │   ├── EnrollmentForm.tsx       # Participant enrollment form
    │   ├── ParticipantList.tsx      # Searchable roster table with captain toggle
    │   ├── ConclavePanel.tsx        # Config + validation + generation + results
    │   └── ScheduleView.tsx         # Round-by-round table cards
    ├── data/
    │   ├── businessCategories.ts    # 74 BNI business categories (controlled list)
    │   ├── names.ts                 # Indian name pools for sample data
    │   └── seed.ts                  # Deterministic 300-participant generator
    └── lib/
        └── storage.ts               # localStorage persistence for roster
```

---

*This document was generated on 2026-07-03 from a complete read of all source files in
`/Users/eb/Documents/web/bni-1-1`. No files in that directory were modified.*
