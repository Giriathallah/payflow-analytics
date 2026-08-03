-- =============================================================================
-- Flyway Migration V2: Seed Initial Data (Merchants & Payment Methods)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Seed Payment Methods
-- -----------------------------------------------------------------------------
INSERT INTO payment_methods (id, code, name, provider, type, is_active) VALUES
    (gen_random_uuid(), 'BCA_VA', 'BCA Virtual Account', 'Bank BCA', 'VIRTUAL_ACCOUNT', TRUE),
    (gen_random_uuid(), 'MANDIRI_VA', 'Mandiri Virtual Account', 'Bank Mandiri', 'VIRTUAL_ACCOUNT', TRUE),
    (gen_random_uuid(), 'GOPAY', 'GoPay E-Wallet', 'GoTo', 'E_WALLET', TRUE),
    (gen_random_uuid(), 'OVO', 'OVO E-Wallet', 'Grab / OVO', 'E_WALLET', TRUE),
    (gen_random_uuid(), 'QRIS', 'QRIS Standard', 'ASPI / Bank Indonesia', 'QR', TRUE),
    (gen_random_uuid(), 'CREDIT_CARD', 'Credit Card Visa/Mastercard', 'Midtrans / Xendit Gateway', 'CREDIT_CARD', TRUE)
ON CONFLICT (code) DO NOTHING;

-- -----------------------------------------------------------------------------
-- Seed Sample Merchants
-- -----------------------------------------------------------------------------
INSERT INTO merchants (id, external_id, name, category, city, fee_rate, is_active) VALUES
    (gen_random_uuid(), 'MERCH-ENT-001', 'Tokopedia Tech Store', 'ENTERPRISE', 'Jakarta', 0.0100, TRUE),
    (gen_random_uuid(), 'MERCH-ENT-002', 'Shopee Supermarket', 'ENTERPRISE', 'Jakarta', 0.0120, TRUE),
    (gen_random_uuid(), 'MERCH-MED-001', 'Kopi Kenangan Resto', 'MEDIUM', 'Bandung', 0.0150, TRUE),
    (gen_random_uuid(), 'MERCH-MED-002', 'Janji Jiwa Coffee', 'MEDIUM', 'Surabaya', 0.0150, TRUE),
    (gen_random_uuid(), 'MERCH-SML-001', 'Toko Kelontong Berkah', 'SMALL', 'Yogyakarta', 0.0200, TRUE),
    (gen_random_uuid(), 'MERCH-SML-002', 'Warung Makan Sederhana', 'SMALL', 'Medan', 0.0200, TRUE)
ON CONFLICT (external_id) DO NOTHING;
