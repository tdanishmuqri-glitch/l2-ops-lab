# RB-04 — Kafka publish failures (P3)

**Alert:** `KafkaPublishFailures` · **Practise with:** `./scripts/simulate_incident.sh kafka-down && ./scripts/load.sh 50`

**User impact:** none — scans still succeed (service degrades gracefully). **Business impact:** analytics / counterfeit-detection dashboards stop receiving events.

## Diagnose
```bash
docker compose ps kafka
docker compose exec kafka rpk cluster health
docker compose exec kafka rpk topic list
docker compose exec kafka rpk topic describe scan-events      # partitions, leaders
docker compose exec kafka rpk group list                      # consumer groups
docker compose exec kafka rpk group describe <group>          # LAG per partition
docker compose exec kafka rpk topic consume scan-events -n 5  # are messages arriving?
docker compose logs app --no-log-prefix --since 15m | grep "kafka publish failed"
```
(Apache Kafka CLI equivalents: `kafka-topics.sh --describe`, `kafka-consumer-groups.sh --describe --group <g>`.)

## Decision
| Finding | Action |
|---|---|
| Broker down | Restart broker; confirm `rpk cluster health` healthy |
| Topic missing / auto-create disabled | Create topic per standard config; log change |
| Consumer lag growing but producer OK | Not a producer issue — escalate to the analytics consumer owner |
| Events lost during window | Note the gap window in the ticket; L3 can replay from `scan_log` table |
