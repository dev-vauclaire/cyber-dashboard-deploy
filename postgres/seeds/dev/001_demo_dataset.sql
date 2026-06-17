/*
 * Jeu de donnees de developpement pour le schema PostgreSQL V2.
 *
 * Ce seed est aligne sur les migrations Alembic:
 * - 6d98af97a0e5_init_v1_schema.py
 * - 14b43480c45e_v2_schema.py
 *
 * Il est idempotent pour les donnees de demo:
 * - les references et configurations sont inserees/mises a jour par UPSERT;
 * - les attaques prefixees demo-v2 sont supprimees puis regenerees;
 * - les alertes d'IP communes de demo sont reconstruites depuis ces attaques.
 */

BEGIN;

SET LOCAL TIME ZONE 'UTC';

WITH sensor_seed(code, label, category, color) AS (
    VALUES
        ('lurio', 'Lurio Honeypot', 'leurre', '#4A5D4E'),
        ('detoxio', 'Detoxio', 'detection', '#A8C2C0'),
        ('waf', 'Web Application Firewall', 'protection', '#E5DCD3')
)
INSERT INTO sensor_types (code, label, category, color)
SELECT code, label, category, color
FROM sensor_seed
ON CONFLICT (code) DO UPDATE
SET
    label = EXCLUDED.label,
    category = EXCLUDED.category,
    color = EXCLUDED.color;

WITH cti_seed(
    code,
    label,
    encrypted_api_key,
    api_key_hint,
    is_key_required,
    is_active,
    last_validation_status
) AS (
    VALUES
        ('abuseipdb', 'AbuseIPDB', 'demo-encrypted-abuseipdb-key', '****demo', TRUE, TRUE, 'success'),
        ('ipdata', 'IPData', 'demo-encrypted-ipdata-key', '****data', TRUE, TRUE, 'success'),
        ('greynoise', 'GreyNoise', NULL, NULL, TRUE, FALSE, 'not_tested'),
        ('virustotal', 'VirusTotal', 'demo-encrypted-virustotal-key', '****vt', TRUE, TRUE, 'success'),
        ('shodan', 'Shodan', NULL, NULL, TRUE, FALSE, 'not_tested'),
        ('rdap', 'RDAP / WHOIS', NULL, NULL, FALSE, TRUE, 'success'),
        ('reverse_dns', 'Reverse DNS', NULL, NULL, FALSE, TRUE, 'success')
)
INSERT INTO cti_config (
    code,
    label,
    encrypted_api_key,
    api_key_hint,
    is_key_required,
    is_active,
    last_validation_status,
    last_validation_at,
    last_validation_error,
    updated_at
)
SELECT
    code,
    label,
    encrypted_api_key,
    api_key_hint,
    is_key_required,
    is_active,
    last_validation_status,
    CASE WHEN last_validation_status = 'success' THEN NOW() ELSE NULL END,
    NULL,
    NOW()
FROM cti_seed
ON CONFLICT (code) DO UPDATE
SET
    label = EXCLUDED.label,
    encrypted_api_key = EXCLUDED.encrypted_api_key,
    api_key_hint = EXCLUDED.api_key_hint,
    is_key_required = EXCLUDED.is_key_required,
    is_active = EXCLUDED.is_active,
    last_validation_status = EXCLUDED.last_validation_status,
    last_validation_at = EXCLUDED.last_validation_at,
    last_validation_error = NULL,
    updated_at = NOW();

INSERT INTO smtp_config (
    id,
    smtp_host,
    smtp_port,
    smtp_user,
    encrypted_smtp_password,
    smtp_password_hint,
    smtp_from,
    smtp_from_name,
    is_active,
    last_validation_status,
    last_validation_at,
    last_validation_error,
    updated_at
)
VALUES (
    1,
    'smtp.demo-v2.test',
    587,
    'alerts@demo-v2.test',
    'demo-encrypted-smtp-password',
    '****smtp',
    'alerts@demo-v2.test',
    'Cyber Dashboard Demo',
    TRUE,
    'success',
    NOW(),
    NULL,
    NOW()
)
ON CONFLICT (id) DO UPDATE
SET
    smtp_host = EXCLUDED.smtp_host,
    smtp_port = EXCLUDED.smtp_port,
    smtp_user = EXCLUDED.smtp_user,
    encrypted_smtp_password = EXCLUDED.encrypted_smtp_password,
    smtp_password_hint = EXCLUDED.smtp_password_hint,
    smtp_from = EXCLUDED.smtp_from,
    smtp_from_name = EXCLUDED.smtp_from_name,
    is_active = EXCLUDED.is_active,
    last_validation_status = EXCLUDED.last_validation_status,
    last_validation_at = EXCLUDED.last_validation_at,
    last_validation_error = NULL,
    updated_at = NOW();

WITH retention_seed(target_table, retention_days) AS (
    VALUES
        ('attacks', 365),
        ('common_ip_alerts', 180)
)
INSERT INTO retention_policies (
    target_table,
    retention_days,
    is_active,
    last_run_at,
    last_deleted_count,
    last_error,
    updated_at
)
SELECT
    target_table,
    retention_days,
    TRUE,
    NOW() - INTERVAL '1 day',
    0,
    NULL,
    NOW()
FROM retention_seed
ON CONFLICT (target_table) DO UPDATE
SET
    retention_days = EXCLUDED.retention_days,
    is_active = TRUE,
    last_run_at = EXCLUDED.last_run_at,
    last_deleted_count = 0,
    last_error = NULL,
    updated_at = NOW();

WITH collector_seed(
    name,
    collector_type,
    encrypted_email,
    email_hint,
    encrypted_api_key,
    api_key_hint,
    is_active,
    inventory_requested,
    last_validation_status
) AS (
    VALUES
        (
            'OGO Demo EU',
            'ogo'::attacks_collector_type,
            'demo-encrypted-ogo@example.test',
            'o***@demo',
            'demo-encrypted-ogo-key',
            '****ogo',
            TRUE,
            FALSE,
            'success'
        ),
        (
            'OGO Demo Partner',
            'ogo'::attacks_collector_type,
            'demo-encrypted-partner@example.test',
            'p***@demo',
            'demo-encrypted-ogo-partner-key',
            '****part',
            TRUE,
            FALSE,
            'success'
        ),
        (
            'Serenicity Demo',
            'serenicity'::attacks_collector_type,
            NULL,
            NULL,
            'demo-encrypted-serenicity-key',
            '****sere',
            TRUE,
            FALSE,
            'success'
        )
)
INSERT INTO attacks_collector_config (
    name,
    collector_type,
    encrypted_email,
    email_hint,
    encrypted_api_key,
    api_key_hint,
    is_active,
    inventory_requested,
    last_validation_status,
    last_validation_at,
    last_validation_error,
    updated_at
)
SELECT
    name,
    collector_type,
    encrypted_email,
    email_hint,
    encrypted_api_key,
    api_key_hint,
    is_active,
    inventory_requested,
    last_validation_status,
    NOW(),
    NULL,
    NOW()
FROM collector_seed
ON CONFLICT ON CONSTRAINT attacks_collector_config_unique_name_per_type DO UPDATE
SET
    encrypted_email = EXCLUDED.encrypted_email,
    email_hint = EXCLUDED.email_hint,
    encrypted_api_key = EXCLUDED.encrypted_api_key,
    api_key_hint = EXCLUDED.api_key_hint,
    is_active = EXCLUDED.is_active,
    inventory_requested = EXCLUDED.inventory_requested,
    last_validation_status = EXCLUDED.last_validation_status,
    last_validation_at = EXCLUDED.last_validation_at,
    last_validation_error = NULL,
    updated_at = NOW();

WITH source_seed(
    source_key,
    sensor_type_code,
    collector_name,
    name,
    color,
    is_active
) AS (
    VALUES
        ('ogo_portal', 'waf', 'OGO Demo EU', 'Portail client', '#D8C4A5', TRUE),
        ('ogo_extranet', 'waf', 'OGO Demo EU', 'Extranet RH', '#C9B79A', TRUE),
        ('ogo_api', 'waf', 'OGO Demo EU', 'API paiement', '#BFAE91', TRUE),
        ('ogo_shop', 'waf', 'OGO Demo Partner', 'Boutique publique', '#E7D8C0', FALSE),
        ('detoxio_paris', 'detoxio', 'Serenicity Demo', 'Detoxio Paris', '#9BB7B5', TRUE),
        ('detoxio_lyon', 'detoxio', 'Serenicity Demo', 'Detoxio Lyon', '#8AAEAA', TRUE),
        ('detoxio_lille', 'detoxio', 'Serenicity Demo', 'Detoxio Lille', '#B7CFCD', FALSE),
        ('lurio_marseille', 'lurio', 'Serenicity Demo', 'Lurio Marseille', '#526957', TRUE),
        ('lurio_nantes', 'lurio', 'Serenicity Demo', 'Lurio Nantes', '#617764', TRUE),
        ('lurio_toulouse', 'lurio', 'Serenicity Demo', 'Lurio Toulouse', '#78907A', TRUE)
),
resolved AS (
    SELECT
        ss.source_key,
        st.id AS sensor_type_id,
        acc.id AS attacks_collector_config_id,
        ss.name,
        ss.color,
        ss.is_active
    FROM source_seed ss
    JOIN sensor_types st
        ON st.code = ss.sensor_type_code
    JOIN attacks_collector_config acc
        ON acc.name = ss.collector_name
)
INSERT INTO sources (
    sensor_type_id,
    attacks_collector_config_id,
    name,
    color,
    is_active,
    created_at,
    updated_at
)
SELECT
    sensor_type_id,
    attacks_collector_config_id,
    name,
    color,
    is_active,
    NOW() - INTERVAL '60 days',
    NOW()
FROM resolved
WHERE NOT EXISTS (
    SELECT 1
    FROM sources existing
    WHERE existing.name = resolved.name
      AND existing.sensor_type_id = resolved.sensor_type_id
);

WITH source_seed(
    source_key,
    sensor_type_code,
    collector_name,
    name,
    color,
    is_active
) AS (
    VALUES
        ('ogo_portal', 'waf', 'OGO Demo EU', 'Portail client', '#D8C4A5', TRUE),
        ('ogo_extranet', 'waf', 'OGO Demo EU', 'Extranet RH', '#C9B79A', TRUE),
        ('ogo_api', 'waf', 'OGO Demo EU', 'API paiement', '#BFAE91', TRUE),
        ('ogo_shop', 'waf', 'OGO Demo Partner', 'Boutique publique', '#E7D8C0', FALSE),
        ('detoxio_paris', 'detoxio', 'Serenicity Demo', 'Detoxio Paris', '#9BB7B5', TRUE),
        ('detoxio_lyon', 'detoxio', 'Serenicity Demo', 'Detoxio Lyon', '#8AAEAA', TRUE),
        ('detoxio_lille', 'detoxio', 'Serenicity Demo', 'Detoxio Lille', '#B7CFCD', FALSE),
        ('lurio_marseille', 'lurio', 'Serenicity Demo', 'Lurio Marseille', '#526957', TRUE),
        ('lurio_nantes', 'lurio', 'Serenicity Demo', 'Lurio Nantes', '#617764', TRUE),
        ('lurio_toulouse', 'lurio', 'Serenicity Demo', 'Lurio Toulouse', '#78907A', TRUE)
)
UPDATE sources s
SET
    attacks_collector_config_id = acc.id,
    color = ss.color,
    is_active = ss.is_active,
    updated_at = NOW()
FROM source_seed ss
JOIN sensor_types st
    ON st.code = ss.sensor_type_code
JOIN attacks_collector_config acc
    ON acc.name = ss.collector_name
WHERE s.name = ss.name
  AND s.sensor_type_id = st.id;

WITH ogo_seed(name, domain_name, organization_codes) AS (
    VALUES
        ('Portail client', 'portal.demo-v2.test', ARRAY['VAUCLAIRE', 'PORTAL']::VARCHAR[]),
        ('Extranet RH', 'rh.demo-v2.test', ARRAY['VAUCLAIRE', 'HR']::VARCHAR[]),
        ('API paiement', 'api-pay.demo-v2.test', ARRAY['VAUCLAIRE', 'PAYMENT']::VARCHAR[]),
        ('Boutique publique', 'shop.demo-v2.test', ARRAY['PARTNER', 'SHOP']::VARCHAR[])
),
resolved AS (
    SELECT s.id AS source_id, os.domain_name, os.organization_codes
    FROM ogo_seed os
    JOIN sources s
        ON s.name = os.name
)
INSERT INTO ogo_sources (source_id, domain_name, organization_codes)
SELECT source_id, domain_name, organization_codes
FROM resolved
ON CONFLICT (source_id) DO UPDATE
SET
    domain_name = EXCLUDED.domain_name,
    organization_codes = EXCLUDED.organization_codes;

WITH serenicity_seed(name, external_id, latitude, longitude) AS (
    VALUES
        ('Detoxio Paris', '200001', 48.8566::DOUBLE PRECISION, 2.3522::DOUBLE PRECISION),
        ('Detoxio Lyon', '200002', 45.7640::DOUBLE PRECISION, 4.8357::DOUBLE PRECISION),
        ('Detoxio Lille', '200003', 50.6292::DOUBLE PRECISION, 3.0573::DOUBLE PRECISION),
        ('Lurio Marseille', '300001', 43.2965::DOUBLE PRECISION, 5.3698::DOUBLE PRECISION),
        ('Lurio Nantes', '300002', 47.2184::DOUBLE PRECISION, -1.5536::DOUBLE PRECISION),
        ('Lurio Toulouse', '300003', 43.6047::DOUBLE PRECISION, 1.4442::DOUBLE PRECISION)
),
resolved AS (
    SELECT s.id AS source_id, ss.external_id, ss.latitude, ss.longitude
    FROM serenicity_seed ss
    JOIN sources s
        ON s.name = ss.name
)
INSERT INTO serenicity_sources (source_id, external_id, latitude, longitude)
SELECT source_id, external_id, latitude, longitude
FROM resolved
ON CONFLICT (source_id) DO UPDATE
SET
    external_id = EXCLUDED.external_id,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude;

WITH source_order AS (
    SELECT
        s.id AS source_id,
        ROW_NUMBER() OVER (ORDER BY s.name) AS source_rank,
        s.is_active
    FROM sources s
    WHERE s.name IN (
        'Portail client',
        'Extranet RH',
        'API paiement',
        'Boutique publique',
        'Detoxio Paris',
        'Detoxio Lyon',
        'Detoxio Lille',
        'Lurio Marseille',
        'Lurio Nantes',
        'Lurio Toulouse'
    )
),
state_seed AS (
    SELECT
        source_id,
        NOW() - INTERVAL '2 hours' - (source_rank * INTERVAL '3 minutes') AS inventory_at,
        NOW() - INTERVAL '15 minutes' - (source_rank * INTERVAL '2 minutes') AS poll_at,
        is_active
    FROM source_order
)
INSERT INTO scheduler_state (
    source_id,
    last_inventory_at,
    last_poll_at,
    last_inventory_status,
    last_inventory_success_at,
    last_inventory_error_at,
    last_inventory_error_message,
    last_collection_status,
    last_collection_success_at,
    last_collection_error_at,
    last_collection_error_message
)
SELECT
    source_id,
    inventory_at,
    poll_at,
    'success',
    inventory_at,
    NULL,
    NULL,
    CASE WHEN is_active THEN 'success' ELSE 'failed' END,
    CASE WHEN is_active THEN poll_at ELSE NULL END,
    CASE WHEN is_active THEN NULL ELSE poll_at END,
    CASE WHEN is_active THEN NULL ELSE 'Source de demo inactive pendant la derniere collecte' END
FROM state_seed
ON CONFLICT (source_id) DO UPDATE
SET
    last_inventory_at = EXCLUDED.last_inventory_at,
    last_poll_at = EXCLUDED.last_poll_at,
    last_inventory_status = EXCLUDED.last_inventory_status,
    last_inventory_success_at = EXCLUDED.last_inventory_success_at,
    last_inventory_error_at = NULL,
    last_inventory_error_message = NULL,
    last_collection_status = EXCLUDED.last_collection_status,
    last_collection_success_at = EXCLUDED.last_collection_success_at,
    last_collection_error_at = EXCLUDED.last_collection_error_at,
    last_collection_error_message = EXCLUDED.last_collection_error_message;

WITH demo_alerts AS (
    SELECT DISTINCT cia.id
    FROM common_ip_alerts cia
    JOIN common_ip_alert_sources cias
        ON cias.alert_id = cia.id
    JOIN attacks a
        ON a.attacker_ip = cia.attacker_ip
       AND a.source_id = cias.source_id
    WHERE a.deduplication_id LIKE 'demo-v2:%'
)
DELETE FROM common_ip_alert_sources cias
USING demo_alerts da
WHERE cias.alert_id = da.id;

WITH demo_alerts AS (
    SELECT DISTINCT cia.id
    FROM common_ip_alerts cia
    WHERE cia.attacker_ip IN (
        '198.51.100.23',
        '198.51.100.77',
        '203.0.113.41',
        '203.0.113.99',
        '192.0.2.150'
    )
)
DELETE FROM common_ip_alerts cia
USING demo_alerts da
WHERE cia.id = da.id;

DELETE FROM attacks
WHERE deduplication_id LIKE 'demo-v2:%';

WITH source_catalog(source_key, source_name, is_active_demo) AS (
    VALUES
        ('ogo_portal', 'Portail client', TRUE),
        ('ogo_extranet', 'Extranet RH', TRUE),
        ('ogo_api', 'API paiement', TRUE),
        ('ogo_shop', 'Boutique publique', FALSE),
        ('detoxio_paris', 'Detoxio Paris', TRUE),
        ('detoxio_lyon', 'Detoxio Lyon', TRUE),
        ('detoxio_lille', 'Detoxio Lille', FALSE),
        ('lurio_marseille', 'Lurio Marseille', TRUE),
        ('lurio_nantes', 'Lurio Nantes', TRUE),
        ('lurio_toulouse', 'Lurio Toulouse', TRUE)
),
source_map AS (
    SELECT sc.source_key, s.id AS source_id, sc.is_active_demo
    FROM source_catalog sc
    JOIN sources s
        ON s.name = sc.source_name
),
common_pattern(attacker_ip, source_key, pattern_rank) AS (
    VALUES
        ('198.51.100.23', 'ogo_portal', 0),
        ('198.51.100.23', 'detoxio_paris', 1),
        ('198.51.100.23', 'lurio_marseille', 2),
        ('198.51.100.77', 'ogo_api', 0),
        ('198.51.100.77', 'detoxio_lyon', 1),
        ('198.51.100.77', 'lurio_nantes', 2),
        ('203.0.113.41', 'ogo_extranet', 0),
        ('203.0.113.41', 'detoxio_paris', 1),
        ('203.0.113.41', 'lurio_toulouse', 2),
        ('203.0.113.99', 'ogo_portal', 0),
        ('203.0.113.99', 'ogo_api', 1),
        ('203.0.113.99', 'lurio_marseille', 2),
        ('192.0.2.150', 'detoxio_lyon', 0),
        ('192.0.2.150', 'lurio_nantes', 1),
        ('192.0.2.150', 'lurio_toulouse', 2)
),
common_attacks AS (
    SELECT
        format(
            'demo-v2:common:%s:%s:%s',
            cp.attacker_ip,
            day_offset,
            cp.source_key
        ) AS deduplication_id,
        sm.source_id,
        format('demo-v2-common-%s-%s-%s', day_offset, cp.pattern_rank, replace(cp.attacker_ip, '.', '-')) AS source_event_id,
        cp.attacker_ip::INET AS attacker_ip,
        (
            date_trunc('day', NOW())
            - (day_offset * INTERVAL '1 day')
            + ((2 + cp.pattern_rank * 3 + day_offset) % 24) * INTERVAL '1 hour'
            + ((day_offset * 7 + cp.pattern_rank * 11) % 60) * INTERVAL '1 minute'
        ) AS occurred_at,
        (
            date_trunc('day', NOW())
            - (day_offset * INTERVAL '1 day')
            + ((2 + cp.pattern_rank * 3 + day_offset) % 24) * INTERVAL '1 hour'
            + ((day_offset * 7 + cp.pattern_rank * 11) % 60) * INTERVAL '1 minute'
            + INTERVAL '5 minutes'
        ) AS collected_at,
        (ARRAY[
            'sql_injection',
            'xss',
            'path_traversal',
            'brute_force',
            'command_injection',
            'rce',
            'bot',
            'vulnerability_scan',
            'credential_stuffing',
            'malicious_probe'
        ])[((day_offset + cp.pattern_rank) % 10) + 1] AS attack_type,
        jsonb_build_object(
            'dataset', 'demo-v2',
            'source_key', cp.source_key,
            'severity', (ARRAY['medium', 'high', 'critical'])[(cp.pattern_rank % 3) + 1],
            'country', (ARRAY['FR', 'US', 'NL', 'DE', 'SG'])[(day_offset % 5) + 1],
            'confidence', 80 + ((day_offset + cp.pattern_rank) % 20),
            'rule', format('demo-common-rule-%s', cp.pattern_rank + 1)
        ) AS raw_payload,
        'completed'::status_correlation AS correlation_status
    FROM generate_series(0, 44) AS day_offset
    JOIN common_pattern cp
        ON day_offset % 2 = 0
    JOIN source_map sm
        ON sm.source_key = cp.source_key
),
active_sources AS (
    SELECT
        source_key,
        source_id,
        ROW_NUMBER() OVER (ORDER BY source_key) AS active_rank
    FROM source_map
    WHERE is_active_demo = TRUE
),
random_attacks AS (
    SELECT
        format('demo-v2:random:%s:%s', day_offset, slot) AS deduplication_id,
        selected.source_id,
        format('demo-v2-random-%s-%s', day_offset, slot) AS source_event_id,
        (
            CASE (day_offset + slot) % 3
                WHEN 0 THEN '192.0.2.'
                WHEN 1 THEN '198.51.100.'
                ELSE '203.0.113.'
            END
            || (10 + ((day_offset * 30 + slot) % 230))::TEXT
        )::INET AS attacker_ip,
        (
            date_trunc('day', NOW())
            - (day_offset * INTERVAL '1 day')
            + (slot % 24) * INTERVAL '1 hour'
            + ((slot * 13 + day_offset) % 60) * INTERVAL '1 minute'
            + ((slot * 17 + day_offset) % 60) * INTERVAL '1 second'
        ) AS occurred_at,
        (
            date_trunc('day', NOW())
            - (day_offset * INTERVAL '1 day')
            + (slot % 24) * INTERVAL '1 hour'
            + ((slot * 13 + day_offset) % 60) * INTERVAL '1 minute'
            + ((slot * 17 + day_offset) % 60) * INTERVAL '1 second'
            + INTERVAL '8 minutes'
        ) AS collected_at,
        (ARRAY[
            'sql_injection',
            'xss',
            'path_traversal',
            'brute_force',
            'command_injection',
            'rce',
            'bot',
            'vulnerability_scan',
            'credential_stuffing',
            'malicious_probe'
        ])[((day_offset + slot) % 10) + 1] AS attack_type,
        jsonb_build_object(
            'dataset', 'demo-v2',
            'source_key', selected.source_key,
            'severity', (ARRAY['low', 'medium', 'high', 'critical'])[((slot + day_offset) % 4) + 1],
            'country', (ARRAY['FR', 'US', 'NL', 'DE', 'SG', 'BR'])[((slot + day_offset) % 6) + 1],
            'confidence', 55 + ((slot * 3 + day_offset) % 45),
            'rule', format('demo-rule-%s', ((slot + day_offset) % 12) + 1)
        ) AS raw_payload,
        (ARRAY[
            'pending'::status_correlation,
            'processing'::status_correlation,
            'completed'::status_correlation
        ])[((slot + day_offset) % 3) + 1] AS correlation_status
    FROM generate_series(0, 44) AS day_offset
    CROSS JOIN generate_series(0, 29) AS slot
    JOIN LATERAL (
        SELECT source_key, source_id
        FROM active_sources
        WHERE active_rank = (((day_offset * 30 + slot) % (SELECT COUNT(*) FROM active_sources)) + 1)
    ) selected ON TRUE
),
all_attacks AS (
    SELECT * FROM common_attacks
    UNION ALL
    SELECT * FROM random_attacks
)
INSERT INTO attacks (
    deduplication_id,
    source_id,
    source_event_id,
    attacker_ip,
    occurred_at,
    collected_at,
    attack_type,
    raw_payload,
    correlation_status
)
SELECT
    deduplication_id,
    source_id,
    source_event_id,
    attacker_ip,
    occurred_at,
    collected_at,
    attack_type,
    raw_payload,
    correlation_status
FROM all_attacks
ON CONFLICT (deduplication_id) DO NOTHING;

WITH grouped AS (
    SELECT
        attacker_ip,
        source_id,
        MIN(occurred_at) AS first_seen_at,
        MAX(occurred_at) AS last_seen_at,
        COUNT(*)::INT AS hit_count
    FROM attacks
    WHERE deduplication_id LIKE 'demo-v2:%'
    GROUP BY attacker_ip, source_id
),
eligible AS (
    SELECT attacker_ip
    FROM grouped
    GROUP BY attacker_ip
    HAVING COUNT(*) >= 2
),
alert_rows AS (
    SELECT
        g.attacker_ip,
        MIN(g.first_seen_at) AS first_seen_at,
        MAX(g.last_seen_at) AS last_seen_at,
        COUNT(*)::INT AS distinct_source_count,
        CASE
            WHEN MAX(g.last_seen_at) >= NOW() - INTERVAL '14 days' THEN 'open'
            ELSE 'acknowledged'
        END AS status
    FROM grouped g
    JOIN eligible e
        ON e.attacker_ip = g.attacker_ip
    GROUP BY g.attacker_ip
)
INSERT INTO common_ip_alerts (
    attacker_ip,
    first_seen_at,
    last_seen_at,
    distinct_source_count,
    status,
    updated_at
)
SELECT
    attacker_ip,
    first_seen_at,
    last_seen_at,
    distinct_source_count,
    status,
    NOW()
FROM alert_rows
ON CONFLICT (attacker_ip) DO UPDATE
SET
    first_seen_at = EXCLUDED.first_seen_at,
    last_seen_at = EXCLUDED.last_seen_at,
    distinct_source_count = EXCLUDED.distinct_source_count,
    status = EXCLUDED.status,
    updated_at = NOW();

WITH grouped AS (
    SELECT
        attacker_ip,
        source_id,
        MIN(occurred_at) AS first_seen_at,
        MAX(occurred_at) AS last_seen_at,
        COUNT(*)::INT AS hit_count
    FROM attacks
    WHERE deduplication_id LIKE 'demo-v2:%'
    GROUP BY attacker_ip, source_id
),
eligible AS (
    SELECT attacker_ip
    FROM grouped
    GROUP BY attacker_ip
    HAVING COUNT(*) >= 2
)
INSERT INTO common_ip_alert_sources (
    alert_id,
    source_id,
    first_seen_at,
    last_seen_at,
    hit_count
)
SELECT
    cia.id,
    g.source_id,
    g.first_seen_at,
    g.last_seen_at,
    g.hit_count
FROM grouped g
JOIN eligible e
    ON e.attacker_ip = g.attacker_ip
JOIN common_ip_alerts cia
    ON cia.attacker_ip = g.attacker_ip
ON CONFLICT (alert_id, source_id) DO UPDATE
SET
    first_seen_at = EXCLUDED.first_seen_at,
    last_seen_at = EXCLUDED.last_seen_at,
    hit_count = EXCLUDED.hit_count;

COMMIT;
