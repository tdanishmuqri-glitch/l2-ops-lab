import os, sys
os.environ["DATABASE_URL"] = "sqlite:///test_authentiscan.db"
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from app.main import app  # noqa: E402

client = app.test_client()

def test_health():
    r = client.get("/health")
    assert r.status_code == 200 and r.json["db"] == "up"

def test_genuine_code():
    r = client.post("/verify", json={"code": "spx-1001"})
    assert r.status_code == 200 and r.json["result"] == "genuine"

def test_revoked_code():
    assert client.post("/verify", json={"code": "SPX-2002"}).json["result"] == "revoked"

def test_unknown_code():
    assert client.post("/verify", json={"code": "FAKE-999"}).json["result"] == "unknown"

def test_missing_code_is_400():
    assert client.post("/verify", json={}).status_code == 400

def test_metrics_exposed():
    r = client.get("/metrics")
    assert b"authentiscan_scans_total" in r.data

def test_request_id_propagated():
    r = client.get("/health", headers={"X-Request-ID": "abc-123"})
    assert r.headers["X-Request-ID"] == "abc-123"
