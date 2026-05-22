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
LOCAL_SIGNING_IDENTITY="${LOCAL_SIGNING_IDENTITY:-VoiceInk Local Dev}"
LOGIN_KEYCHAIN="${HOME}/Library/Keychains/login.keychain-db"

log() { printf "\033[1;34m▸\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m!\033[0m %s\n" "$*"; }

# Is the stable self-signed identity available? When it is, we sign the
# build with a cert whose requirement string doesn't change between
# rebuilds, so TCC grants persist and we can skip the destructive
# tccutil reset below.
has_stable_signing_identity() {
    security find-identity -p codesigning -v "${LOGIN_KEYCHAIN}" 2>/dev/null \
        | grep -qF "\"${LOCAL_SIGNING_IDENTITY}\""
}

# Allow callers to force a TCC reset even when signed (RESET_TCC=1).
# Default policy: reset only for ad-hoc builds.
RESET_TCC="${RESET_TCC:-auto}"
if [ "${RESET_TCC}" = "auto" ]; then
    if has_stable_signing_identity; then
        RESET_TCC=0
    else
        RESET_TCC=1
    fi
fi

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

# 2. Wipe stale TCC entries for every permission scope VoiceInk requests
#    — but only when the build is ad-hoc signed.
#
#    Ad-hoc rebuilds change the binary's cdhash, and tccd silently
#    rejects permission attempts whose stored csreq no longer matches.
#    Resetting every relevant scope forces tccd to treat the next launch
#    as a first install and write a new csreq against the current cdhash.
#
#    When `make setup-signing` has been run, builds are signed by a
#    stable self-signed identity whose Designated Requirement does not
#    change between rebuilds — TCC grants carry over without a reset.
#    Skip the destructive sweep in that case (set RESET_TCC=1 to force).
if [ "${RESET_TCC}" -eq 1 ]; then
    log "Resetting TCC for ${BUNDLE_ID} (all VoiceInk scopes)"
    for scope in Accessibility ScreenCapture Microphone AppleEvents PostEvent ListenEvent; do
        tccutil reset "${scope}" "${BUNDLE_ID}" >/dev/null 2>&1 || true
    done
else
    log "Stable signing identity detected — TCC grants will persist across rebuilds"
fi

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

# 5. Force Launch Services to re-index the bundle so its in-memory cache of
#    the previous cdhash is dropped. Without this, the OS sometimes consults
#    the cached requirement string from the previous build and the toggle in
#    System Settings still won't stick.
LS_REGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [ -x "${LS_REGISTER}" ]; then
    log "Re-registering ${INSTALL_PATH} with Launch Services"
    "${LS_REGISTER}" -u "${INSTALL_PATH}" >/dev/null 2>&1 || true
    "${LS_REGISTER}" -f "${INSTALL_PATH}" >/dev/null 2>&1 || true
fi

# 6. Launch and explain the only manual step left.
log "Launching ${INSTALL_PATH}"
open "${INSTALL_PATH}"

if [ "${RESET_TCC}" -eq 1 ]; then
    cat <<'EOF'

✓ VoiceInk rebuilt, reinstalled to /Applications, TCC reset, and launched.

If a permission prompt appears, click "Open System Settings" and toggle
ON. The fields below already had any stale-hash records cleared:

  System Settings → Privacy & Security
    → Accessibility            (global hotkey + paste)
    → Screen & System Audio    (screen-context capture)
    → Microphone               (recording)

If a toggle still refuses to flip ("checkbox doesn't stick"), remove the
VoiceInk entry from that list with the (−) button and add it back with
(+) pointing at /Applications/VoiceInk.app — that forces macOS to write
a fresh requirement string against the current ad-hoc signature.

Tired of granting permissions on every rebuild?
  Run once:  make setup-signing
  Then:      make install-local
The setup target provisions a stable self-signed identity in your login
keychain. Subsequent installs reuse it, the Designated Requirement stays
fixed across builds, and TCC stops invalidating your grants.
EOF
else
    cat <<'EOF'

✓ VoiceInk rebuilt, reinstalled to /Applications, and launched.

TCC grants were preserved this run (stable signing identity in use).
If this is the first time you've installed the app under this identity,
you'll still need to grant permissions once for:

  System Settings → Privacy & Security
    → Accessibility            (global hotkey + paste)
    → Screen & System Audio    (screen-context capture)

Subsequent rebuilds will keep those grants.
EOF
fi
