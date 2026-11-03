#!/usr/bin/env bash
# First thing an L2 engineer runs when a ticket lands: is everything up?
# Usage: ./scripts/healthcheck.sh [base_url]
set -uo pipefail
BASE="${1:-http://localhost:8080}"
PROM="${PROM_URL:-http://localhost:9090}"
fail=0

check() {  # name, command
  if eval "$2" >/dev/null 2>&1; then printf "  [OK]   %s\n" "$1"; else printf "  [FAIL] %s\n" "$1"; fail=1; fi
}

echo "== AuthentiScan health check $(date '+%F %T') =="
check "API /health returns 200"       "curl -sf --max-time 3 $BASE/health"
check "Genuine code verifies"         "curl -sf --max-time 5 -X POST $BASE/verify -H 'Content-Type: application/json' -d '{\"code\":\"SPX-1001\"}' | grep -q genuine"
check "Metrics endpoint exposed"      "curl -sf --max-time 3 $BASE/metrics | grep -q authentiscan_requests_total"
check "Prometheus is scraping app"    "curl -sf --max-time 3 '$PROM/api/v1/query?query=up%7Bjob%3D%22authentiscan%22%7D' | grep -q '\"1\"\\]'"

echo
echo "Version: $(curl -s --max-time 3 "$BASE/version" || echo unknown)"
firing=$(curl -s --max-time 3 "$PROM/api/v1/alerts" | python3 -c 'import sys,json; a=[x["labels"]["alertname"] for x in json.load(sys.stdin)["data"]["alerts"] if x["state"]=="firing"]; print(", ".join(a) or "none")' 2>/dev/null || echo "prometheus unreachable")
echo "Firing alerts: $firing"
exit $fail
