#!/usr/bin/env bash
# Rebuild VoiceInk locally (ad-hoc signed) and reinstall it into /Applications.
#
# Why this script exists: ad-hoc signed apps have their TCC permissions
# (Accessibility, Screen Recording) keyed by binary hash. Every rebuild
# changes the hash, which makes System Settings show the entry as "allowed"
# while the app actually fails the runtime permission check. This script
# resets those two TCC scopes so the OS forgets the stale grant; the user
# then re-adds the app to the relevant lists once, against the new hash.
#
# Steps:
#   1. Quit any running VoiceInk instance.
#   2. tccutil reset Accessibility + ScreenCapture for the bundle ID.
#      (Microphone usually survives ad-hoc rebuilds — not reset here.)
#   3. make local — produces ~/Downloads/VoiceInk.app.
#   4. Swap /Applications/VoiceInk.app for the fresh build.
#   5. Launch the new build and print the remaining manual step.

set -euo pipefail

BUNDLE_ID="com.prakashjoshipax.VoiceInk"
INSTALL_PATH="/Applications/VoiceInk.app"
BUILD_OUTPUT="$HOME/Downloads/VoiceInk.app"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

log() { printf "\033[1;34m▸\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m!\033[0m %s\n" "$*"; }

# 1. Stop the running app cleanly (best-effort).
if pgrep -f "${INSTALL_PATH}/Contents/MacOS/VoiceInk" >/dev/null 2>&1; then
    log "Quitting running VoiceInk"
    osascript -e "tell application id \"${BUNDLE_ID}\" to quit" 2>/dev/null || true
    for _ in 1 2 3 4 5; do
        sleep 0.5
        pgrep -f "${INSTALL_PATH}/Contents/MacOS/VoiceInk" >/dev/null 2>&1 || break
    done
    # Fallback: SIGTERM if still up.
    pkill -f "${INSTALL_PATH}/Contents/MacOS/VoiceInk" 2>/dev/null || true
    sleep 1
fi

# 2. Wipe stale TCC entries for permissions that rebuild invalidates.
log "Resetting TCC for ${BUNDLE_ID} (Accessibility, ScreenCapture)"
tccutil reset Accessibility "${BUNDLE_ID}" >/dev/null 2>&1 || true
tccutil reset ScreenCapture "${BUNDLE_ID}" >/dev/null 2>&1 || true

# 3. Build via the existing make target.
log "Running 'make local' in ${REPO_DIR}"
(cd "${REPO_DIR}" && make local)

if [ ! -d "${BUILD_OUTPUT}" ]; then
    echo "Build did not produce ${BUILD_OUTPUT}. Aborting install." >&2
    exit 1
fi

# 4. Swap binaries.
if [ -d "${INSTALL_PATH}" ]; then
    log "Removing previous ${INSTALL_PATH}"
    rm -rf "${INSTALL_PATH}"
fi
log "Installing fresh build to ${INSTALL_PATH}"
mv "${BUILD_OUTPUT}" "${INSTALL_PATH}"

# 5. Launch and explain the only manual step left.
log "Launching ${INSTALL_PATH}"
open "${INSTALL_PATH}"

cat <<'EOF'

✓ VoiceInk rebuilt and reinstalled.

Manual step (macOS forces this on ad-hoc rebuilds):

  System Settings → Privacy & Security
    → Accessibility:           remove the VoiceInk entry (−), then add it back (+)
    → Screen & System Audio:   same — remove, then add back

The TCC reset above already cleared the stale-hash record. The
remove/add dance is required because macOS keys these grants by the
binary's signature and there is no API for an unsigned app to grant
itself those permissions.

To eliminate this step permanently: sign the build with an Apple
Developer ID (paid account). TCC will then index by Team ID and
rebuilds become transparent.
EOF
