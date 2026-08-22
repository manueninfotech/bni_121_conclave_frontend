# Release runbook (for Claude)

When the user says **"release"**, **"release a new version"**, **"ship it"**, or
similar, run this end-to-end and only stop to ask if something below says so.
Default target is **production, submitted for review**. `scripts/RELEASE.md` is
the human setup guide; this is my operating procedure.

---

## 0. Decide the target and version
- **Track:** default **production** (full rollout → review). Use `--internal`
  only if the user says testing/internal; `--rollout 0.2` if they say staged/%.
- **Version name:** bump by intent —
  - mostly **fixes** → **patch** (e.g. 1.1.0 → 1.1.1)
  - **new features** → **minor** (e.g. 1.1.0 → 1.2.0)
  - If genuinely ambiguous, ask; otherwise decide and proceed.
- **versionCode:** don't pick it by hand — `release.sh` syncs with Play and uses
  `max(local, Play) + 1`.

## 1. Pre-flight (fix or stop if any fails)
```bash
cd <project>
flutter analyze          # MUST be clean
git status --short       # intended changes committed?
git push                 # ensure frontend is pushed
```
- If the **backend** repo (`~/Documents/web/bni-1-2-1-backend`) has unpushed
  commits this release depends on, push them first (onrender auto-deploys).
- If analyze fails or there's an obvious bug → **stop and tell the user**, don't
  release broken code.

## 2. Secure the Play key (one-time, but always verify)
Expected at `~/.conclave-secrets/play-service-account.json` (chmod 600, NOT in
the repo). If it's missing, check the project dir and move it out:
```bash
ls -la ~/.conclave-secrets/play-service-account.json || \
  { mv <project>/.conclave-secrets/play-service-account.json ~/.conclave-secrets/ 2>/dev/null; \
    chmod 600 ~/.conclave-secrets/play-service-account.json; }
git check-ignore .conclave-secrets  # must be ignored
```
A service-account key in git is a leak — never let it get committed.

## 3. Verify Play auth + read current state
```bash
cd <project>/android
fastlane android latest_code                                  # LATEST_CODE=<n>, no auth error
fastlane run google_play_track_version_codes track:production \
  json_key:"$HOME/.conclave-secrets/play-service-account.json" \
  package_name:com.manuen.conclave_1_2_1                      # what's live/in review now
```
If auth fails → the service account or its Play permissions aren't set up; point
the user at `scripts/RELEASE.md` step 3.

## 4. Write the release notes
Update `scripts/release_notes.txt` to a short, **user-facing** "What's new"
that matches THIS release. Derive it from commits since the last release:
```bash
git log --oneline "$(git log --oneline | grep -m1 'chore(release):' | awk '{print $1}')"..HEAD
```
Keep it ≤ 500 chars (Play caps a changelog). Lead with headline features/fixes,
plain language, no internal jargon.

## 5. Release
```bash
cd <project>
scripts/release.sh --production --version X.Y.Z          # normal
# scripts/release.sh --production --rollout 0.2          # staged
# scripts/release.sh --internal --version X.Y.Z          # testing
```
The script: syncs the versionCode, writes the changelog, builds the signed AAB
(auto-detects the JDK), uploads, and rolls back the version bump on failure.

## 6. Commit + report
```bash
git add pubspec.yaml android/fastlane scripts/release_notes.txt
git commit -m "chore(release): X.Y.Z+N to production" && git push
```
Then report: version shipped, track, "submitted for review", and to watch it in
**Play Console → Production → Releases**.

---

## Failure handling
- **Build fails (R8/compile):** read the error. If it's a known plugin R8 issue,
  add a keep rule in `android/app/proguard-rules.pro`; otherwise fix the code.
  Don't retry blindly.
- **`versionCode already used`:** re-run `release.sh` (it bumps again). If a build
  already exists for that code, `--no-bump` reuses it.
- **Upload fails after a successful build:** fix the cause, then
  `scripts/release.sh --no-bump` to retry the upload without rebuilding.
- **Auth / permission errors:** the key or its Play grants; don't guess — surface
  it to the user with the `scripts/RELEASE.md` reference.

## When to interfere (ask the user)
- `flutter analyze` isn't clean, or there's a real bug in the diff.
- The version-name bump is genuinely ambiguous.
- A backend change this release needs isn't deployed.
- Anything that would ship broken or wrong to real users.

Otherwise: go through all of the above and release it.
