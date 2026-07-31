#!/usr/bin/env bash
# install-local.sh — build jj-ice.app from source (Release, unsigned) and install it locally.
#
# Pre-deploy gate: a successful run means the release build compiles AND the app is
# delivered on this machine. Mirrors .github/workflows/release.yml build+package steps.
#
# Usage:
#   bash scripts/install-local.sh
#   INSTALL_DIR="$HOME/Applications" bash scripts/install-local.sh

set -euo pipefail

PROJECT="jj-ice.xcodeproj"
SCHEME="jj-ice"
APP_NAME="jj-ice.app"
DERIVED="build"
INSTALL_DIR="${INSTALL_DIR:-/Applications}"

err()  { printf 'error: %s\n' "$*" >&2; exit 1; }
info() { printf '%s\n' "$*"; }

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

[ -d "$PROJECT" ] || err "$PROJECT not found (run from the repository)"
command -v xcodebuild >/dev/null 2>&1 || err "xcodebuild is required (install Xcode)"

version="$(
  xcodebuild -showBuildSettings -project "$PROJECT" -scheme "$SCHEME" -configuration Release 2>/dev/null \
    | awk -F' = ' '/ MARKETING_VERSION =/ { gsub(/ /, "", $2); print $2; exit }'
)"
[ -n "$version" ] || err "failed to read MARKETING_VERSION"

info "==> Building ${APP_NAME} v${version} (Release, unsigned)"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  clean build

app="${DERIVED}/Build/Products/Release/${APP_NAME}"
[ -d "$app" ] || err "$app not found after build"

dest="${INSTALL_DIR}/${APP_NAME}"
info "==> Installing to ${dest}"
mkdir -p "$INSTALL_DIR"

# Quit a running instance so the replaced bundle is not half-live.
pkill -x "${APP_NAME%.app}" 2>/dev/null || true

# Stage then swap: a failed copy must not leave the machine without the app.
staged="${dest}.new"
rm -rf "$staged"
ditto "$app" "$staged"
xattr -dr com.apple.quarantine "$staged" 2>/dev/null || true
rm -rf "$dest"
mv "$staged" "$dest"

info "==> Installed: ${dest} (v${version})"
info "    launch: open \"${dest}\""
