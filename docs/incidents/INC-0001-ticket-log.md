# INC-0001 — Scan verifications failing after release 1.2.0

> Ticket worked in the lab by reproducing `./scripts/simulate_incident.sh bad-deploy`. Written the way it would appear in ServiceNow / Jira Service Management.

| Field | Value |
|---|---|
| Priority | **P1** (high impact: all markets on new version · high urgency) |
| Category | Application > Verification API |
| CI affected | authentiscan (prod) |
| Reported by | L1 Service Desk — 3 customer calls in 10 min + `DatabaseDown` alert |
| Assigned | Digital Operations L2 — T. Danish |
| Status | Resolved → Closed |

## Work notes (chronological)

**10:02** — Acknowledged. Alert `DatabaseDown` firing; L1 reports "verification failed, please try again" on consumer app across MY and SG.

**10:04** — *Observation:* `healthcheck.sh` → `/health` 503, `"error": "password authentication failed for user ops"`. Grafana: error rate 100% since 09:58. *Running version* panel shows 1.2.0 deployed 09:57.
*Hypothesis:* release 1.2.0 shipped with a wrong DB credential.

**10:06** — Checked postgres logs: repeated `FATAL: password authentication failed`. DB itself healthy (`pg_isready` OK, previous version connects fine). Hypothesis confirmed — app-side config, not database.

**10:07** — *Action:* emergency change — rollback to 1.1.0 (RB-05). Bridge informed.

**10:09** — *Result:* `/health` 200, Postman smoke suite 7/7 pass, error rate back to 0%. Alert resolved 10:10.

**10:15** — Data check: `scan_log` per-minute query shows no rows 09:58–10:09 → ~11 min of failed scans. Kafka shows the same gap — analytics team informed.

**10:20** — Escalated to L3 (Release Engineering) with: release diff, error message, timestamps, rollback confirmation. Problem record PRB-0001 opened for RCA.

**10:25** — Customer update via L1: service restored, users can re-scan.

## Resolution summary
Release 1.2.0 contained an incorrect database credential. Rolled back to 1.1.0. Impact window 09:58–10:09 (11 min), all markets. RCA in `RCA-0001.md`.
