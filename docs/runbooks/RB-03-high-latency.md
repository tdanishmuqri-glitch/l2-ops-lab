# RB-03 — High latency (P3, P2 if timeouts reach users)

**Alert:** `HighLatencyP95` (>1s for 3 min) · **Practise with:** `./scripts/simulate_incident.sh slow-db && ./scripts/load.sh 50`

## Diagnose
1. Grafana *latency* panel: p95 up but p50 normal → a subset of slow requests; both up → systemic.
2. Slow request IDs: `docker compose logs app --no-log-prefix --since 15m | python3 scripts/triage_logs.py`
3. Database side — run queries 5, 6, 7 in `sql/troubleshooting_queries.sql`:
   long-running/blocked queries, connection count vs max, table growth.
4. Resource pressure: `docker stats` / `kubectl top pods` — CPU throttling or memory near limit?

## Decision
| Finding | Action |
|---|---|
| Long-running query blocking others | Capture query + pid, escalate to L3/DBA; `pg_cancel_backend(pid)` only with approval |
| Connections near max | Restart app pods to release leaked connections (workaround); L3 ticket for connection pooling |
| CPU throttled | Scale replicas (standard change); raise limits via change request |
| Injected fault / config | Revert config |
