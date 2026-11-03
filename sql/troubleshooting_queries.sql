-- L2 troubleshooting queries (PostgreSQL). Run with:
--   docker compose exec postgres psql -U ops -d authentiscan -f /sql/troubleshooting_queries.sql

-- 1. Is a specific code in the system, and what is its status?   (ticket: "customer says genuine product shows as fake")
SELECT code, product_name, brand, status, created_at FROM product_codes WHERE code = 'SPX-2002';

-- 2. Scan history for that code - when did the result change?
SELECT scanned_at, result, country FROM scan_log WHERE code = 'SPX-2002' ORDER BY scanned_at DESC LIMIT 20;

-- 3. Spike in 'unknown' results in the last hour by country  (counterfeit wave, or bad data load?)
SELECT country, result, COUNT(*) AS scans
FROM scan_log
WHERE scanned_at > NOW() - INTERVAL '1 hour'
GROUP BY country, result
ORDER BY scans DESC;

-- 4. Scans per minute (spot an outage window: a gap in minutes = nothing got through)
SELECT date_trunc('minute', scanned_at) AS minute, COUNT(*) AS scans
FROM scan_log
WHERE scanned_at > NOW() - INTERVAL '30 minutes'
GROUP BY 1 ORDER BY 1;

-- 5. Long-running / blocked queries (DB latency incident)
SELECT pid, state, wait_event_type, now() - query_start AS running_for, LEFT(query, 80) AS query
FROM pg_stat_activity
WHERE state <> 'idle' AND query_start < NOW() - INTERVAL '5 seconds'
ORDER BY running_for DESC;

-- 6. Connection count vs max (connection exhaustion)
SELECT COUNT(*) AS connections, current_setting('max_connections') AS max_allowed FROM pg_stat_activity;

-- 7. Table sizes (disk-full / growth issues)
SELECT relname AS table, pg_size_pretty(pg_total_relation_size(relid)) AS size
FROM pg_catalog.pg_statio_user_tables ORDER BY pg_total_relation_size(relid) DESC;

-- 8. Request fulfilment: revoke a code (ALWAYS inside a transaction, verify before COMMIT)
-- BEGIN;
-- UPDATE product_codes SET status = 'revoked' WHERE code = 'SPX-1002';
-- SELECT code, status FROM product_codes WHERE code = 'SPX-1002';
-- COMMIT;   -- or ROLLBACK;
