#!/usr/bin/env bash
#
# Builds the React renderer with esbuild and copies the output into the iPadOS
# app bundle as a `renderer/` resource folder loaded by the host WKWebView.
#
# The bridge JS folder (Resources/bridge) is bundled separately by Xcode.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEST="${ROOT_DIR}/ipados/Ferdium-iPadOS/Renderer"

echo "==> Building renderer (esbuild) in ${ROOT_DIR}"
cd "${ROOT_DIR}"
node esbuild.mjs

echo "==> Syncing ./build into ${DEST}"
rm -rf "${DEST}"
mkdir -p "${DEST}"
cp -R "${ROOT_DIR}/build/." "${DEST}/"

echo "==> Renderer bundle ready at ${DEST}"
