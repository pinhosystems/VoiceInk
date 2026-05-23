#!/usr/bin/env bash
# One-time setup: generate a self-signed code-signing certificate named
# "VoiceInk Local Dev" and import it into the user's login keychain.
#
# Why: ad-hoc signing (`codesign -s -`) makes every rebuild produce a
# binary with a fresh cdhash. macOS keys TCC grants (Accessibility,
# Screen Recording, etc.) to the binary's *Designated Requirement*, and
# for ad-hoc binaries the DR includes that cdhash, so each rebuild
# invalidates every prior grant. Signing with a stable cert produces a
# stable DR (it references the cert's SubjectKeyHash / common name),
# which makes TCC carry grants forward across rebuilds.
#
# This script is idempotent — running it twice will detect the existing
# certificate and exit early. To start over, run with `--force` (which
# deletes the existing identity from the login keychain first).
#
# After running this script once, `make install-local` will produce a
# binary that keeps its Accessibility / Screen Recording / Microphone /
# AppleEvents grants across rebuilds.

set -euo pipefail

CERT_NAME="VoiceInk Local Dev"
KEYCHAIN="${HOME}/Library/Keychains/login.keychain-db"
VALID_DAYS=3650
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

log()  { printf "\033[1;34m▸\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m!\033[0m %s\n" "$*"; }
ok()   { printf "\033[1;32m✓\033[0m %s\n" "$*"; }

FORCE=0
if [ "${1:-}" = "--force" ]; then
    FORCE=1
fi

# Detect existing identity. Self-signed code-signing certs come up as
# `CSSMERR_TP_NOT_TRUSTED` under `find-identity -v` even though codesign
# accepts them for signing (trust matters only for verifying), so the
# probe omits `-v` and matches on the certificate's common name.
existing_identity() {
    security find-identity -p codesigning "${KEYCHAIN}" 2>/dev/null \
        | grep -F "\"${CERT_NAME}\"" || true
}

if [ -n "$(existing_identity)" ]; then
    if [ "${FORCE}" -eq 1 ]; then
        warn "Removing existing '${CERT_NAME}' identity (--force)"
        # `security delete-identity` only works when the cert is matched
        # by SHA-1. Pull the SHA from find-identity and remove that and
        # the underlying certificate / private key by common name.
        SHA="$(existing_identity | head -1 | awk '{print $2}')"
        if [ -n "${SHA}" ]; then
            security delete-identity -Z "${SHA}" "${KEYCHAIN}" >/dev/null 2>&1 || true
        fi
        security delete-certificate -c "${CERT_NAME}" "${KEYCHAIN}" >/dev/null 2>&1 || true
    else
        ok "Certificate '${CERT_NAME}' is already installed in the login keychain."
        echo "   Use --force to regenerate."
        exit 0
    fi
fi

log "Generating self-signed code-signing cert '${CERT_NAME}'"

cat > "${TMP_DIR}/openssl.cnf" <<EOF
[ req ]
default_bits        = 2048
default_md          = sha256
prompt              = no
distinguished_name  = dn
x509_extensions     = v3_codesign

[ dn ]
CN = ${CERT_NAME}

[ v3_codesign ]
basicConstraints     = critical, CA:FALSE
keyUsage             = critical, digitalSignature
extendedKeyUsage     = critical, codeSigning
subjectKeyIdentifier = hash
EOF

openssl req -x509 -newkey rsa:2048 -nodes \
    -keyout "${TMP_DIR}/key.pem" \
    -out "${TMP_DIR}/cert.pem" \
    -days "${VALID_DAYS}" \
    -config "${TMP_DIR}/openssl.cnf" 2>/dev/null

# macOS `security import` silently fails on PKCS#12 archives that carry
# an empty password — give the bundle a throwaway non-empty passphrase
# that lives only inside this script run, then hand the same string to
# the importer below.
P12_PASS="setup-local-signing"

openssl pkcs12 -export -legacy \
    -inkey "${TMP_DIR}/key.pem" \
    -in "${TMP_DIR}/cert.pem" \
    -name "${CERT_NAME}" \
    -out "${TMP_DIR}/bundle.p12" \
    -passout "pass:${P12_PASS}" 2>/dev/null

log "Importing into login keychain (granting codesign tool access)"
security import "${TMP_DIR}/bundle.p12" \
    -k "${KEYCHAIN}" \
    -P "${P12_PASS}" \
    -T /usr/bin/codesign \
    -T /usr/bin/security \
    -T /usr/bin/productbuild \
    >/dev/null 2>&1

# Without this, `codesign` will prompt for the private key on first use.
# `security set-key-partition-list` widens the ACL to cover Apple's code
# signing tools. The password prompt is for the keychain itself, so this
# call is the only step that requires the user to interact (typing the
# login password). On most setups this is unattended thanks to the
# already-unlocked login keychain.
log "Granting codesign tool access to the new key (you may be prompted for your login password)"
security set-key-partition-list \
    -S apple-tool:,apple: \
    -s \
    -k "$(security default-keychain | tr -d '\" ' | xargs -I {} security unlock-keychain -p '' '{}' 2>/dev/null || true)" \
    "${KEYCHAIN}" >/dev/null 2>&1 || \
security set-key-partition-list \
    -S apple-tool:,apple: \
    -s \
    "${KEYCHAIN}" || true

# Verify the certificate is now findable as a code-signing identity.
if [ -z "$(existing_identity)" ]; then
    echo "✗ Failed to register '${CERT_NAME}' as a code-signing identity." >&2
    echo "   Try running this script again with --force, or inspect Keychain Access." >&2
    exit 1
fi

ok "'${CERT_NAME}' is registered as a code-signing identity"
cat <<EOF

Next steps:
  1. Run \`make install-local\` — the Makefile picks up
     LOCAL_SIGNING_IDENTITY="${CERT_NAME}" by default.
  2. The FIRST install will still need a TCC re-grant (the new
     requirement string differs from the previous ad-hoc binaries).
     After that, subsequent installs preserve all permissions.

To override the identity name, export LOCAL_SIGNING_IDENTITY before
calling make.
EOF
