# Incident & Request Management Process (ITIL 4 aligned)

How an issue moves through Digital Operations, and what L2 owns.

## 1. Support tiers

| Tier | Owns | Typical actions | Hands off when |
|---|---|---|---|
| **L1** Service Desk | First contact, logging, known fixes | Categorise ticket, check status page, apply KB fix, password/access requests | No KB fix exists, or fix needs system access |
| **L2** Cloud Support (this role) | Technical troubleshooting on the running platform | Logs, metrics, DB queries, config changes, restarts, rollbacks, deployments, RCA, KB updates | Root cause is a code defect, needs a schema change, or vendor/infra-provider involvement |
| **L3** Engineering / Vendor | Code and architecture | Bug fixes, hotfix releases, design changes | — |

## 2. Priority matrix (Impact x Urgency)

| | **High urgency** | **Medium** | **Low** |
|---|---|---|---|
| **High impact** (all users / a whole country / revenue or compliance) | **P1** | P2 | P3 |
| **Medium impact** (one customer / one feature) | P2 | P3 | P4 |
| **Low impact** (single user, workaround exists) | P3 | P4 | P4 |

| Priority | Example | Response | Resolve / workaround target | Update cadence |
|---|---|---|---|---|
| P1 | API down, verifications failing for all markets | 15 min | 4 h | every 30 min + bridge call |
| P2 | >5% errors, one market failing | 30 min | 8 h | every 1 h |
| P3 | Slow responses, analytics events delayed | 4 h | 3 business days | daily |
| P4 | Cosmetic, how-to question | 1 business day | 10 business days | on change |

## 3. Incident lifecycle

```
Detect ──► Log & Categorise ──► Prioritise ──► Investigate & Diagnose ──► Resolve / Workaround ──► Close
(alert,     (ticket tool,          (matrix          (L2: logs, metrics,         (fix, restart,             (user confirms,
 L1 call)    CI affected)           above)           SQL, recent changes)        rollback, escalate L3)      KB updated)
                                                                                         │
                                                              P1/P2 or recurring ──► Problem record ──► RCA ──► Corrective actions
```

### L2 first-15-minutes checklist
1. **Acknowledge** the ticket and set status *In Progress* so L1 / customer know it's owned.
2. **Scope it**: one user, one market, or everyone? (`scripts/healthcheck.sh`, Grafana dashboard)
3. **What changed?** Last deployment, config change, certificate, infra event (`deploy-history.log`, ArgoCD history, AWS Health).
4. **Evidence**: error messages and request IDs from logs (`scripts/triage_logs.py`, Splunk / CloudWatch).
5. **Decide**: fix within L2 authority (restart, rollback, config) or escalate with evidence.
6. **Update the ticket** with findings in the format: *Observation → Hypothesis → Action → Result*.

## 4. Escalation to L3 — what a good escalation contains
- Ticket ID, priority, start time, impact (users/markets/transactions)
- Exact symptoms + 2–3 sample request IDs and timestamps
- What L2 already checked and ruled out
- Current workaround (if any) and whether it is holding
- Specific ask ("need a hotfix for null-pointer in /verify when country is missing")

## 5. Change management (deployments and config changes)
- **Standard change** (pre-approved, low risk, e.g. scaling replicas): do it, log it.
- **Normal change** (new version deployment): change request with plan, smoke test, rollback plan, time window; approved by CAB / change manager.
- **Emergency change** (rollback during P1): do it, get retrospective approval.

Every change in this lab follows: record current version → deploy → smoke test (Postman/healthcheck) → rollback automatically on failure (`scripts/deploy.sh`).

## 6. Knowledge Base
After every resolved ticket ask: *would a KB article have let L1 fix this, or let L2 fix it faster?* If yes, write or update one (`docs/kb/`). Track KB articles that L1 actually uses — that's the metric for shift-left.
