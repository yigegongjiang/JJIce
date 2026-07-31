#!/usr/bin/env bash
# install-local.sh — build jj-ice.app from source and install it locally.
#
# Pre-deploy gate: a successful run means the release build compiles AND the app is
# delivered on this machine. The build itself lives in scripts/build-app.sh, the same
# script .github/workflows/release.yml runs.
#
# Usage:
#   bash scripts/install-local.sh

set -euo pipefail

APP_NAME="jj-ice.app"
INSTALL_DIR="/Applications"

err()  { printf 'error: %s\n' "$*" >&2; exit 1; }
info() { printf '%s\n' "$*"; }

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

bash scripts/build-app.sh

app="build/${APP_NAME}"
[ -d "$app" ] || err "$app not found after build"

dest="${INSTALL_DIR}/${APP_NAME}"
info "==> Installing to ${dest}"

# Quit a running instance so the replaced bundle is not half-live.
pkill -x "${APP_NAME%.app}" 2>/dev/null || true

# Stage then swap: a failed copy must not leave the machine without the app.
# No quarantine stripping here (unlike install.sh): the attribute is set by
# downloaders, never by a locally built product.
staged="${dest}.new"
rm -rf "$staged"
ditto "$app" "$staged"
rm -rf "$dest"
mv "$staged" "$dest"

# Menu bar agent: the pkill above took it out of the menu bar, so put it back.
# Leaving the machine without the tool that was just installed is not "delivered".
open "$dest"

info "==> Installed: ${dest}"
