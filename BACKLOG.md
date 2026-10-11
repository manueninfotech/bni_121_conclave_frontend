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

## 🟠 P1 — schedule tooling (admin) — SHIPPED & LIVE (Vercel)
- [x] **Schedule Review: show WHY pairs are flagged** — repeat modal now explains
      the dense categories that force repeats, flagging those at/above the table
      count as the hard drivers. — shipped 1450dfb.
- [x] **Schedule generation: show invalidation reasons** — the failure banner now
      renders the engine's real issues/warnings/derived math + hint. — shipped 1450dfb.
- [x] **Admin feedback view** — new Feedback tab reads `GET /admin/conclaves/:id/feedback`
      and joins uids to member names. — shipped 1450dfb.

## 🟡 P2 — reliability & admin
- [x] **Create-form validation** — reg-start > reg-end blocked. — shipped (admin).
- [x] **Status drift fix** — app computes reg-open from the window. — shipped d97749b.
- [x] **Auto-advance guard** — block starting a round that already ran (backend
      422 with the live round). — shipped 22d5845.
- [x] **Live sticky notification (Zomato-style)** — ongoing Android round card with
      round/table + speaker/next-table + live countdown. iOS Live Activity later.
      — shipped 2947724.
- [x] **Subscribe to the conclave topic at registration** — additive subscribe on
      register, so members get pushes without opening the active-round screen.
      — shipped 2947724.

## 🟢 P3 — feedback-driven features
- [x] **In-app post-conclave feedback** on the summary screen. — shipped 18c57b1.
- [x] **Calendar integration** — "Add to calendar" on register (iOS+Android) +
      app-side reminder ~1h before. — shipped 2947724.
- [x] **1-2-1 calendar alerts** — device reminder ~15 min before every confirmed
      1-2-1, scheduled at the data layer so both parties get it. — shipped 2947724.
- [x] **Self-heal fix** — `listConclaves` no longer re-opens a deliberately-completed
      conclave (trusts completedAt; never re-opens a past event). — shipped fa72ceb, deployed.

## 🔵 Ops — not code
- [x] **Enable Razorpay** — TEST keys set as Azure secrets (secretref), verified by a
      live order create+fetch against Razorpay. ⚠️ Swap to LIVE keys before real charges.
- [x] **Verify backend deploy** — feedback endpoints + auto-advance guard confirmed
      live (401 not 404); self-heal fix built & deployed (revision 0000010).

---

## ✅ Shipped this cycle (context)
Dynamic categories + Settings admin UI; auto-advancing rounds; auto-scaling &
admin-tunable round timing; register-on-past fix; deleted-conclave ghost fix;
schedule-ready / round-start / table-sequence notifications; Azure migration;
fvm pin to Flutter 3.38.5; Android 1.1.3 → 1.1.8.
