# Releasing to Google Play

Automated with `scripts/release.sh`. After the **one-time setup** below, every
release is a single command.

---

## One-time setup (you must do this — it needs your Google login)

### 1. Install fastlane
```bash
brew install fastlane
```

### 2. Create a Play service account (Google Cloud)
1. Go to <https://console.cloud.google.com/> and select the project
   **`conclave-1-2-1`** (the app's Firebase/GCP project).
2. **APIs & Services → Library →** search **"Google Play Android Developer API"**
   → **Enable**.
3. **IAM & Admin → Service Accounts → Create service account**
   - Name: `play-publisher` → **Create and continue** → skip roles → **Done**.
4. Open the new service account → **Keys → Add key → Create new key → JSON**.
   A `.json` file downloads.
5. Move it to the path the script expects:
   ```bash
   mkdir -p ~/.conclave-secrets
   mv ~/Downloads/conclave-1-2-1-*.json ~/.conclave-secrets/play-service-account.json
   chmod 600 ~/.conclave-secrets/play-service-account.json
   ```

### 3. Grant it access in Play Console
1. Go to <https://play.google.com/console/> → **Users and permissions**.
2. **Invite new users** → paste the service account **email**
   (looks like `play-publisher@conclave-1-2-1.iam.gserviceaccount.com`).
3. **App permissions →** add **BNI 121 Conclave**.
4. **Account permissions →** enable at least:
   - *Release to testing tracks* and *Release apps to production* (or *Release manager*),
   - *View app information*.
5. **Invite user / Save.** (Access can take a few minutes to propagate.)

### 4. Verify
```bash
scripts/release.sh --dry-run      # builds the AAB, writes notes, uploads nothing
cd android && fastlane android latest_code   # should print LATEST_CODE=<n> with no auth error
```

---

## Releasing

The script bumps the versionCode (synced with Play so it never collides), writes
the changelog, builds the signed AAB, and uploads it.

```bash
# Internal testing (safe default)
scripts/release.sh --internal --notes "Short user-facing summary"

# Production — full rollout
scripts/release.sh --production

# Production — staged 20% rollout
scripts/release.sh --production --rollout 0.2

# Also bump the version NAME (marketing version)
scripts/release.sh --production --version 1.1.0

# Reuse the current version to RETRY a failed upload (no rebuild-bump)
scripts/release.sh --no-bump

# Build + notes only, no upload
scripts/release.sh --dry-run
```

**Release notes:** taken from `--notes "..."`, or `--notes-file path`, or
`scripts/release_notes.txt` by default. Play caps a changelog at 500 chars.

After a successful release the script prints the git command to commit the
version bump. Do commit it, so the repo's version matches Play.

---

## Notes & gotchas
- The backend URL is resolved at runtime from **Firebase Remote Config**
  (defaults to onrender prod), so release builds need **no `--dart-define`**.
- Signing uses `android/key.properties` + the keystore at
  `~/.conclave-secrets/conclave-release.jks` — keep both safe and off git.
- The service-account JSON grants publishing rights — never commit it. It lives
  outside the repo at `~/.conclave-secrets/`.
- First-ever production release: if Play requires it, promote the internal build
  in the console once; API-based production releases work thereafter.
- `PLAY_JSON_KEY=/path/to/key.json scripts/release.sh …` overrides the key path.
