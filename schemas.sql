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
DROP TABLE IF EXISTS sensor_types CASCADE;

-- Table représentant un type de capteur
CREATE TABLE sensor_types (
    id SERIAL PRIMARY KEY,
    code VARCHAR(50) NOT NULL UNIQUE, -- Ajouté pour faciliter les liens applicatifs
    label VARCHAR(150) NOT NULL,
    category VARCHAR(100) NOT NULL
);

-- Table représentant une source 
CREATE TABLE sources (
    id SERIAL PRIMARY KEY,
    sensor_type_id INT NOT NULL REFERENCES sensor_types(id),
    external_id VARCHAR(150),
    name VARCHAR(150) NOT NULL,
    latitude DOUBLE PRECISION NULL,
    longitude DOUBLE PRECISION NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE(sensor_type_id, external_id)
);

CREATE TYPE status_correlation AS ENUM ('pending', 'processing', 'completed', 'failed');

-- Table des attaques
CREATE TABLE attacks (
    id BIGSERIAL PRIMARY KEY, 
    deduplication_id VARCHAR(255) NOT NULL UNIQUE, -- Hash calculer sur source_id + attacker_ip + occured_at
    source_id INT NOT NULL REFERENCES sources(id),
    source_event_id VARCHAR(150) NULL,
    attacker_ip VARCHAR(45) NOT NULL,
    occured_at TIMESTAMP NOT NULL,
    collected_at TIMESTAMP NOT NULL DEFAULT NOW(),
    attack_type VARCHAR(100) NULL,
    raw_payload JSONB NULL,
    correlation_status status_correlation NOT NULL DEFAULT 'pending',
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Alertes globales par IP
CREATE TABLE common_ip_alerts (
    id BIGSERIAL PRIMARY KEY,
    attacker_ip VARCHAR(45) NOT NULL UNIQUE,
    first_seen_at TIMESTAMP NOT NULL,
    last_seen_at TIMESTAMP NOT NULL,
    distinct_source_count INT NOT NULL DEFAULT 2,
    status VARCHAR(20) NOT NULL DEFAULT 'open',
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Relation alertes / sources
CREATE TABLE common_ip_alert_sources (
    alert_id BIGINT NOT NULL REFERENCES common_ip_alerts(id) ON DELETE CASCADE,
    source_id INT NOT NULL REFERENCES sources(id),
    first_seen_at TIMESTAMP NOT NULL,
    last_seen_at TIMESTAMP NOT NULL,
    hit_count INT NOT NULL DEFAULT 1,
    PRIMARY KEY (alert_id, source_id)
);

-- État du scheduler
CREATE TABLE scheduler_state (
    source_id INT PRIMARY KEY REFERENCES sources(id) ON DELETE CASCADE,
    last_inventory_at TIMESTAMP NULL,
    last_poll_at TIMESTAMP NULL,
    last_success_at TIMESTAMP NULL,
    last_error_at TIMESTAMP NULL,
    last_error_message TEXT NULL
);