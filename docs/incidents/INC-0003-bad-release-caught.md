# INC-0003 — Release 1.2.0 rejected at pre-traffic smoke test (wrong DB credential)

> Live drill run on 2026-11-03 using `./scripts/simulate_incident.sh bad-deploy`. All output below is real. Times in MYT (UTC+8); logs show UTC.
> Contrast with INC-0001, where the same defect reached production and caused an 11-minute P1 outage.

| Field | Value |
|---|---|
| Type | Change / release validation failure (no customer impact) |
| Priority | P3 — failed change, production unaffected |
| Change | Deploy AuthentiScan 1.2.0 (current production: 1.0.0) |
| CI affected | authentiscan release candidate (port 8081) |
| Assigned | Digital Operations L2 — T. Danish |
| Status | Release rejected → returned to L3 Release Engineering |
| Runbook | RB-05 Failed deployment / rollback |

## Work notes (chronological)

**15:50:40** — Release candidate 1.2.0 started alongside production (1.0.0 stays live on :8080, candidate on :8081, receiving no customer traffic).

**15:50:46** — Pre-traffic smoke test against the candidate (`healthcheck.sh http://localhost:8081`):
```
[FAIL] API /health returns 200
[FAIL] Genuine code verifies
[OK]   Metrics endpoint exposed
Version: {"version":"1.2.0-bad"}
Firing alerts: none
```
*Observation:* candidate process is up (serves metrics, reports its version) but cannot serve verifications. No production alerts — Prometheus only monitors the live service, which is untouched.
**Decision: do not switch traffic.** Investigate.

**15:51** — Health endpoint detail (`curl /health` on :8081):
```
"db":"down",
"error":"connection to server at "postgres" (172.18.0.4), port 5432 failed:
         FATAL: password authentication failed for user "ops""
```

**15:52** — Candidate logs (`docker logs authentiscan-bad`): same error on every health probe, every 15 s since start, each failing in **5–14 ms**.

**Diagnosis — layer by layer**
| Layer | Evidence | Result |
|---|---|---|
| DNS | `postgres` resolved to 172.18.0.4 | ✅ OK |
| Network | TCP connection to port 5432 established | ✅ OK |
| Database | Server responded with an auth decision | ✅ Up and healthy |
| Authentication | `password authentication failed for user "ops"` | ❌ **Fault** |
*Conclusion:* infrastructure is healthy; the 1.2.0 release ships an incorrect database credential. This is a **release configuration defect**, not a database incident → owner is Release Engineering (L3), not the DBA.

**15:53** — Version comparison: production `1.0.0` (working), candidate `1.2.0-bad` (failing). Only the candidate's config differs.

**15:53:25** — *Action:* release rejected; candidate container removed (`simulate_incident.sh recover`).

**15:53:31** — *Result:* production health check 4/4 OK, version 1.0.0, no firing alerts. Production was never affected.

## Resolution summary
| | |
|---|---|
| Customer impact | **None** — defect caught before traffic switch |
| Root cause | Release 1.2.0 contains a wrong DB password in its configuration |
| Detection | Pre-traffic smoke test, ~6 s after the candidate started |
| Action | Release rejected; production remains on 1.0.0 |

## Escalation to L3 (Release Engineering)
> **Release 1.2.0 rejected at smoke test — wrong DB credential.**
> Candidate fails DB auth: `FATAL: password authentication failed for user "ops"`. DNS and network to postgres are OK (resolved 172.18.0.4, port 5432 reachable); production 1.0.0 connects fine with the current secret, so the DB and secret store are healthy. Please check how the DB credential is supplied in the 1.2.0 build (hard-coded / overridden env var?). Production unaffected, still on 1.0.0. Logs and timestamps in this ticket.

## Lessons
1. **Smoke-test before switching traffic.** Same defect as INC-0001 — there it caused an 11-minute P1, here zero impact.
2. **Read the error for the layer that failed.** "Could not translate host name" (INC-0002) = infrastructure; "password authentication failed" = configuration. Different owner, different fix.
3. **"No alerts" ≠ "release is fine."** Monitoring watches production; a new release must be validated explicitly.
4. **Fast failure is a clue.** 5–14 ms failures mean the DB answered and said no; ~8 s failures (INC-0002) mean nothing answered.

## Follow-up actions
| # | Action | Owner |
|---|---|---|
| 1 | Release pipeline must pull DB credentials from the secret store only; block builds that set `DATABASE_URL` directly | L3 |
| 2 | Make the smoke test a mandatory gate in `deploy.sh` / CI before traffic switch (already in `scripts/deploy.sh`) | L2 |
| 3 | Add "auth failed vs DNS failed" decision table to RB-01 and RB-05 | L2 |
