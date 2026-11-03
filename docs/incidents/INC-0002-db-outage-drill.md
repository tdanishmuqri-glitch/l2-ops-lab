# INC-0002 — Verification API failing: database unreachable

> Live drill run on 2026-11-03 using `./scripts/simulate_incident.sh db-outage`. All timestamps, counts and errors below are real output from the lab. Times in MYT (UTC+8); Prometheus shows UTC.

| Field | Value |
|---|---|
| Priority | **P1** — high impact (all `/verify` requests failing) · high urgency |
| Category | Application > Verification API > Database connectivity |
| CI affected | authentiscan (app), postgres |
| Detected by | Prometheus alert `DatabaseDown` (P1) + correlated `HighErrorRate` (P2), `HighLatencyP95` (P3) |
| Assigned | Digital Operations L2 — T. Danish |
| Status | Resolved |
| Runbook | RB-01 Service down / database unreachable |

## Pre-existing state (noted before investigation)
At 15:39:44 the health check passed 4/4, but **`HighErrorRate` was already firing** (since 15:37:15). This was recorded as a pre-existing alert so it would not be wrongly attributed to this incident. It was caused by errors during an earlier application restart and aged out of the 5-minute window.

## Work notes (chronological)

**15:40:00** — PostgreSQL container stopped (incident start).

**15:40:05** — `DatabaseDown` condition first true (`authentiscan_db_up == 0`); alert pending for 1m, then **FIRING (P1)**. `HighErrorRate` and `HighLatencyP95` also firing.

**15:44:06** — Acknowledged. Ran `healthcheck.sh`:
```
[FAIL] API /health returns 200
[FAIL] Genuine code verifies
[OK]   Metrics endpoint exposed
[OK]   Prometheus is scraping app
Firing alerts: HighErrorRate, HighLatencyP95, DatabaseDown
```
*Observation:* the app process is alive (metrics are being served, `AuthentiScanDown` NOT firing) but every functional check fails.
*Hypothesis:* dependency failure, not an application crash.

**15:44:30** — `docker compose ps`: app `Up (unhealthy)`, grafana/kafka/prometheus Up, **postgres not listed** — container not running.

**15:45:06** — Log triage, window 15:40:14 → 15:45:06:
```
Requests: 66  |  5xx: 65 (98.5%)
By status: {200: 1, 503: 65}
Top errors:
  59  could not translate host name "postgres" to address: Temporary failure in name resolution
   6  could not translate host name "postgres" to address: Name or service not known
Slow requests (>1s): 65   (each ~8,006 ms)
```
*Finding:* the app cannot resolve the hostname `postgres`. A stopped container is removed from Docker's internal DNS, so the failure appears as a **DNS error, not a "connection refused"**. Hypothesis confirmed: database down.
*Finding 2:* each failed request took **~8 seconds** before returning 503 — the time spent waiting for name resolution to give up. This explains the `HighLatencyP95` alert: it was a symptom of the same cause.

**15:45:40** — *Action:* started PostgreSQL (`simulate_incident.sh recover`). Container reported Healthy after 5.1s.

**15:45:46** — *Result:* `healthcheck.sh` 4/4 OK. Service restored.
`HighErrorRate` and `HighLatencyP95` still firing — expected, because both use a 5-minute rate window that still contains the failed requests. Monitored until cleared; no action needed.

## Alert correlation
| Alert | Severity | Role in incident |
|---|---|---|
| DatabaseDown | P1 | **Cause** — worked as the primary alert |
| HighErrorRate | P2 | Symptom (503s because DB unreachable) |
| HighLatencyP95 | P3 | Symptom (8s DNS wait per request) |
| AuthentiScanDown | — | Stayed green → proved the app itself was alive, narrowing the search |

One incident ticket, three linked alerts — not three tickets.

## Resolution summary
| | |
|---|---|
| Impact window | 15:40:00 – 15:45:46 (≈ 5 min 46 s) |
| Impact | 98.5% of `/verify` requests failed with 503; successful ones unaffected after recovery |
| Root cause | PostgreSQL container stopped; app could not resolve/reach the database |
| Fix | Restarted PostgreSQL |
| Detection time | ~1 min (alert `for: 1m`) |

## Follow-up actions (problem record)
| # | Action | Why |
|---|---|---|
| 1 | Fail fast: cap DB connection/DNS wait to ~2s | Users waited 8s just to get an error; a fast 503 is better UX and frees app threads |
| 2 | Add a "dependency down" banner/response so the consumer app shows "temporarily unavailable" instead of a generic failure | Reduces L1 call volume during DB incidents |
| 3 | Add `pg_up` (postgres-exporter) as a separate alert | Detect DB down even when no one is calling `/health` |
| 4 | Note in RB-01: "DNS error for `postgres` = container stopped / service missing", and "rate-based alerts lag ~5 min after recovery" | Faster diagnosis next time; avoids false alarm after fix |
