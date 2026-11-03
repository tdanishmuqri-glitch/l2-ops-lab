# RB-02 — High error rate (P2)

**Alert:** `HighErrorRate` (>5% 5xx for 2 min) · **Practise with:** `./scripts/simulate_incident.sh error-rate && ./scripts/load.sh`

## Diagnose
1. Grafana → *Requests/sec by status*: when did 5xx start? Does it line up with a deploy (*Running version* panel)?
2. Which errors?
   ```bash
   docker compose logs app --no-log-prefix --since 15m | python3 scripts/triage_logs.py
   ```
   Splunk: `index=apps service=authentiscan level=ERROR earliest=-15m | stats count by msg, error`
3. Is it all requests or a subset (one code, one country)? Pull request IDs and look them up.
4. Check config: `docker compose exec app env | grep FAULT_MODE` (in K8s: `kubectl get cm authentiscan-config -o yaml`).

## Decision
| Finding | Action |
|---|---|
| Started with a new version | Roll back (RB-05), then escalate defect to L3 with request IDs |
| Bad config value | Revert config, restart, log change |
| Downstream dependency errors (DB/Kafka) | Follow RB-01 / RB-04 |
| Unknown code defect, no recent change | Escalate to L3 with evidence; keep monitoring |
