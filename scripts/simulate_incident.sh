#!/usr/bin/env bash
# Break the system on purpose so you can practise detection -> triage -> fix -> RCA.
# Usage: ./scripts/simulate_incident.sh <scenario>
#   db-outage    stop PostgreSQL                      -> RB-01
#   error-rate   30% of requests return 500           -> RB-02
#   slow-db      2s added to every DB call            -> RB-03
#   kafka-down   event publishing fails (degraded)    -> RB-04
#   bad-deploy   deploy a version with broken config  -> RB-05
#   recover      put everything back to normal
set -euo pipefail
case "${1:-}" in
  db-outage)  docker compose stop postgres ;;
  error-rate) FAULT_MODE=error_rate docker compose up -d app ;;
  slow-db)    FAULT_MODE=slow_db    docker compose up -d app ;;
  kafka-down) FAULT_MODE=kafka_down docker compose up -d app ;;
  bad-deploy)
    # wrong DB password shipped in a "new release"
    docker compose run -d --name authentiscan-bad -p 8081:8080 \
      -e DATABASE_URL=postgresql://ops:WRONG@postgres:5432/authentiscan -e APP_VERSION=1.2.0-bad app
    echo "Bad release running on :8081 - try ./scripts/healthcheck.sh http://localhost:8081" ;;
  recover)
    docker rm -f authentiscan-bad 2>/dev/null || true
    docker compose start postgres
    FAULT_MODE=none docker compose up -d app ;;
  *) sed -n '3,11p' "$0"; exit 1 ;;
esac
echo "Scenario '${1}' applied. Now generate traffic: ./scripts/load.sh"
