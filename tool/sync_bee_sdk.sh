#!/usr/bin/env bash
# Build the Bee Engine WASM SDK and copy it into assets/bee/pkg/.
#
# Usage: tool/sync_bee_sdk.sh /path/to/bee-engine
set -euo pipefail

BEE_ENGINE="${1:?usage: tool/sync_bee_sdk.sh /path/to/bee-engine}"
APP_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$APP_ROOT/assets/bee/pkg"

echo "==> patching MinerAccountData (expose on-chain session/epoch fields)"
"$APP_ROOT/tool/patch_bee_engine.py" "$BEE_ENGINE"

echo "==> building bee_sdk (wasm-pack --target web)"
( cd "$BEE_ENGINE/bee_sdk" && rm -rf pkg && wasm-pack build --target web )

echo "==> copying to $DEST"
rm -f "$DEST"/bee_sdk.js "$DEST"/bee_sdk_bg.wasm "$DEST"/bee_sdk.d.ts
mkdir -p "$DEST"
cp "$BEE_ENGINE"/bee_sdk/pkg/bee_sdk.js "$DEST/"
cp "$BEE_ENGINE"/bee_sdk/pkg/bee_sdk_bg.wasm "$DEST/"
# package.json / .d.ts are optional but harmless for reference
cp "$BEE_ENGINE"/bee_sdk/pkg/bee_sdk.d.ts "$DEST/" 2>/dev/null || true

echo "==> done. assets/bee/pkg now has:"
ls -la "$DEST"
