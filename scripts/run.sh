#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
pkill -f "$ROOT/build/Otter.app/Contents/MacOS/Otter" 2>/dev/null || true
"$ROOT/scripts/build.sh"
open "$ROOT/build/Otter.app"
echo "launched"
