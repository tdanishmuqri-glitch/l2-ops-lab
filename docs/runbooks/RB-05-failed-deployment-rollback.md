# RB-05 — Failed deployment / rollback

**Practise with:** `./scripts/simulate_incident.sh bad-deploy` then `./scripts/healthcheck.sh http://localhost:8081`

## Before any deployment (change checklist)
- [ ] Change request approved, window agreed, L1 informed
- [ ] Current version recorded (`curl localhost:8080/version`)
- [ ] Rollback plan written (previous image tag)
- [ ] Smoke test ready (Postman collection / healthcheck)

## Deploy
- Lab: `./scripts/deploy.sh 1.1.0` (auto-rolls back on smoke-test failure)
- GitOps: push tag `v1.1.0` → CI builds image and bumps `k8s/deployment.yaml` → ArgoCD syncs.
- Watch: `kubectl -n authentiscan rollout status deploy/authentiscan`

## Rollback options
| Platform | Command |
|---|---|
| Docker Compose | `APP_VERSION=<previous> docker compose up -d --build app` |
| Kubernetes | `kubectl -n authentiscan rollout undo deploy/authentiscan` |
| ArgoCD | `argocd app history authentiscan` → `argocd app rollback authentiscan <id>` (or `git revert` the deploy commit — preferred, keeps git as source of truth) |

## After
Run Postman smoke tests: `newman run postman/authentiscan.postman_collection.json -e postman/local.postman_environment.json`. Update the change record with the outcome; open a problem ticket for L3 if the release was faulty.
