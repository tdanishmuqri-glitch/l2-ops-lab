# L2 Cloud Ops Lab — running, breaking and fixing a cloud service

**Author:** Tengku Danish Muqri · [LinkedIn](https://www.linkedin.com/in/tengku-danish-8225a9332/) · [Portfolio](https://tdanishmuqriportfolio.netlify.app/)

A hands-on lab where I operate a small product-authentication API ("AuthentiScan") the way a Digital Operations L2 team would: deploy it, monitor it, break it on purpose, troubleshoot from logs/metrics/SQL, roll back, write the ticket, the RCA and the knowledge-base article.

The app is deliberately simple. **The point is the operations around it.**

```
 Consumer scan ──► AuthentiScan API (Flask, Docker) ──► PostgreSQL   (product codes, scan log)
                         │      │
                         │      └──► Kafka topic "scan-events" ──► analytics
                         └── /metrics ──► Prometheus ──► alert rules ──► Grafana dashboard
                                              │
                                              └──► Runbooks (docs/runbooks) ──► Ticket ──► RCA ──► KB
 Deploy path:  git tag ──► GitHub Actions (test, build, push) ──► k8s manifest bump ──► ArgoCD sync
```

## Mapping to the role

| Responsibility | Where it's shown |
|---|---|
| Operate solution & cloud infra, ensure continuity | `docker-compose.yml`, `k8s/` (probes, rolling update, resource limits) |
| Configuration changes & deployment of new versions | `scripts/deploy.sh` (smoke test + auto-rollback), `.github/workflows/ci.yml`, `argocd/application.yaml` |
| Respond to incidents escalated by L1, update tickets | `docs/incidents/INC-0001-ticket-log.md` |
| Troubleshoot, identify bugs | `scripts/triage_logs.py`, `sql/troubleshooting_queries.sql`, runbooks |
| Root Cause Analysis, corrective actions | `docs/incidents/RCA-0001.md` (5 Whys + action table) |
| Escalate to L3 appropriately | `docs/process/incident-management-process.md` §4 |
| Maintain Knowledge Base | `docs/kb/` |
| Process documentation (ITIL) | `docs/process/`, `docs/runbooks/` |

| Tool in the JD | Used here |
|---|---|
| Kafka | Redpanda (Kafka-API compatible) — producer, topic inspection, consumer lag (RB-04) |
| SQL (PostgreSQL) | Schema, 8 troubleshooting queries incl. `pg_stat_activity` |
| Grafana / Prometheus | Provisioned dashboard + 5 alert rules each linked to a runbook |
| Splunk / AWS CloudWatch | Structured JSON logs; equivalent Splunk SPL and Logs Insights queries in `triage_logs.py` and KB-0003 |
| Docker / Kubernetes | Dockerfile (non-root, healthcheck), Deployment/Service/ConfigMap/Secret |
| AWS | Mapped in runbooks (RDS, CloudWatch, Secrets Manager); manifests are EKS-ready |
| Bash / Python / Postman | `scripts/*.sh`, `triage_logs.py`, Postman smoke-test collection |
| CI/CD, ArgoCD | GitHub Actions pipeline + GitOps ArgoCD Application |

## Run it

Requires Docker Desktop.

```bash
docker compose up -d --build        # API :8080, Grafana :3000, Prometheus :9090
./scripts/healthcheck.sh            # all [OK]
./scripts/load.sh 300               # generate traffic
```
Grafana → http://localhost:3000 → *L2 Ops / AuthentiScan – L2 Operations*.

## Incident drills

| Drill | Command | Runbook |
|---|---|---|
| Database outage | `./scripts/simulate_incident.sh db-outage` | RB-01 |
| Error spike | `./scripts/simulate_incident.sh error-rate` | RB-02 |
| Latency | `./scripts/simulate_incident.sh slow-db` | RB-03 |
| Kafka degraded | `./scripts/simulate_incident.sh kafka-down` | RB-04 |
| Bad release | `./scripts/simulate_incident.sh bad-deploy` | RB-05 |
| Reset | `./scripts/simulate_incident.sh recover` | — |

For each drill: generate load → watch the alert fire in Prometheus (`/alerts`) → follow the runbook → record notes → recover.

## Tests
```bash
pip install -r app/requirements.txt pytest && pytest -q tests
newman run postman/authentiscan.postman_collection.json -e postman/local.postman_environment.json
```

## Kubernetes (optional, with kind or minikube)
```bash
docker build -t ghcr.io/tdanishmuqri-glitch/authentiscan:1.0.0 .
kind load docker-image ghcr.io/tdanishmuqri-glitch/authentiscan:1.0.0
kubectl apply -k k8s/
kubectl -n authentiscan rollout status deploy/authentiscan
```
(Postgres/Kafka for the cluster are not included — run them via Helm or point the Secret at the Compose services.)

## What I learned
- Graceful degradation matters: when Kafka is down, scans still succeed and the gap is recoverable from `scan_log` — that turns a P1 into a P3.
- A readiness probe tied to real dependencies is the cheapest outage prevention there is (see RCA-0001).
- Good escalations are evidence, not opinions: request IDs, timestamps, what was ruled out.
