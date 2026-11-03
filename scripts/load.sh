#!/usr/bin/env bash
# Generate realistic scan traffic so dashboards and alerts have data.
# Usage: ./scripts/load.sh [requests] [base_url]
set -uo pipefail
N="${1:-300}"; BASE="${2:-http://localhost:8080}"
codes=(SPX-1001 SPX-1002 SPX-2001 SPX-2002 SPX-3001 FAKE-0001 FAKE-0002)
countries=(MY SG ID TH PH)
ok=0; err=0
for _ in $(seq 1 "$N"); do
  c=${codes[$RANDOM % ${#codes[@]}]}; k=${countries[$RANDOM % ${#countries[@]}]}
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 -X POST "$BASE/verify" \
         -H 'Content-Type: application/json' -d "{\"code\":\"$c\",\"country\":\"$k\"}")
  if [ "$code" = "200" ]; then ok=$((ok+1)); else err=$((err+1)); fi
done
echo "Sent $N requests: $ok ok, $err errors"
