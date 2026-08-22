#!/usr/bin/env bash
#
# release.sh — build a signed AAB and ship it to Google Play.
#
# Handles: version-code bumping (synced with Play so it never collides),
# release notes, the build, the upload, staged production rollouts, and clean
# failures. See scripts/RELEASE.md for the one-time service-account setup.
#
# Examples:
#   scripts/release.sh                          # internal track, auto-notes
#   scripts/release.sh --internal --notes "Fixes 1-2-1 spam + branded loader"
#   scripts/release.sh --production --rollout 0.2   # 20% staged production
#   scripts/release.sh --production --version 1.1.0  # also bump version NAME
#   scripts/release.sh --no-bump                # reuse current version (retry upload)
#   scripts/release.sh --dry-run                # build + notes, skip upload
#
set -euo pipefail

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
PKG="com.manuen.conclave_1_2_1"
JSON_KEY="${PLAY_JSON_KEY:-$HOME/.conclave-secrets/play-service-account.json}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AAB="build/app/outputs/bundle/release/app-release.aab"
CHANGELOG_DIR="android/fastlane/metadata/android/en-US/changelogs"
cd "$PROJECT_DIR"

# ---------------------------------------------------------------------------
# Args
# ---------------------------------------------------------------------------
TRACK="internal"
ROLLOUT=""
NOTES=""
NOTES_FILE=""
VERSION_NAME=""
DO_BUMP=1
SYNC=1
DRY_RUN=0

usage() {
  cat <<'EOF'
release.sh — build a signed AAB and ship it to Google Play.

  scripts/release.sh                       Internal track, auto notes
  scripts/release.sh --production          Production, full rollout
  scripts/release.sh --production --rollout 0.2   Staged 20% production
  scripts/release.sh --version 1.1.0       Also bump the version name
  scripts/release.sh --notes "..."         Set release notes inline
  scripts/release.sh --notes-file PATH     Release notes from a file
  scripts/release.sh --no-bump             Reuse current version (retry upload)
  scripts/release.sh --no-sync             Don't query Play for the version code
  scripts/release.sh --dry-run             Build + notes, no upload

Setup (one-time): scripts/RELEASE.md
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --internal)     TRACK="internal"; shift;;
    --production)   TRACK="production"; shift;;
    --track)        TRACK="$2"; shift 2;;
    --rollout)      ROLLOUT="$2"; shift 2;;
    --notes)        NOTES="$2"; shift 2;;
    --notes-file)   NOTES_FILE="$2"; shift 2;;
    --version)      VERSION_NAME="$2"; shift 2;;
    --no-bump)      DO_BUMP=0; shift;;
    --no-sync)      SYNC=0; shift;;
    --dry-run)      DRY_RUN=1; shift;;
    -h|--help)      usage; exit 0;;
    *) echo "Unknown arg: $1"; usage; exit 1;;
  esac
done

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
bold=$(tput bold 2>/dev/null || true); red=$(tput setaf 1 2>/dev/null || true)
grn=$(tput setaf 2 2>/dev/null || true); ylw=$(tput setaf 3 2>/dev/null || true)
rst=$(tput sgr0 2>/dev/null || true)
step() { echo; echo "${bold}==> $*${rst}"; }
ok()   { echo "${grn}✓ $*${rst}"; }
warn() { echo "${ylw}! $*${rst}"; }
die()  { echo "${red}✗ $*${rst}" >&2; exit 1; }

PUBSPEC_BACKED_UP=0
on_err() {
  local line=$1
  echo
  echo "${red}${bold}Release failed (line $line).${rst}" >&2
  # Roll back the version bump only if we hadn't built the AAB yet — once the
  # AAB exists with the new code, keep it so a --no-bump retry can reuse it.
  if [[ $PUBSPEC_BACKED_UP -eq 1 && ! -f "$AAB.done" ]]; then
    mv -f pubspec.yaml.rel.bak pubspec.yaml 2>/dev/null && warn "Restored pubspec.yaml"
  fi
  rm -f "$AAB.done"
  exit 1
}
trap 'on_err $LINENO' ERR

# ---------------------------------------------------------------------------
# JDK
# ---------------------------------------------------------------------------
if [[ -z "${JAVA_HOME:-}" || ! -x "${JAVA_HOME:-}/bin/java" ]]; then
  if JH=$(/usr/libexec/java_home 2>/dev/null); then export JAVA_HOME="$JH"
  elif [[ -x "/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/java" ]]; then
    export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
  fi
fi
[[ -x "${JAVA_HOME:-}/bin/java" ]] || die "No JDK found. Install one or set JAVA_HOME."
export PATH="$JAVA_HOME/bin:$PATH"

# ---------------------------------------------------------------------------
# Preconditions
# ---------------------------------------------------------------------------
step "Checking prerequisites"
command -v flutter >/dev/null || die "flutter not on PATH."
[[ -f android/key.properties ]] || die "android/key.properties missing — release signing not configured."
STORE_FILE=$(grep -E '^storeFile=' android/key.properties | cut -d= -f2-)
STORE_FILE="${STORE_FILE/#\~/$HOME}"
[[ -f "$STORE_FILE" ]] || die "Keystore not found at: $STORE_FILE"
if [[ $DRY_RUN -eq 0 ]]; then
  command -v fastlane >/dev/null || die "fastlane not installed. Run: brew install fastlane  (see scripts/RELEASE.md)"
  [[ -f "$JSON_KEY" ]] || die "Play service-account JSON not found at: $JSON_KEY
  Create it once (see scripts/RELEASE.md), then re-run."
fi
export PLAY_JSON_KEY="$JSON_KEY"
ok "JDK, signing$([[ $DRY_RUN -eq 0 ]] && echo ', fastlane, service account') ready"
echo "  Track: ${bold}$TRACK${rst}${ROLLOUT:+  (rollout ${ROLLOUT})}${DRY_RUN:+  [DRY RUN]}"

# ---------------------------------------------------------------------------
# Version
# ---------------------------------------------------------------------------
CUR_LINE=$(grep -m1 '^version:' pubspec.yaml)
CUR_NAME=$(echo "$CUR_LINE" | sed -E 's/^version:[[:space:]]*([^+]+)\+.*/\1/')
CUR_CODE=$(echo "$CUR_LINE" | sed -E 's/.*\+([0-9]+).*/\1/')
NEW_NAME="${VERSION_NAME:-$CUR_NAME}"
NEW_CODE="$CUR_CODE"

if [[ $DO_BUMP -eq 1 ]]; then
  step "Choosing versionCode"
  PLAY_MAX=0
  if [[ $DRY_RUN -eq 0 && $SYNC -eq 1 ]]; then
    echo "  Asking Play for the highest versionCode…"
    if OUT=$(cd android && fastlane android latest_code 2>&1); then
      PLAY_MAX=$(echo "$OUT" | grep -oE 'LATEST_CODE=[0-9]+' | head -1 | cut -d= -f2)
      PLAY_MAX="${PLAY_MAX:-0}"
      echo "  Play highest: $PLAY_MAX"
    else
      warn "Could not read Play version codes; bumping locally."
    fi
  fi
  HIGHEST=$(( CUR_CODE > PLAY_MAX ? CUR_CODE : PLAY_MAX ))
  NEW_CODE=$(( HIGHEST + 1 ))
  cp pubspec.yaml pubspec.yaml.rel.bak; PUBSPEC_BACKED_UP=1
  # Portable in-place edit.
  perl -0pi -e "s/^version:.*\$/version: ${NEW_NAME}+${NEW_CODE}/m" pubspec.yaml
  ok "Version ${CUR_NAME}+${CUR_CODE} → ${bold}${NEW_NAME}+${NEW_CODE}${rst}"
else
  warn "Skipping bump — building version ${NEW_NAME}+${NEW_CODE} as-is."
fi

# ---------------------------------------------------------------------------
# Release notes  (Play caps a changelog at 500 chars)
# ---------------------------------------------------------------------------
step "Release notes"
if [[ -n "$NOTES_FILE" ]]; then
  [[ -f "$NOTES_FILE" ]] || die "Notes file not found: $NOTES_FILE"
  NOTES="$(cat "$NOTES_FILE")"
elif [[ -z "$NOTES" && -f scripts/release_notes.txt ]]; then
  NOTES="$(cat scripts/release_notes.txt)"
fi
[[ -n "$NOTES" ]] || NOTES="Bug fixes and improvements."
if [[ ${#NOTES} -gt 500 ]]; then
  warn "Notes are ${#NOTES} chars; Play caps at 500. Truncating."
  NOTES="${NOTES:0:497}..."
fi
mkdir -p "$CHANGELOG_DIR"
printf '%s\n' "$NOTES" > "$CHANGELOG_DIR/${NEW_CODE}.txt"
echo "  → $CHANGELOG_DIR/${NEW_CODE}.txt"
echo "  ┌────────────────────────────────────────"
echo "$NOTES" | sed 's/^/  │ /'
echo "  └────────────────────────────────────────"

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------
step "Building signed AAB"
flutter pub get >/dev/null
flutter build appbundle --release
[[ -f "$AAB" ]] || die "Build reported success but $AAB is missing."
touch "$AAB.done"
ok "Built $AAB ($(du -h "$AAB" | cut -f1))"

# ---------------------------------------------------------------------------
# Upload
# ---------------------------------------------------------------------------
if [[ $DRY_RUN -eq 1 ]]; then
  echo; ok "DRY RUN complete — AAB built and notes written, nothing uploaded."
  rm -f "$AAB.done"
  exit 0
fi

step "Uploading to Play ($TRACK)"
( cd android && fastlane android deploy \
    aab:"../$AAB" \
    track:"$TRACK" \
    rollout:"$ROLLOUT" )

rm -f "$AAB.done" pubspec.yaml.rel.bak
echo
ok "Released ${bold}${NEW_NAME}+${NEW_CODE}${rst} to ${bold}$TRACK${rst}."
echo "  Commit the version bump:  git add pubspec.yaml android/fastlane && git commit -m \"chore(release): ${NEW_NAME}+${NEW_CODE}\""
