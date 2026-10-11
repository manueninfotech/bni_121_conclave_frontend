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
- [x] **Show the next table in transition** (4 members asked). — shipped 07b599c.
- [x] **Captain stay-put / role-aware transition.** — shipped 07b599c.
- [ ] **Timer UX ("uncontrolled timer").** Re-verify after P0 — likely the iOS
      auto-advance gap; confirm the countdown reads correctly on iOS.

## 🟠 P1 — schedule tooling (admin) — STILL PENDING
- [ ] **Schedule Review: show WHY pairs are flagged** — repeat-pair count + the
      categories that forced them (e.g. "4× Tax Advisory can't be separated").
      Data is in `scheduleSummary` / `schedule.stats`.
- [ ] **Schedule generation: show invalidation reasons** — on failure, render
      the engine's actual issues (round-count range, captain count/categories,
      "no category-safe seating") instead of a generic error. Backend already
      returns `issues` / `warnings` / `derived`; admin just needs to display.
- [ ] **Admin feedback view** — backend endpoint `GET /admin/conclaves/:id/feedback`
      is live (8193506); the admin panel UI to display it is NOT built.

## 🟡 P2 — reliability & admin
- [x] **Create-form validation** — reg-start > reg-end blocked. — shipped (admin).
- [x] **Status drift fix** — app computes reg-open from the window. — shipped d97749b.
- [x] **Auto-advance guard** — block starting a round that already ran (backend
      422 with the live round). — shipped 22d5845.
- [ ] **Live sticky notification (Zomato-style)** — ongoing status: Round/Table
      + who's speaking + countdown. Android ongoing-notification first; iOS Live
      Activity later.
- [ ] **Subscribe to the conclave topic at registration** (proper fix; today's
      personal-topic broadcast was the mitigation).

## 🟢 P3 — feedback-driven features
- [x] **In-app post-conclave feedback** on the summary screen. — shipped 18c57b1.
- [x] **Calendar integration** — "Add to calendar" on register (iOS+Android) +
      app-side reminder ~1h before. — built this cycle (uncommitted).
- [ ] **1-2-1 calendar alerts** — reminders before individual scheduled 1-2-1s
      (distinct from the conclave-level reminder above).
- [ ] **Self-heal fix** — `listConclaves` re-opens explicitly-completed
      conclaves with `currentRound==0`; gate or remove.

## 🔵 Ops — not code
- [ ] **Enable Razorpay** — set `RAZORPAY_KEY_ID` + `RAZORPAY_KEY_SECRET` as
      Azure container secrets (backend fully built, fails closed 503 until set).
      Needs the live keys from the approved account.
- [ ] **Verify backend deploy** — confirm auto-advance guard (22d5845) + feedback
      endpoints (8193506) are on the live Azure revision, not just committed.

---

## ✅ Shipped this cycle (context)
Dynamic categories + Settings admin UI; auto-advancing rounds; auto-scaling &
admin-tunable round timing; register-on-past fix; deleted-conclave ghost fix;
schedule-ready / round-start / table-sequence notifications; Azure migration;
fvm pin to Flutter 3.38.5; Android 1.1.3 → 1.1.8.
