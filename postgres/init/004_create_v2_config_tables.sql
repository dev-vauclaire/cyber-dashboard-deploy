/*
 * Migrations V2 - tables de configuration CTI, SMTP et collecteurs d'attaques.
 */

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'attacks_collector_type'
    ) THEN
        CREATE TYPE attacks_collector_type AS ENUM ('ogo', 'serenicity');
    END IF;
END$$;

CREATE TABLE IF NOT EXISTS cti_config (
    id SERIAL PRIMARY KEY,

    code VARCHAR(25) NOT NULL UNIQUE,
    label VARCHAR(25) NOT NULL,

    encrypted_api_key TEXT NULL,
    api_key_hint VARCHAR(32) NULL,

    is_active BOOLEAN NOT NULL DEFAULT FALSE,

    last_validation_status VARCHAR(30) NULL,
    last_validation_at TIMESTAMPTZ NULL,
    last_validation_error TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT cti_config_code_not_empty CHECK (LENGTH(TRIM(code)) > 0),
    CONSTRAINT cti_config_label_not_empty CHECK (LENGTH(TRIM(label)) > 0),
    CONSTRAINT cti_config_validation_status_check CHECK (
        last_validation_status IS NULL
        OR last_validation_status IN ('success', 'failed', 'not_tested')
    )
);

CREATE TABLE IF NOT EXISTS smtp_config (
    id SMALLINT PRIMARY KEY DEFAULT 1,

    smtp_host VARCHAR(30) NULL,
    smtp_port INT NULL,

    smtp_user VARCHAR(30) NULL,
    encrypted_smtp_password TEXT NULL,
    smtp_password_hint VARCHAR(32) NULL,

    smtp_from VARCHAR(30) NULL,
    smtp_from_name VARCHAR(30) NULL,

    is_active BOOLEAN NOT NULL DEFAULT FALSE,

    last_validation_status VARCHAR(30) NULL,
    last_validation_at TIMESTAMPTZ NULL,
    last_validation_error TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT smtp_config_singleton CHECK (id = 1),
    CONSTRAINT smtp_config_port_range CHECK (
        smtp_port IS NULL OR smtp_port BETWEEN 1 AND 65535
    ),
    CONSTRAINT smtp_config_validation_status_check CHECK (
        last_validation_status IS NULL
        OR last_validation_status IN ('success', 'failed', 'not_tested')
    )
);

CREATE TABLE IF NOT EXISTS attacks_collector_config (
    id SERIAL PRIMARY KEY,

    name VARCHAR(30) NOT NULL,
    collector_type attacks_collector_type NOT NULL,

    encrypted_api_key TEXT NULL,
    api_key_hint VARCHAR(32) NULL,

    encrypted_username TEXT NULL,
    username_hint VARCHAR(32) NULL,

    site_name_or_id VARCHAR(80) NULL,

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
