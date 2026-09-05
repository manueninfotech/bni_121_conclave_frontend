# iOS release runbook (for Claude)

When the user says **"release the iOS version"**, **"push a new TestFlight build"**,
or **"submit to the App Store"**, follow this. It captures the two traps this
project hit: the **beta-vs-release Xcode split** and the **fastlane-Ruby breaks
CocoaPods** issue.

Default target: **TestFlight** (internal testers). Only go to App Store review
when the user explicitly asks.

---

## Constants
- App (iOS bundle id): `com.manuen.bniconclave`
- App Store Connect app id: **6809010007** ("BNI 1-2-1 Conclave")
- Apple team id: `3PH4PG45KG`
- ASC API key: id `79TJL426G2`, issuer `cb07fb7a-b51b-41a8-9466-d07c578a4790`,
  key at `~/.conclave-secrets/ASC_API_AuthKey_79TJL426G2.p8` (chmod 600, NEVER commit)
- iPhone-only: `TARGETED_DEVICE_FAMILY = "1"`
- Firebase iOS app has an **OAuth client** — the `REVERSED_CLIENT_ID` URL scheme in
  `Info.plist` and `iosClientId` in `firebase_options.dart` are required for phone
  auth on iOS. Don't remove them.

## The two Xcodes (this is the #1 trap)
- **Release Xcode 26.6** (`/Applications/Xcode.app`) → **all App Store / TestFlight
  builds**. Apple **rejects builds made with a beta Xcode** ("SDK build not
  supported yet").
- **Xcode 27 beta** (`/Applications/Xcode-beta.app`) → **only** for running/
  debugging on the physical iOS 26.6.1 iPhone (the sole Xcode with a working DDI).
- `xcode-select` is usually pointed at the beta. **Don't sudo-switch it** — override
  per-command with `DEVELOPER_DIR` instead:
  `export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`

## The CocoaPods trap
`fastlane ios beta` runs `flutter build ipa` **inside** fastlane's bundled Ruby,
which breaks CocoaPods ("installed but broken … different Ruby") whenever a
`pod install` is needed (e.g. after `flutter clean` or a new plugin). **Do the
Flutter build in a normal shell**, then upload via fastlane.

---

## Build + upload a new build (TestFlight)
```bash
cd <project>
# 1. bump the build number
#    pubspec.yaml: version: 1.1.x+N   (N must exceed the last uploaded build)
flutter analyze                       # must be clean

# 2. build the IPA in a NORMAL shell with the RELEASE Xcode
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
flutter clean                         # only if plugins/pods changed
flutter build ipa --release --export-method app-store
#   ^ the "No Accounts / No iOS Distribution certificate" errors at the end are
#     EXPECTED (Flutter can't mint a dist cert). What matters is the .xcarchive:
ls build/ios/archive/Runner.xcarchive # must exist

# 3. export a signed IPA with the ASC API key (creates cert/profile headlessly)
xcodebuild -exportArchive \
  -archivePath build/ios/archive/Runner.xcarchive \
  -exportPath build/ios/ipa \
  -exportOptionsPlist ios/ExportOptions.plist \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$HOME/.conclave-secrets/ASC_API_AuthKey_79TJL426G2.p8" \
  -authenticationKeyID 79TJL426G2 \
  -authenticationKeyIssuerID cb07fb7a-b51b-41a8-9466-d07c578a4790
ls build/ios/ipa/*.ipa                # must exist ("EXPORT SUCCEEDED")

# 4. upload to App Store Connect / TestFlight
cd ios && fastlane ios upload_only
```
Testers get the build once Apple finishes processing (~5–15 min). `fastlane ios
wait_build build:N` polls until it's `VALID`.

## Submit to App Store review (only when asked)
One-time metadata lives in `ios/fastlane/metadata` + `ios/fastlane/screenshots`
(demo account `9012340000 / Review@2026` in review notes). Before submitting,
these must be set **in the ASC web UI** (can't be done via API): **App Privacy**
questionnaire, **Age Rating**, and **Pricing = Free**. Then:
```bash
cd ios
fastlane ios push_metadata           # listing + 6.9" screenshots (skip if unchanged)
fastlane ios wait_build build:N      # wait for VALID
fastlane ios submit build:N          # submit_for_review, auto-release on approval
```
Screenshots must be **1290×2796** (iPhone 6.9"/6.7"). If starting from phone
marketing images of another aspect, pad with edge-replication (see how the first
set was made) — never stretch.

## When to stop and ask
- `flutter analyze` isn't clean, or there's a real bug.
- App Review rejects (read Resolution Center, fix, resubmit).
- The version-name bump is genuinely ambiguous.

Otherwise: build, upload, and (if asked) submit.
