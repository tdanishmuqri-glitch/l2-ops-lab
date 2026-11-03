#!/usr/bin/env python3
"""
Summarise the app's JSON logs the way you would with a Splunk / CloudWatch Logs Insights query.

  docker compose logs app --no-log-prefix --since 15m | python3 scripts/triage_logs.py

Equivalent Splunk query:
  index=apps service=authentiscan earliest=-15m
  | stats count by level, status | sort -count
Equivalent CloudWatch Logs Insights query:
  fields @timestamp, level, status, msg
  | filter service = "authentiscan" | stats count(*) by level, status
"""
import collections
import json
import sys

levels, statuses, errors, slow = collections.Counter(), collections.Counter(), collections.Counter(), []
first = last = None
for line in sys.stdin:
    try:
        e = json.loads(line)
    except ValueError:
        continue
    first = first or e.get("ts")
    last = e.get("ts")
    levels[e.get("level")] += 1
    if "status" in e:
        statuses[e["status"]] += 1
    if e.get("level") == "ERROR":
        errors[e.get("error") or e.get("msg")] += 1
    if e.get("ms", 0) > 1000:
        slow.append((e["ms"], e.get("path"), e.get("request_id")))

total = sum(statuses.values()) or 1
five_xx = sum(v for k, v in statuses.items() if 500 <= int(k) < 600)
print(f"Window: {first} -> {last}")
print(f"Requests: {total}  |  5xx: {five_xx} ({five_xx / total:.1%})")
print("By level:", dict(levels))
print("By status:", dict(sorted(statuses.items())))
print("\nTop errors:")
for msg, n in errors.most_common(5):
    print(f"  {n:>5}  {msg}")
print(f"\nSlow requests (>1s): {len(slow)}")
for ms, path, rid in sorted(slow, reverse=True)[:5]:
    print(f"  {ms:>6} ms  {path}  request_id={rid}")
