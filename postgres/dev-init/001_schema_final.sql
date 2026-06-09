/*
 * Initialise les schémas de la base de donnée
 */

-- Nettoyage
DROP TABLE IF EXISTS scheduler_state CASCADE;
DROP TABLE IF EXISTS common_ip_alert_sources CASCADE;
DROP TABLE IF EXISTS common_ip_alerts CASCADE;
DROP TABLE IF EXISTS attacks CASCADE;
DROP TYPE IF EXISTS status_correlation CASCADE;
DROP TABLE IF EXISTS sources CASCADE;
DROP TYPE IF EXISTS source_kind CASCADE;
DROP TABLE IF EXISTS sensor_types CASCADE;
DROP TABLE IF EXISTS attacks_collector_config CASCADE;
DROP TYPE IF EXISTS attacks_collector_type CASCADE;
DROP TABLE IF EXISTS ogo_sources CASCADE;
DROP TABLE IF EXISTS serenicity_sources CASCADE;



/* créer un type ENUM pour les types de collecteurs d'attaques */
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

-- Table représentant un type de capteur
CREATE TABLE sensor_types (
    id SERIAL PRIMARY KEY,
    code VARCHAR(50) NOT NULL UNIQUE, -- Ajouté pour faciliter les liens applicatifs
    label VARCHAR(150) NOT NULL,
    category VARCHAR(100) NOT NULL,
    color VARCHAR(7) NOT NULL DEFAULT '#FF0000'
);

/* table commune des sources */
CREATE TABLE sources (
    id SERIAL PRIMARY KEY,

    sensor_type_id INT NOT NULL
        REFERENCES sensor_types(id),

    attacks_collector_config_id INT NULL
        REFERENCES attacks_collector_config(id)
        ON DELETE SET NULL,

    name VARCHAR(150) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    color VARCHAR(30) NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT sources_name_not_empty CHECK (
        LENGTH(TRIM(name)) > 0
    )
);

/* table spécialisée OGO */
CREATE TABLE ogo_sources (
    source_id INT PRIMARY KEY
        REFERENCES sources(id)
        ON DELETE CASCADE,

    site_url VARCHAR(500) NOT NULL,
    organization_code VARCHAR(100) NOT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT ogo_sources_site_url_not_empty CHECK (
        LENGTH(TRIM(site_url)) > 0
    ),
    CONSTRAINT ogo_sources_organization_code_not_empty CHECK (
        LENGTH(TRIM(organization_code)) > 0
    )
);

/* table spécialisée Serenicity */
CREATE TABLE serenicity_sources (
    source_id INT PRIMARY KEY
        REFERENCES sources(id)
        ON DELETE CASCADE,

    external_id VARCHAR(255) NOT NULL,
    latitude DOUBLE PRECISION NULL,
    longitude DOUBLE PRECISION NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT serenicity_sources_external_id_not_empty CHECK (
        LENGTH(TRIM(external_id)) > 0
    ),
    CONSTRAINT serenicity_sources_latitude_range CHECK (
        latitude IS NULL OR latitude BETWEEN -90 AND 90
    ),
    CONSTRAINT serenicity_sources_longitude_range CHECK (
        longitude IS NULL OR longitude BETWEEN -180 AND 180
    )
);

CREATE TYPE status_correlation AS ENUM ('pending', 'processing', 'completed', 'failed');

-- Table des attaques
CREATE TABLE attacks (
    id BIGSERIAL PRIMARY KEY, 
    deduplication_id VARCHAR(255) NOT NULL UNIQUE, -- Hash calculer sur source_id + attacker_ip + occurred_at
    source_id INT NOT NULL REFERENCES sources(id),
    source_event_id VARCHAR(150) NULL,
    attacker_ip INET NOT NULL,
    occurred_at TIMESTAMPTZ NOT NULL,
    collected_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    attack_type VARCHAR(100) NULL,
    raw_payload JSONB NULL,
    correlation_status status_correlation NOT NULL DEFAULT 'pending'
);

-- Alertes globales par IP
CREATE TABLE common_ip_alerts (
    id BIGSERIAL PRIMARY KEY,
    attacker_ip INET NOT NULL UNIQUE,
    first_seen_at TIMESTAMPTZ NOT NULL,
    last_seen_at TIMESTAMPTZ NOT NULL,
    distinct_source_count INT NOT NULL DEFAULT 2,
    status VARCHAR(20) NOT NULL DEFAULT 'open',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Relation alertes / sources
CREATE TABLE common_ip_alert_sources (
    alert_id BIGINT NOT NULL REFERENCES common_ip_alerts(id) ON DELETE CASCADE,
    source_id INT NOT NULL REFERENCES sources(id),
    first_seen_at TIMESTAMPTZ NOT NULL,
    last_seen_at TIMESTAMPTZ NOT NULL,
    hit_count INT NOT NULL DEFAULT 1,
    PRIMARY KEY (alert_id, source_id)
);

-- État du scheduler
CREATE TABLE scheduler_state (
    source_id INT PRIMARY KEY REFERENCES sources(id) ON DELETE CASCADE,
    last_inventory_at TIMESTAMPTZ NULL,
    last_poll_at TIMESTAMPTZ NULL,
    last_success_at TIMESTAMPTZ NULL,
    last_error_at TIMESTAMPTZ NULL,
    last_error_message TEXT NULL
);

