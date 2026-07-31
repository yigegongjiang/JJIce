#!/usr/bin/env bash
# build-app.sh — build the Release binary and assemble it into build/jj-ice.app.
#
# Shared by scripts/install-local.sh and .github/workflows/release.yml so the locally
# installed app and the published artifact come out of one recipe.
#
# Universal (arm64 + x86_64): macOS 26 still runs on some Intel Macs, and plain
# `swift build` would only emit the host architecture.
#
# Usage: bash scripts/build-app.sh   -> build/jj-ice.app

set -euo pipefail

APP_NAME="jj-ice"
BUNDLE_ID="com.yigegongjiang.jj-ice"
BUNDLE="build/${APP_NAME}.app"
ARCHS=(--arch arm64 --arch x86_64)

err()  { printf 'error: %s\n' "$*" >&2; exit 1; }
info() { printf '%s\n' "$*"; }

cd "$(dirname "${BASH_SOURCE[0]}")/.."

[ -f Package.swift ] || err "Package.swift not found (run from the repository)"
command -v swift >/dev/null 2>&1 || err "swift is required (install Xcode)"

version="$(tr -d ' \t\n\r' < VERSION)"
[ -n "$version" ] || err "VERSION is empty"

info "==> [1/4] Building v${version} (Release, universal)"
swift build -c release "${ARCHS[@]}"
bin="$(swift build -c release "${ARCHS[@]}" --show-bin-path)/${APP_NAME}"
[ -x "$bin" ] || err "built binary not found: $bin"

info "==> [2/4] Assembling ${BUNDLE}"
rm -rf "$BUNDLE"
mkdir -p "${BUNDLE}/Contents/MacOS" "${BUNDLE}/Contents/Resources"
cp "$bin" "${BUNDLE}/Contents/MacOS/${APP_NAME}"
cp Resources/AppIcon.icns "${BUNDLE}/Contents/Resources/AppIcon.icns"
sed "s/@VERSION@/${version}/g" Resources/Info.plist.in > "${BUNDLE}/Contents/Info.plist"
printf 'APPL????' > "${BUNDLE}/Contents/PkgInfo"

info "==> [3/4] Ad-hoc signing"
# SMAppService refuses to register a login item for an unsigned bundle, so ad-hoc signing
# is a functional requirement, not cosmetics. The designated requirement is pinned to the
# identifier only (no cdhash): every rebuild changes the cdhash, and a cdhash-bound DR would
# revoke the user's login item on each upgrade.
codesign --force --sign - --identifier "$BUNDLE_ID" \
  -r="designated => identifier \"${BUNDLE_ID}\"" "$BUNDLE"
codesign --verify --strict "$BUNDLE" || err "signature verification failed"

info "==> [4/4] Built ${BUNDLE} (v${version}, $(lipo -archs "${BUNDLE}/Contents/MacOS/${APP_NAME}"))"
