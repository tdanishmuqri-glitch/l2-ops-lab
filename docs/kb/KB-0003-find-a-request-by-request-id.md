# KB-0003 — Trace a single failed request using its Request ID

Every response carries an `X-Request-ID` header and every log line includes `request_id`. When a customer or L1 provides one, L2 can find exactly what happened.

```bash
docker compose logs app --no-log-prefix | grep "<request-id>"
```
Splunk: `index=apps service=authentiscan request_id="<request-id>"`
CloudWatch Logs Insights: `fields @timestamp, level, msg, status, error | filter request_id = "<request-id>"`

Ask L1 to always capture the request ID (shown in the app's error screen) — it cuts diagnosis from 30 minutes to 2.
