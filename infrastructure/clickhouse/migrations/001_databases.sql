-- ============================================================
-- 001: Create ClickHouse databases
-- payflow_raw  → append-only CDC events
-- payflow_core → current-state + event history + real-time aggregates
-- payflow_mart → dbt-managed business marts
-- ============================================================

CREATE DATABASE IF NOT EXISTS payflow_raw;
CREATE DATABASE IF NOT EXISTS payflow_core;
CREATE DATABASE IF NOT EXISTS payflow_mart;
