"""
AuthentiScan - a small product-authentication API used as the "production system"
for this L2 support lab.

A consumer scans a code printed on a product; the API checks it against the
database, records the scan, and publishes a scan event to Kafka for downstream
analytics. It exposes /health (for probes) and /metrics (for Prometheus).

FAULT_MODE lets you reproduce realistic incidents on purpose:
  none        - normal behaviour
  slow_db     - every DB call sleeps 2s (latency incident)
  error_rate  - ~30% of /verify calls return HTTP 500 (error-rate incident)
  kafka_down  - event publishing fails; API still answers (degraded mode)
"""
import json
import logging
import os
import random
import sqlite3
import time
import uuid

from flask import Flask, g, jsonify, request
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Gauge, Histogram, generate_latest

APP_VERSION = os.getenv("APP_VERSION", "1.0.0")
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///authentiscan.db")
KAFKA_BOOTSTRAP = os.getenv("KAFKA_BOOTSTRAP", "")
KAFKA_TOPIC = os.getenv("KAFKA_TOPIC", "scan-events")
FAULT_MODE = os.getenv("FAULT_MODE", "none")

# ---------- structured JSON logging (what you'd search in Splunk / CloudWatch) ----------
class JsonFormatter(logging.Formatter):
    def format(self, record):
        payload = {
            "ts": self.formatTime(record, "%Y-%m-%dT%H:%M:%S"),
            "level": record.levelname,
            "service": "authentiscan",
            "version": APP_VERSION,
            "msg": record.getMessage(),
        }
        payload.update(getattr(record, "extra_fields", {}))
        return json.dumps(payload)


handler = logging.StreamHandler()
handler.setFormatter(JsonFormatter())
log = logging.getLogger("authentiscan")
log.addHandler(handler)
log.setLevel(logging.INFO)


def log_event(level, msg, **fields):
    log.log(level, msg, extra={"extra_fields": fields})


# ---------- metrics ----------
REQUESTS = Counter("authentiscan_requests_total", "HTTP requests", ["endpoint", "status"])
LATENCY = Histogram("authentiscan_request_seconds", "Request latency", ["endpoint"],
                    buckets=(0.05, 0.1, 0.25, 0.5, 1, 2, 5))
SCANS = Counter("authentiscan_scans_total", "Scan results", ["result"])
KAFKA_FAIL = Counter("authentiscan_kafka_publish_failures_total", "Failed Kafka publishes")
DB_UP = Gauge("authentiscan_db_up", "1 if last DB check succeeded")
INFO = Gauge("authentiscan_build_info", "Build info", ["version"])
INFO.labels(version=APP_VERSION).set(1)


# ---------- database (PostgreSQL in Docker/K8s, SQLite for local tests) ----------
def get_db():
    if "db" not in g:
        if DATABASE_URL.startswith("postgres"):
            import psycopg2
            g.db = psycopg2.connect(DATABASE_URL, connect_timeout=3)
            g.db_kind = "pg"
        else:
            g.db = sqlite3.connect(DATABASE_URL.replace("sqlite:///", ""))
            g.db_kind = "sqlite"
    return g.db


def q(sql):
    """Convert %s placeholders to ? for SQLite."""
    return sql if g.get("db_kind") == "pg" else sql.replace("%s", "?")


def db_query(sql, params=(), fetch=True):
    if FAULT_MODE == "slow_db":
        time.sleep(2)
    conn = get_db()
    cur = conn.cursor()
    cur.execute(q(sql), params)
    rows = cur.fetchall() if fetch else None
    conn.commit()
    return rows


def init_sqlite():
    """Local dev only - PostgreSQL is initialised by sql/schema.sql."""
    if DATABASE_URL.startswith("postgres"):
        return
    conn = sqlite3.connect(DATABASE_URL.replace("sqlite:///", ""))
    with open(os.path.join(os.path.dirname(__file__), "..", "sql", "schema_sqlite.sql")) as f:
        conn.executescript(f.read())
    conn.close()


# ---------- kafka ----------
_producer = None


def publish_event(event):
    global _producer
    if not KAFKA_BOOTSTRAP:
        return "skipped"
    try:
        if FAULT_MODE == "kafka_down":
            raise ConnectionError("simulated broker unavailable")
        if _producer is None:
            from kafka import KafkaProducer
            _producer = KafkaProducer(
                bootstrap_servers=KAFKA_BOOTSTRAP,
                value_serializer=lambda v: json.dumps(v).encode(),
                request_timeout_ms=3000,
                max_block_ms=3000,
            )
        _producer.send(KAFKA_TOPIC, event)
        return "sent"
    except Exception as exc:  # degrade gracefully: never fail the user's scan
        KAFKA_FAIL.inc()
        log_event(logging.ERROR, "kafka publish failed", error=str(exc), topic=KAFKA_TOPIC)
        return "failed"


# ---------- app ----------
app = Flask(__name__)


@app.before_request
def start_timer():
    g.start = time.time()
    g.request_id = request.headers.get("X-Request-ID", str(uuid.uuid4()))


@app.after_request
def record(resp):
    endpoint = request.path
    if endpoint != "/metrics":
        REQUESTS.labels(endpoint=endpoint, status=resp.status_code).inc()
        LATENCY.labels(endpoint=endpoint).observe(time.time() - g.start)
        log_event(logging.INFO, "request", path=endpoint, status=resp.status_code,
                  ms=round((time.time() - g.start) * 1000), request_id=g.request_id)
    resp.headers["X-Request-ID"] = g.request_id
    return resp


@app.teardown_appcontext
def close_db(_exc):
    db = g.pop("db", None)
    if db is not None:
        db.close()


@app.get("/health")
def health():
    try:
        db_query("SELECT 1")
        DB_UP.set(1)
        return jsonify(status="ok", version=APP_VERSION, db="up", fault_mode=FAULT_MODE)
    except Exception as exc:
        DB_UP.set(0)
        log_event(logging.ERROR, "health check failed", error=str(exc))
        return jsonify(status="degraded", version=APP_VERSION, db="down", error=str(exc)), 503


@app.post("/verify")
def verify():
    body = request.get_json(silent=True) or {}
    code = str(body.get("code", "")).strip().upper()
    if not code:
        return jsonify(error="field 'code' is required"), 400

    if FAULT_MODE == "error_rate" and random.random() < 0.3:
        log_event(logging.ERROR, "unhandled error in verify", code=code, request_id=g.request_id)
        return jsonify(error="internal error", request_id=g.request_id), 500

    try:
        rows = db_query("SELECT product_name, brand, status FROM product_codes WHERE code = %s", (code,))
    except Exception as exc:
        log_event(logging.ERROR, "database error", error=str(exc), request_id=g.request_id)
        return jsonify(error="service unavailable", request_id=g.request_id), 503

    if not rows:
        result, payload = "unknown", {"code": code, "result": "unknown",
                                      "message": "Code not found - possible counterfeit"}
    else:
        name, brand, status = rows[0]
        result = "genuine" if status == "active" else status  # e.g. 'revoked'
        payload = {"code": code, "result": result, "product": name, "brand": brand}

    country = body.get("country", "MY")
    db_query("INSERT INTO scan_log (code, result, country) VALUES (%s, %s, %s)",
             (code, result, country), fetch=False)
    SCANS.labels(result=result).inc()
    payload["event"] = publish_event({"code": code, "result": result, "country": country,
                                      "ts": time.time(), "request_id": g.request_id})
    return jsonify(payload)


@app.get("/version")
def version():
    return jsonify(version=APP_VERSION)


@app.get("/metrics")
def metrics():
    return generate_latest(), 200, {"Content-Type": CONTENT_TYPE_LATEST}


init_sqlite()

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", "8080")))
