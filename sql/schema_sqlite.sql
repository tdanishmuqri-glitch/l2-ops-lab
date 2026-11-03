-- SQLite equivalent, used only for local unit tests
CREATE TABLE IF NOT EXISTS product_codes (
    code TEXT PRIMARY KEY, product_name TEXT NOT NULL, brand TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'active', created_at TEXT DEFAULT CURRENT_TIMESTAMP);
CREATE TABLE IF NOT EXISTS scan_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT, code TEXT NOT NULL, result TEXT NOT NULL,
    country TEXT NOT NULL DEFAULT 'MY', scanned_at TEXT DEFAULT CURRENT_TIMESTAMP);
INSERT OR IGNORE INTO product_codes (code, product_name, brand, status) VALUES
 ('SPX-1001','Premium Whisky 700ml','Highland Co','active'),
 ('SPX-1002','Premium Whisky 700ml','Highland Co','active'),
 ('SPX-2001','Cigarettes 20s','Tobacco Ltd','active'),
 ('SPX-2002','Cigarettes 20s','Tobacco Ltd','revoked'),
 ('SPX-3001','Pharma Tablet 10mg','MediCare','active');
