DROP TABLE IF EXISTS attacks_collector_config CASCADE;

/* créer un type ENUM pour les types de collecteurs d'attaques, avec une migration idempotente */
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'attacks_collector_type'
    ) THEN
        CREATE TYPE attacks_collector_type AS ENUM ('ogo', 'serenicity');
    END IF;
END$$;

/* table de configuration des collecteurs d'attaques */
CREATE TABLE IF NOT EXISTS attacks_collector_config (
    id SERIAL PRIMARY KEY,

    name VARCHAR(30) NOT NULL,
    collector_type attacks_collector_type NOT NULL,

    email VARCHAR(255) NULL,

    encrypted_api_key TEXT NULL,
    api_key_hint VARCHAR(32) NULL,

    is_active BOOLEAN NOT NULL DEFAULT FALSE,

    last_validation_status VARCHAR(30) NULL,
    last_validation_at TIMESTAMPTZ NULL,
    last_validation_error TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT attacks_collector_config_name_not_empty CHECK (
        LENGTH(TRIM(name)) > 0
    ),
    CONSTRAINT attacks_collector_config_unique_name_per_type UNIQUE (
        collector_type,
        name
    ),
    CONSTRAINT attacks_collector_config_validation_status_check CHECK (
        last_validation_status IS NULL
        OR last_validation_status IN ('success', 'failed', 'not_tested')
    )
);