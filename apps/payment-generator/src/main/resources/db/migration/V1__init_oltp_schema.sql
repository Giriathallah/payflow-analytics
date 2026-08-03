-- =============================================================================
-- Flyway Migration V1: Initial OLTP Schema for Payflow Analytics
-- =============================================================================

-- Enable pgcrypto extension for UUID generation if needed
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- -----------------------------------------------------------------------------
-- 1. Table: merchants
-- -----------------------------------------------------------------------------
CREATE TABLE merchants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    external_id VARCHAR(100) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    category VARCHAR(50) NOT NULL CHECK (category IN ('SMALL', 'MEDIUM', 'ENTERPRISE')),
    city VARCHAR(100) NOT NULL,
    fee_rate NUMERIC(5, 4) NOT NULL DEFAULT 0.0150, -- 1.50% default fee
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- -----------------------------------------------------------------------------
-- 2. Table: payment_methods
-- -----------------------------------------------------------------------------
CREATE TABLE payment_methods (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    provider VARCHAR(100) NOT NULL,
    type VARCHAR(50) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- -----------------------------------------------------------------------------
-- 3. Table: payments
-- -----------------------------------------------------------------------------
CREATE TABLE payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_id UUID NOT NULL REFERENCES merchants(id) ON DELETE RESTRICT,
    payment_method_id UUID NOT NULL REFERENCES payment_methods(id) ON DELETE RESTRICT,
    external_reference VARCHAR(100) NOT NULL UNIQUE,
    amount NUMERIC(15, 2) NOT NULL CHECK (amount > 0),
    fee_amount NUMERIC(15, 2) NOT NULL DEFAULT 0.00 CHECK (fee_amount >= 0),
    net_amount NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    currency VARCHAR(3) NOT NULL DEFAULT 'IDR',
    status VARCHAR(50) NOT NULL CHECK (status IN ('INITIATED', 'AUTHORIZED', 'CAPTURED', 'SETTLED', 'FAILED', 'EXPIRED', 'REFUNDED', 'CHARGEBACK')),
    failure_reason VARCHAR(255),
    version INT NOT NULL DEFAULT 1 CHECK (version >= 1),
    initiated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    authorized_at TIMESTAMPTZ,
    captured_at TIMESTAMPTZ,
    settled_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- -----------------------------------------------------------------------------
-- 4. Table: payment_status_history (Append-Only)
-- -----------------------------------------------------------------------------
CREATE TABLE payment_status_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_id UUID NOT NULL REFERENCES payments(id) ON DELETE CASCADE,
    from_status VARCHAR(50),
    to_status VARCHAR(50) NOT NULL,
    reason VARCHAR(255),
    payment_version INT NOT NULL,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- -----------------------------------------------------------------------------
-- 5. Table: refunds
-- -----------------------------------------------------------------------------
CREATE TABLE refunds (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_id UUID NOT NULL REFERENCES payments(id) ON DELETE RESTRICT,
    refund_reference VARCHAR(100) NOT NULL UNIQUE,
    amount NUMERIC(15, 2) NOT NULL CHECK (amount > 0),
    status VARCHAR(50) NOT NULL CHECK (status IN ('REQUESTED', 'PROCESSING', 'COMPLETED', 'FAILED')),
    reason VARCHAR(255),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- -----------------------------------------------------------------------------
-- 6. Table: settlement_batches
-- -----------------------------------------------------------------------------
CREATE TABLE settlement_batches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_id UUID NOT NULL REFERENCES merchants(id) ON DELETE RESTRICT,
    settlement_reference VARCHAR(100) NOT NULL UNIQUE,
    settlement_date DATE NOT NULL,
    gross_amount NUMERIC(15, 2) NOT NULL DEFAULT 0.00 CHECK (gross_amount >= 0),
    fee_amount NUMERIC(15, 2) NOT NULL DEFAULT 0.00 CHECK (fee_amount >= 0),
    refund_amount NUMERIC(15, 2) NOT NULL DEFAULT 0.00 CHECK (refund_amount >= 0),
    expected_net_amount NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    actual_net_amount NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    status VARCHAR(50) NOT NULL CHECK (status IN ('PENDING', 'PROCESSING', 'COMPLETED', 'MISMATCH')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- -----------------------------------------------------------------------------
-- 7. Table: settlement_items
-- -----------------------------------------------------------------------------
CREATE TABLE settlement_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    settlement_batch_id UUID NOT NULL REFERENCES settlement_batches(id) ON DELETE CASCADE,
    payment_id UUID NOT NULL REFERENCES payments(id) ON DELETE RESTRICT,
    expected_amount NUMERIC(15, 2) NOT NULL,
    actual_amount NUMERIC(15, 2) NOT NULL,
    reconciliation_status VARCHAR(50) NOT NULL CHECK (reconciliation_status IN ('MATCHED', 'AMOUNT_MISMATCH', 'MISSING', 'DUPLICATE')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- INDEXES FOR PERFORMANCE & CDC LOOKUPS
-- =============================================================================
CREATE INDEX idx_payments_merchant_id ON payments(merchant_id);
CREATE INDEX idx_payments_payment_method_id ON payments(payment_method_id);
CREATE INDEX idx_payments_status ON payments(status);
CREATE INDEX idx_payments_created_at ON payments(created_at);
CREATE INDEX idx_payments_updated_at ON payments(updated_at);

CREATE INDEX idx_payment_status_history_payment_id ON payment_status_history(payment_id);
CREATE INDEX idx_payment_status_history_occurred_at ON payment_status_history(occurred_at);

CREATE INDEX idx_refunds_payment_id ON refunds(payment_id);
CREATE INDEX idx_refunds_status ON refunds(status);

CREATE INDEX idx_settlement_batches_merchant_date ON settlement_batches(merchant_id, settlement_date);
CREATE INDEX idx_settlement_batches_status ON settlement_batches(status);

CREATE INDEX idx_settlement_items_batch_id ON settlement_items(settlement_batch_id);
CREATE INDEX idx_settlement_items_payment_id ON settlement_items(payment_id);

-- =============================================================================
-- DEBEZIUM PUBLICATION & REPLICATION SETUP
-- =============================================================================
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'payflow_publication') THEN
        CREATE PUBLICATION payflow_publication FOR TABLE 
            merchants,
            payment_methods,
            payments,
            payment_status_history,
            refunds,
            settlement_batches,
            settlement_items;
    END IF;
END $$;
