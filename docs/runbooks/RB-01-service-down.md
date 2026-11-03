# RB-01 — Service down / database unreachable (P1)

**Alerts:** `AuthentiScanDown`, `DatabaseDown` · **Practise with:** `./scripts/simulate_incident.sh db-outage`

## Symptoms
- `/health` returns 503 with `"db": "down"`, or the API does not answer at all
- `/verify` returns 503 `service unavailable`; scans/min in Grafana drops to zero

## Diagnose
```bash
./scripts/healthcheck.sh                       # which checks fail?
docker compose ps                              # is every container Up / healthy?
docker compose logs app --since 10m | python3 scripts/triage_logs.py
docker compose logs postgres --tail 50         # DB crashed? disk full? auth errors?
docker compose exec postgres pg_isready -U ops # DB accepting connections?
```
Kubernetes equivalent:
```bash
kubectl -n authentiscan get pods               # CrashLoopBackOff? 0/1 Ready?
kubectl -n authentiscan describe pod <pod>     # readiness probe failures, OOMKilled, image pull errors
kubectl -n authentiscan logs <pod> --previous  # logs from the crashed container
kubectl -n authentiscan get events --sort-by=.lastTimestamp | tail -20
```
AWS equivalent: RDS console → instance status, CloudWatch `DatabaseConnections`, `FreeStorageSpace`, `CPUUtilization`.

## Decision
| Finding | Action |
|---|---|
| Postgres container stopped | `docker compose start postgres`, then re-run healthcheck |
| App pod CrashLoopBackOff after a deploy | Roll back (RB-05) |
| DB disk full | Escalate to L3/DBA — **do not delete data**; P1 bridge |
| Credentials rejected | Check secret/config change history; roll back the config change |

## Verify recovery
`./scripts/healthcheck.sh` all OK · error rate back to 0 in Grafana · `AuthentiScanDown` alert resolved.

## Communicate
Update ticket every 30 min (P1). Resolution note: start time, end time, impact, cause, fix, follow-ups.
