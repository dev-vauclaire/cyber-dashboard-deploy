/*
 * Migrations V2 - politiques de retention des donnees.
 */

CREATE TABLE IF NOT EXISTS retention_policies (
    id SERIAL PRIMARY KEY,

    target_table VARCHAR(100) NOT NULL UNIQUE,
    retention_days INT NOT NULL DEFAULT 365,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    last_run_at TIMESTAMPTZ NULL,
    last_deleted_count BIGINT NULL,
    last_error TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT retention_policies_target_table_check CHECK (
        target_table IN ('attacks', 'common_ip_alerts')
    ),
    CONSTRAINT retention_policies_retention_days_positive CHECK (
        retention_days > 0
    )
);
