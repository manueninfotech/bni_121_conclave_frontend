# Post-Test Fixes — MIT-Test Conclave2026_001

Tracker for the 18 bugs + 11 requirements found in the live test. Execute in batches to minimize deploys/builds: **Backend** (deploy Azure once) → **Admin panel** (Vercel) → **App** (one build + store release). Status: ☐ todo · ◐ in-progress · ☑ done.

## Priority legend
P0 = reliability / data integrity · P1 = correctness / important UX · P2 = polish

---

## BATCH 1 — Backend (`web/bni-1-2-1-backend` → Azure) ✅ DEPLOYED rev 0000027 (2026-11-04)
- ☑ **#6 (P1)** Idempotent lock — provided by Shravya's `a2a2ff2`: re-lock throws 409 Conflict (never re-reaches notify) + notify is now non-blocking/parallel + records in-app notifications. Our own #6 commit was dropped as redundant during rebase. Fixes "6 notifications at once".
- ☑ **#4 (P1)** Captain push on role change — `conclaveMembers.updateMember` now sends the "You're a Table Captain" push AND records an in-app notification when role→captain (mirrors notifyScheduleReady). Done (tsc clean, commit 4c3f37e).
- ☑ **#12 (P1)** End-round idempotency — `closeRound` no-ops if the talk phase already ended (double-click can't re-anchor/restart the move timer or re-notify). Done (tsc clean, commit 4c3f37e).
- → **#3 (P1)** Notify trigger — no backend change (schedule-ready-on-lock is correct); UX copy fix moves to Batch 2 (admin panel).
- ✖ **#2 (P1)** Matcher weights — **DECISION: REMOVE, not implement** (user, 2026-11-05). The sliders are dead (matcher ignores config weights). No backend change — matcher already schedules fine minimizing repeats. The dead sliders get removed in Batch 2 (admin panel).
- ⚠ **#16 (P0)** iOS round notifications — needs device + APNs investigation (why conclaveTopic stops on iOS after R1 while userTopic works). Pair with the app iOS-background workstream; requires on-device testing. Defer to App batch.

## BATCH 2 — Admin panel (`web/BNI-1-2-1-conclave` → Vercel) ✅ PUSHED (auto-deploys)
- ☑ **#2 (P1)** Weight sliders removed — done upstream by Shravya (`a445e2d` removed the arrangement-rules/weights card). Verified gone from ScheduleGen.jsx.
- ☑ **#12 (P1)** "End round" button — the old manual end-round control that restarted the move timer was removed upstream (`300cf46`). Added our own `isStartingRound` guard (commit `ee76b66`) so the remaining start/advance button can't be double-clicked.
- ☑ **#6 (P1)** Lock & Finalize debounce — done upstream by Shravya (`91be249`: isLocking guard + spinner on lock seating button).

## BATCH 3 — App (`FlutterProjects/conclave_1_2_1` → build + store release)
- ☑ **#5 (P0)** `effectiveStatus` now never date-demotes a `running` conclave — a live event stays in Ongoing even if its scheduled day rolled over. (conclave_model.dart)
- ☑ **#13 (P0)** List refreshes on app resume (added WidgetsBindingObserver → invalidate `conclavesStreamProvider`). Cache already re-fetched on subscribe + every 30s + pull; this adds "refresh on open". (conclaves_list_screen.dart)
- ☑ **#8 (P0)** Offline sync: added **sync-on-write** — every attendance/referral/note capture now fires `syncNow` immediately (fire-and-forget) instead of waiting for the 30s tick or a connectivity change. Foreground-flush (app.dart resume) and connectivity-flush already existed. (active_round_screen.dart)
- ☑ **#18 (P0)** Summary **syncs-on-open** AND now persists the member's server-side attendance: syncNow pulls this member's own attendance out of `mySchedule` (including rounds a CAPTAIN marked) into local db as synced, via `upsertServerAttendance` (safe UPSERT that never clobbers a locally-pending self-mark). Summary now reflects the server, not just local captures. (conclave_summary_screen.dart, sync_service.dart, local_db.dart)
- ◐ **#16 (P0)** sync-on-foreground already present (app.dart resume → syncAllPending). The remaining part — iOS stops receiving conclaveTopic round pushes after R1 while userTopic works — needs on-device + APNs investigation; can't be verified blind. Deferred, needs a device.
- ☑ **#1 (P1)** Conclave/1-2-1 reminders hardened: exact-alarm with graceful inexact fallback (`_scheduleResilient`), `RECEIVE_BOOT_COMPLETED` + boot receiver (survives reboot), `SCHEDULE_EXACT_ALARM` permission, **reschedule on app-open** (app.dart listens to the conclaves list and re-arms registered upcoming reminders), and errors are logged not swallowed. (local_notifications.dart, AndroidManifest.xml, app.dart)
- ☑ **#7 (P1)** Own row shows only "I'm here"; "Absent" segment hidden for self (captain & member). Captain can still mark others absent; a member marked absent by captain can still tap "I'm here". (active_round_screen.dart)
- ☑ **#11 (P1)** Captain transition copy now says "Stay at your table" instead of "Move to your next table" (the _PhaseNotice text was role-blind; timer VM was already correct). (active_round_screen.dart)
- ☑ **#10 (P1)** Referral-phase labels now "Your turn to give a referral" / "Referring now" (not "speak"/"Speaking now"), via new `_TimerVM.isReferral`. Covers big timer, Android sticky, and _SpeakingPill. (active_round_screen.dart)
- ☑ **#9 (P2)** Referral-given + toast snackbars now floating, 3s, with a close icon — auto-dismiss and dismissible without tapping Add-note. (active_round_screen.dart)
- ☑ **#14 (P2)** Smoother transitions — expanded timer card eases its phase colour (AnimatedContainer) and the phase banner cross-fades (AnimatedSwitcher) instead of hard-cutting. (active_round_screen.dart)
- ☑ **#15 (P2)** Timer no longer jumps — `ServerClock.syncWith` now **slews** small offset corrections (snaps only on the first correction or a >5s genuine shift), so routine re-syncs (and sync-on-write) don't make the countdown skip/stall. (server_clock.dart)
- ☐ **#17 (P2)** Remove redundant appbar "Home"/tab-name duplication.

## REQUIREMENTS (after bugs) — see `conclave-ux-requirements.md`
Table number on move · "Upcoming table" preview · full-screen member view + QR · speaking order · profile photos in roster · mini-timer speaker photo · referral contacts picker · Home "Live now" card · repeat-pairing flags · graceful off-boarding · custom icon set.

---
_Updated as fixes land. Start: Batch 1._
