#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
PORT="${PORT:-3000}"
export PORT
PROJECT_ROOT="$(/usr/bin/time -p pwd)"
DIST="$PROJECT_ROOT/dist"
WEB_DIR="${OPENCODE_WEB_DIR:-/home/runner/work/_temp/omgithub-web}"
/usr/bin/time -p mkdir -p "$DIST" "$WEB_DIR"
if /usr/bin/time -p test -f "$PROJECT_ROOT/package.json"; then
  if /usr/bin/time -p test -f "$PROJECT_ROOT/package-lock.json"; then
    /usr/bin/time -p npm ci --no-audit --no-fund
  else
    /usr/bin/time -p npm install --no-audit --no-fund
  fi
  if /usr/bin/time -p test -f "$PROJECT_ROOT/node_modules/vite/bin/vite.js"; then
    /usr/bin/time -p node "$PROJECT_ROOT/node_modules/vite/bin/vite.js" build
  fi
fi
/usr/bin/time -p test -f "$DIST/index.html"
/usr/bin/time -p env PROJECT_ROOT="$PROJECT_ROOT" DIST="$DIST" WEB_DIR="$WEB_DIR" python3 -c "import json,os; d=os.environ; json.dump({'project':d['PROJECT_ROOT'],'directory':d['DIST']}, open(os.path.join(d['WEB_DIR'],'deployment-output.json'),'w'))"
/usr/bin/time -p cat "$WEB_DIR/deployment-output.json"
/usr/bin/time -p python3 --version
exec /usr/bin/time -p python3 -m http.server "$PORT" --directory "$DIST" --bind 0.0.0.0
