#!/bin/bash
# Same as package.sh, then launches the app (handy during development).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
"$SCRIPT_DIR/package.sh"

echo "🚀  Launching MarketView…"
open "$SCRIPT_DIR/MarketView.app"
echo "✅  Done — look for MarketView in your menu bar."
