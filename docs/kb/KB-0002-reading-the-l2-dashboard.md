# KB-0002 — How to read the "AuthentiScan – L2 Operations" Grafana dashboard

| Panel | Healthy | Investigate when | Go to |
|---|---|---|---|
| Service up | 1 | 0 | RB-01 |
| DB up | 1 | 0 | RB-01 |
| Error rate (5m) | < 1% | > 5% | RB-02 |
| Kafka failures (1h) | 0 | > 0 | RB-04 |
| Requests/sec by status | steady 200s | 5xx line appears, or total drops to 0 | RB-02 / RB-01 |
| /verify latency | p95 < 300 ms | p95 > 1 s | RB-03 |
| Scan results/min | mostly genuine | sudden jump in `unknown` in one country | Possible counterfeit wave or bad data load — escalate to business owner, not an outage |
| Running version | one version | two versions for > 10 min | Stuck rollout — RB-05 |
