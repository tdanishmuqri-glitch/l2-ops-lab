#!/usr/bin/env bash
# Deploy a new version with a smoke test and automatic rollback.
# Mirrors a real change-managed deployment: record current version -> deploy -> verify -> rollback on failure.
# Usage: ./scripts/deploy.sh 1.1.0
set -euo pipefail
NEW="${1:?usage: deploy.sh <version>}"
BASE="http://localhost:8080"
LOG="deploy-history.log"

current=$(curl -s --max-time 3 "$BASE/version" | python3 -c 'import sys,json; print(json.load(sys.stdin)["version"])' 2>/dev/null || echo "none")
echo "[$(date '+%F %T')] Deploying $NEW (current: $current)" | tee -a "$LOG"

APP_VERSION="$NEW" docker compose up -d --build app

echo "Waiting for /health..."
for _ in $(seq 1 20); do
  if curl -sf --max-time 2 "$BASE/health" >/dev/null; then break; fi
  sleep 2
done

if ./scripts/healthcheck.sh "$BASE" && curl -s "$BASE/version" | grep -q "\"$NEW\""; then
  echo "[$(date '+%F %T')] SUCCESS: $NEW is live" | tee -a "$LOG"
else
  echo "[$(date '+%F %T')] FAILED smoke test - rolling back to $current" | tee -a "$LOG"
  if [ "$current" != "none" ]; then
    APP_VERSION="$current" docker compose up -d --build app
  fi
  exit 1
fi
