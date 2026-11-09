# Live-Round Work — Session Handoff

_Snapshot for resuming after the movie. Branch: `main`. Nothing released yet._

---

## ✅ DONE this session (committed to `main`, unreleased → goes in app 1.3.4)

| Commit | What |
|---|---|
| `2a89045` | **iOS push notifications** — AppDelegate forwards the APNs token to FCM + `setForegroundNotificationPresentationOptions`. Background **and** foreground **confirmed working** on the real iPhone. |
| `6714e3a` | **Android live-round sticky** — now owned app-wide (`roundStickyDriverProvider`), persists across tabs / when pocketed. Shows round · table · speaker · live countdown, "Move to Table N" in the move phase, "· Paused" when paused. |
| `906ca69` | **Rapido-style lock** — while the member's round is live they're held on the active-round screen; tabs/back/deep-links all redirect back; releases when the conclave ends. Only locks once a seat actually resolves (no trapping late registrants). |
| `c46c80a` | **iOS live-round sticky = Live Activity** — new `ios/ConclaveWidgets` extension (lock screen + Dynamic Island), same content as Android. One driver feeds both platforms. Compiles + launches on iPhone 17 sim. |

**Also confirmed done by user:** R8 password reset to `Conclave@2026`; bug **#17** (redundant "Home" appbar label); **#12 liquid-glass nav = DROPPED** (out of scope).

---

## 🔬 TO TEST tonight (all need a REAL live round — not just a build)

1. **Android sticky** — start a round; the ongoing card shows round/table/speaker/countdown. Switch tabs and lock the phone → it must stay and keep counting. In the move phase it shows "Move to Table N". Paused shows "Paused".
2. **iOS Live Activity** — start a round with the app foreground (the lock keeps you there) → a card appears on the lock screen (and Dynamic Island on Pro models). Same content; countdown stays live while pocketed.
3. **Rapido lock** — once a round is live, try to leave the round screen (tabs, back) → you're bounced back. When the conclave completes/cancels → you're free to navigate.
4. **iOS notifications end-to-end** — round started / paused / resumed / closed through ALL rounds (the old bug was "nothing after R1").

> To drive a round for testing: use a test conclave + the admin panel (bni-admin.manuen.com) to lock the schedule and start/advance rounds. The emulator/sim accounts must be registered + seated.

---

## ▶️ TO START next (the main ask)

- **Refine the active-round UI** — user says it's "too basic." Needs direction + concrete redesign options before building. This is the priority after testing.

**Smaller follow-ups tied to this work:**
- `PopScope(canPop:false)` on the active-round screen so the Android **back button** can't even briefly bounce during the lock (redirect catches it today, but a hard block is cleaner).
- Live Activity **v2** (optional): push-to-update while the app is suspended + an App Group, so the speaker line advances in-pocket (today only the countdown does; content updates when the app is active — same as Android).

---

## 📋 REMAINING BACKLOG (from POST_TEST_FIXES.md + conclave-ux-requirements)

Active-round UX not yet built:
- **#3** Full-screen member view (timer top / Move-to-Table + expandable personal QR bottom)
- **#6** Mini-timer shows the current speaker's photo

App-wide:
- **#8/#13** Home "Live now" card + fill Home's empty space (impact stats, quick actions, upcoming)
- **#10** Graceful conclave off-boarding (smooth "that's a wrap" → summary, esp. ended-early) — needs a plan
- **#11** Custom branded icon set (one set, both platforms)

Operational:
- **Release 1.3.4** once tonight's tests pass (iOS + Play)
- **Delete the 3 test conclaves** (requested earlier — confirm whether done)
- **Client feedback** — user will send details; fold into the backlog

---

## 🔁 HOW TO RESUME

- All `flutter run` sessions were stopped at end of session. Relaunch as needed:
  - Android emulator: `flutter run -d emulator-5554`
  - iPhone (device): `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer flutter run -d <iphone-id>`
  - iPhone 17 sim: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer flutter run -d 41742A8C-5D53-4718-B7D8-1478CB753C7D`
- Global Flutter 3.47.8, JDK 21 for Android, Xcode 26.6 for iOS release.
- Uncommitted incidental files left alone: `.gitignore`, `ios/Podfile.lock` (Firestore pod removal), `ios/Runner/Info.plist` scene reorder.

_Memory note: `active-round-checkpoint.md` mirrors this._
