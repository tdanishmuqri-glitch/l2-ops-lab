-- PostgreSQL schema + seed data (runs automatically on first `docker compose up`)
CREATE TABLE IF NOT EXISTS product_codes (
    code          VARCHAR(32) PRIMARY KEY,
    product_name  VARCHAR(120) NOT NULL,
    brand         VARCHAR(80)  NOT NULL,
    status        VARCHAR(16)  NOT NULL DEFAULT 'active',   -- active | revoked
    created_at    TIMESTAMP    NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS scan_log (
    id         BIGSERIAL PRIMARY KEY,
    code       VARCHAR(32) NOT NULL,
    result     VARCHAR(16) NOT NULL,                        -- genuine | revoked | unknown
    country    VARCHAR(2)  NOT NULL DEFAULT 'MY',
    scanned_at TIMESTAMP   NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_scan_log_code ON scan_log(code);
CREATE INDEX IF NOT EXISTS idx_scan_log_time ON scan_log(scanned_at);

INSERT INTO product_codes (code, product_name, brand, status) VALUES
 ('SPX-1001', 'Premium Whisky 700ml', 'Highland Co', 'active'),
 ('SPX-1002', 'Premium Whisky 700ml', 'Highland Co', 'active'),
 ('SPX-2001', 'Cigarettes 20s',       'Tobacco Ltd', 'active'),
 ('SPX-2002', 'Cigarettes 20s',       'Tobacco Ltd', 'revoked'),
 ('SPX-3001', 'Pharma Tablet 10mg',   'MediCare',    'active')
ON CONFLICT DO NOTHING;
