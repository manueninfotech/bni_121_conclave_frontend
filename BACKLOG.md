# Conclave — change backlog

Living list of fixes & improvements. Strategy: build a **big batch**, verify
everything, then cut **one iOS submission** (App Store review takes ~a week, so
we maximize what's in each review). Android can ship incrementally.

---

## Conclave #1 — recap (2026-10-03, "BNI LTRT 121 Conclave")
- Completed cleanly: 4/4 rounds, status `completed`.
- **39 members, 27 unique business categories** (12 in shared-category clusters).
- Schedule: 8 tables, ~5/table, 4 rounds. **4 repeat pairs** out of 300 unique
  pairs met (98.7% unique) — caused by the hard "no same-category at a table"
  rule with dense clusters (4× Tax Advisory, 3× Glass, 3× Red Sandal Wood).
- Notifications (schedule-ready, round-start, table sequence) delivered via
  personal topics — confirmed received.
- Feedback (10 responses): mostly 4–5★, NPS 7–10. **Every negative traces to
  iOS being 3 versions behind** ("iOS slow", "table not changing for iOS").

---

## 🔴 P0 — ship immediately
- [ ] **Catch iOS up to Android (1.1.8+).** iOS 1.1.5 lacks auto-advancing
      rounds, dynamic categories, register-on-past fix, dynamic round timing —
      the root of the "iOS slow / table not changing / not working" feedback.
      Batch the P1/P2 app work below into this same submission.

## 🟠 P1 — active-round experience (run + feedback)
- [ ] **Show the next table in transition** (4 members asked). `MOVE → Go to
      Table 3` — add `nextTableNumber` (member's seat in round +1) to the
      active-round data and surface it on the timer card during transition.
- [ ] **Captain stay-put / role-aware transition.** Captains anchor their table
      (same table all rounds) but the app says "move to your next table." Show
      captains "Stay at Table N — your next group is arriving."
- [ ] **Timer UX ("uncontrolled timer").** Re-verify after P0 — likely the iOS
      auto-advance gap; confirm the countdown reads correctly on iOS.

## 🟠 P1 — schedule tooling (admin)
- [ ] **Schedule Review: show WHY pairs are flagged** — repeat-pair count + the
      categories that forced them (e.g. "4× Tax Advisory can't be separated").
      Data is in `scheduleSummary` / `schedule.stats`.
- [ ] **Schedule generation: show invalidation reasons** — on failure, render
      the engine's actual issues (round-count range, captain count/categories,
      "no category-safe seating") instead of a generic error. Backend already
      returns `issues` / `warnings` / `derived`; admin just needs to display.

## 🟡 P2 — reliability & admin
- [ ] **Create-form validation** — block saving when reg-start > reg-end or the
      window excludes the event (caused today's "registration closed").
- [ ] **Status drift fix** — app trusts stored `status`/`isRegistrationOpen`
      which go stale; compute reg-open from dates in the app, or a backend sweep
      that persists status transitions (not just completion).
- [ ] **Live sticky notification (Zomato-style)** — ongoing status: Round/Table
      + who's speaking + countdown. Android ongoing-notification first; iOS Live
      Activity later.
- [ ] **Subscribe to the conclave topic at registration** (proper fix; today's
      personal-topic broadcast was the mitigation).

## 🟢 P3 — feedback-driven features
- [ ] **In-app post-conclave feedback** on the summary screen (★ + comment →
      backend) — replaces the Google Form.
- [ ] **Pre-meeting / 1-2-1 calendar alerts** — "connect to Google Calendar",
      reminders before scheduled 1-2-1s (requested).
- [ ] **Self-heal fix** — `listConclaves` re-opens explicitly-completed
      conclaves with `currentRound==0`; gate or remove.

## ⬜ Incoming
- [ ] _(to be added)_

---

## ✅ Shipped this cycle (context)
Dynamic categories + Settings admin UI; auto-advancing rounds; auto-scaling &
admin-tunable round timing; register-on-past fix; deleted-conclave ghost fix;
schedule-ready / round-start / table-sequence notifications; Azure migration;
fvm pin to Flutter 3.38.5; Android 1.1.3 → 1.1.8.
