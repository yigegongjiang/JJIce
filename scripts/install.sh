#!/usr/bin/env bash
# install.sh — download jj-ice.app from GitHub Releases and install into /Applications.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/<owner>/jj-ice/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/<owner>/jj-ice/main/install.sh | VERSION=v0.0.1 bash
#   INSTALL_DIR="$HOME/Applications" ./install.sh
#
# The build is unsigned: this script strips the quarantine attribute so Gatekeeper
# allows the first launch without a right-click "Open" dance.

set -euo pipefail

REPO="${REPO:-yigegongjiang/jj-ice}"
VERSION="${VERSION:-latest}"
INSTALL_DIR="${INSTALL_DIR:-/Applications}"
ASSET="jj-ice-macos.zip"
APP_NAME="jj-ice.app"

err()  { printf 'error: %s\n' "$*" >&2; exit 1; }
info() { printf '%s\n' "$*"; }

command -v curl  >/dev/null 2>&1 || err "curl is required"
command -v ditto >/dev/null 2>&1 || err "ditto is required (macOS only)"

case "$(uname -s)" in
  Darwin) ;;
  *) err "unsupported OS: $(uname -s) (only macOS is supported)" ;;
esac

if [ "$VERSION" = "latest" ]; then
  base="https://github.com/${REPO}/releases/latest/download"
else
  base="https://github.com/${REPO}/releases/download/${VERSION}"
fi
asset_url="${base}/${ASSET}"
checksums_url="${base}/checksums.txt"

info "==> Installing ${APP_NAME} ${VERSION}"
info "    repo:   ${REPO}"
info "    target: ${INSTALL_DIR}/${APP_NAME}"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

tmp_zip="${tmpdir}/${ASSET}"
info "==> Downloading"
curl -fsSL --retry 3 -o "$tmp_zip" "$asset_url" || err "download failed: $asset_url"

# Verify SHA256 if checksums.txt is published with the release.
if hash_line="$(curl -fsSL --retry 3 "$checksums_url" 2>/dev/null | grep " ${ASSET}$" || true)"; then
  if [ -n "$hash_line" ]; then
    expected="${hash_line%% *}"
    actual="$(shasum -a 256 "$tmp_zip" | awk '{print $1}')"
    [ "$expected" = "$actual" ] || err "checksum mismatch for ${ASSET} (expected ${expected}, got ${actual})"
    info "==> Checksum OK"
  fi
fi

info "==> Extracting"
ditto -x -k "$tmp_zip" "${tmpdir}/extracted"
src_app="${tmpdir}/extracted/${APP_NAME}"
[ -d "$src_app" ] || err "extracted archive does not contain ${APP_NAME}"

# Unsigned build: strip quarantine so Gatekeeper allows launch.
xattr -dr com.apple.quarantine "$src_app" 2>/dev/null || true

dest="${INSTALL_DIR}/${APP_NAME}"
info "==> Installing to ${dest}"
mkdir -p "$INSTALL_DIR"
rm -rf "$dest"
mv "$src_app" "$dest"

info "==> Installed: ${dest}"
info "    launch: open \"${dest}\""
