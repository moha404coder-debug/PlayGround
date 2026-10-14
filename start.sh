#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
/usr/bin/time -p pwd
PROJECT_DIR="$(pwd)"
DIST="$PROJECT_DIR/dist"
PORT="${PORT:-3000}"
export PORT
WEB_DIR="${OPENCODE_WEB_DIR:-/home/runner/work/_temp/omgithub-web}"
/usr/bin/time -p mkdir -p "$WEB_DIR"
/usr/bin/time -p mkdir -p "$DIST"
if /usr/bin/time -p test -f "$PROJECT_DIR/package.json"; then
  if /usr/bin/time -p test -f "$PROJECT_DIR/package-lock.json"; then
    /usr/bin/time -p npm ci --no-audit --no-fund
  else
    /usr/bin/time -p npm install --no-audit --no-fund
  fi
  if /usr/bin/time -p node -e "process.exit(require('./package.json').scripts?.build ? 0 : 1)"; then
    /usr/bin/time -p npm run build
  fi
fi
if ! /usr/bin/time -p test -f "$DIST/index.html"; then
  if /usr/bin/time -p test -f "$PROJECT_DIR/index.html"; then
    /usr/bin/time -p cp "$PROJECT_DIR/index.html" "$DIST/index.html"
  else
    echo "Static deployment output must contain dist/index.html." >&2
    exit 1
  fi
fi
/usr/bin/time -p printf '{"project":%s,"directory":%s}' "\"$PROJECT_DIR\"" "\"$DIST\"" > "$WEB_DIR/deployment-output.json"
/usr/bin/time -p cat "$WEB_DIR/deployment-output.json"
/usr/bin/time -p node "$PROJECT_DIR/server.mjs" "$DIST"
