# Offline Attendance & Sync — Design Note

> Status: **QR attendance is implemented.** The venue-LAN proposal in §5 is a
> **proposal only — parked pending research.** Do not build §5 without working
> through the open questions in §7 first.

---

## 1. The problem

The venue has no usable internet for 300–400 people at once. This has been the
recurring failure at past conclaves. Two things must survive with zero
connectivity:

1. **Attendance** — did member X actually attend round R?
2. **Referrals** — A promises business to B; that promise must not be lost.

And two things are *wanted* despite no connectivity:

3. The **captain** must see their table's attendance status.
4. The **admin** must see live stats (active members) before each round.

(3) and (4) are the hard ones. Capturing data offline is easy; *seeing other
people's* data offline is not.

---

## 2. The insight that drives the whole design

> **Whoever scans is the device the record lands on.**

When there is no network, a record exists only on the device that created it.
So the direction of the scan decides who can see the data.

| Direction | Where records land | Can the captain see the table roll offline? |
|---|---|---|
| Members scan the captain's QR | Spread across ~250 member phones | **No.** The captain holds nothing. |
| **Captain scans each member's QR** | **All on the captain's phone** | **Yes.** Complete, instantly. |

This is why the intuitive design (members scan a table code) is the wrong one.
It proves presence but leaves the data fragmented across every phone in the
room, which is exactly the state we cannot sync out of.

**Scanning inward — captain scans members — is the design.** It satisfies
requirement (3) with no network at all, and it collapses the sync problem from
~250 devices to ~36 (one per table).

---

## 3. What is implemented today

### 3.1 The QR payload

Deliberately plain text, not JSON — it has to survive being printed on a name
badge and scanned from paper.

```
BNI121|1|<conclaveId>|<uid>
```

- `BNI121` — magic prefix, so foreign QR codes in the room are ignored.
- `1` — payload version, so the format can change later without misreading.
- `conclaveId` / `uid` — Firestore identifiers.

The uid **identifies, it does not authenticate**. That is fine: the captain is
physically standing at the table. A rotating signed token would solve a problem
we do not have.

Defined in `lib/features/active_conclave/domain/attendance_qr.dart`.

### 3.2 Two ways to present the code

- **In-app** — the member's active-round screen renders their QR (`_MyQrCard`).
- **Printed on the name badge** — *recommended primary*. BNI already prints
  badges. A badge works with a dead battery, a cracked screen, or a member who
  never installed the app.

The payload is identical either way, so the captain's scanner does not care
which it is looking at.

### 3.3 Scan validation

Every scan is checked against the captain's current table before it is
recorded (`validateScan`, pure and unit-tested):

| Rejected when | Why it matters |
|---|---|
| Not a `BNI121` code | The camera reads every QR in the room. |
| Wrong payload version | Forward compatibility. |
| Wrong `conclaveId` | Stale badge from a previous conclave. |
| **Person is not at this table this round** | **Tables are inches apart. This stops a captain marking the neighbouring table's member.** |
| Captain scanned their own code | Meaningless. |
| Round is not in its active phase | Attendance closes with the round. |

### 3.4 Fallback: manual marking stays

QR is the fast path, **not the only path**. Dead battery, broken camera, damaged
badge, member who refuses to be scanned — the manual Present/Absent controls
remain. Members can also still mark themselves.

`attendance.markedBy` records which device recorded each row (the member
themselves, or their captain), so the two paths stay distinguishable after sync.

### 3.5 Where it is stored

sqflite (`local_db.dart`), table `attendance`, keyed by
`(conclaveId, roundNumber, userId)` — so re-marking the same person in the same
round *updates* rather than appending. Rows carry `synced = 0` until the server
confirms them.

Referrals work the same way, and are **immutable once given** (spec: "can't
modify") — `addReferral` refuses a duplicate `(round, from, to)`.

---

## 4. Sync, as it works today

`sync_service.dart` pushes unsynced rows to `POST /api/conclaves/:id/sync` every
30 seconds and on demand.

The critical invariant, and the reason the old version lost data:

> **A row may only be marked `synced` locally once the server has actually
> committed it.**

The server therefore commits its Firestore batch *first*, and only then echoes
back the ids it persisted. If the write fails, it returns 500 with **no**
acknowledged ids, and the rows stay on the device to be retried. (The original
implementation echoed the ids back without writing anything, so every record was
acknowledged and then dropped.)

---

## 5. PROPOSAL (PARKED): venue LAN for live admin stats

> **This section is not implemented and not agreed. It needs the research in §7.**

The spec asks: *"if there's any way of getting these live stats without network,
it will be appreciable for admin."*

There is — the observation being that **you do not need internet, you need a
network**.

### 5.1 Proposed topology

```
300 members ──── no network at all; they just show a QR (or a printed badge)
      │
      │ scanned by
      ▼
 36 captains ──── venue wifi (a router or a laptop hotspot; no internet)
      │
      │ HTTP sync to the laptop's local IP
      ▼
   Laptop ──────── runs the Express backend + the admin dashboard
      │             admin reads it locally ⇒ live stats, instantly
      │
      └─ one 4G/dongle link ──► Firestore (the durable mirror)
```

### 5.2 Why it is attractive

- **One internet connection, not three hundred.** The laptop needs a link;
  no phone does.
- **Only captains need the LAN.** Because captains scan members, members need
  no network whatsoever. ~36 devices on one router is trivial; 300–400 devices
  on one AP is the thing that has been failing.
- **Admin stats stay live even if the 4G link dies**, because the dashboard
  reads from the laptop, not from Firestore. Only the durable mirror lags.
- **Nearly free given the current architecture** — `sync_service` already
  targets a configurable `host:port`.

### 5.3 What it would require

- Sync base URL must become configurable at runtime (Firebase Remote Config was
  the suggested mechanism — fetched early while there is still signal, cached,
  with a baked-in default fallback).
- The backend must tolerate its Firestore link being absent or intermittent
  (buffer locally, drain later) — **today it does not; it assumes Firestore is
  reachable.**

---

## 6. Failure modes and what happens

| Scenario | Behaviour today |
|---|---|
| Member's phone is dead | Captain scans the **printed badge**. Works. |
| Captain's phone dies mid-event | **Unresolved.** That table's unsynced attendance is lost. See §7. |
| Member registers after the schedule is generated | They are not in the participant snapshot; the app tells them to ask the admin to regenerate. |
| No network for the entire event | Capture works. Sync drains whenever connectivity returns. Admin sees nothing live (this is what §5 would fix). |
| Server unreachable during sync | Rows stay `synced = 0` and retry. Nothing is lost. |
| Server write fails | 500, no ids acknowledged, rows retried. Nothing is lost. |
| Two referrals to the same person, same round | Second is refused. Referrals are immutable. |
| Captain scans the neighbouring table's member | Rejected — `notAtThisTable`. |

---

## 7. Open questions — resolve before building §5

1. **Captain's phone is a single point of failure.** All of a table's attendance
   lives on one device until it syncs. If that phone dies or is lost, the table's
   roll is gone. Options: opportunistic sync whenever any network appears;
   members *also* self-mark as a redundant copy; a second scanning device per
   table. **Needs a decision.**

2. **Does the admin actually need live stats, or just fast post-hoc stats?**
   §5 is a meaningful amount of venue logistics (router, laptop, dongle, someone
   to run it). If "within a few minutes of each round" is good enough, a simpler
   answer may do.

3. **Router capacity and the real device count.** 36 captains is comfortable. But
   if members end up needing the LAN for any reason, the numbers change
   completely. Confirm members truly need nothing.

4. **Backend resilience without Firestore.** §5 assumes the laptop can keep
   accepting syncs while its own internet is down. Today it cannot. Requires a
   local buffer + drain.

5. **Badge printing logistics.** Who prints them, and are uids known early
   enough? If badges are printed before registration closes, late registrants
   have no badge and must use the in-app QR.

6. **Scan throughput.** ~7 members × 8 rounds ≈ 56 scans per captain. At a few
   seconds each this is comfortable inside a 12-minute round — but it has not
   been tested with real people, real lighting, or a badge in a lanyard that
   keeps flipping over.

7. **Who is the source of truth if a member self-marks present and the captain
   marks them absent?** `markedBy` records both paths, but the conflict rule is
   undefined. Suggest: captain wins.

---

## 8. Related code

| Concern | File |
|---|---|
| QR payload + scan validation (pure, tested) | `lib/features/active_conclave/domain/attendance_qr.dart` |
| Captain's scanner | `lib/features/active_conclave/presentation/captain_scanner_screen.dart` |
| Member's QR / round UI | `lib/features/active_conclave/presentation/active_round_screen.dart` |
| Offline store | `lib/features/active_conclave/data/local_db.dart` |
| Sync client | `lib/features/active_conclave/data/sync_service.dart` |
| Sync endpoint | `bni-1-1/src/server/index.ts` → `POST /api/conclaves/:id/sync` |
| Tests | `test/attendance_qr_test.dart`, `test/active_conclave_models_test.dart` |
