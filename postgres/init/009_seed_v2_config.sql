/*
 * Migrations V2 - donnees initiales de configuration.
 */

INSERT INTO cti_config (code, label, is_active, last_validation_status)
VALUES
    ('abuseipdb', 'AbuseIPDB', FALSE, 'not_tested'),
    ('ipdata', 'IPData', FALSE, 'not_tested'),
    ('greynoise', 'GreyNoise', FALSE, 'not_tested'),
    ('virustotal', 'VirusTotal', FALSE, 'not_tested'),
    ('shodan', 'Shodan', FALSE, 'not_tested'),
    ('rdap_whois', 'RDAP / WHOIS', FALSE, 'not_tested'),
    ('reverse_dns', 'Reverse DNS', FALSE, 'not_tested')
ON CONFLICT (code) DO UPDATE
SET label = EXCLUDED.label,
    updated_at = NOW()
WHERE cti_config.label IS DISTINCT FROM EXCLUDED.label;

INSERT INTO smtp_config (id, is_active, last_validation_status)
VALUES (1, FALSE, 'not_tested')
ON CONFLICT (id) DO NOTHING;

INSERT INTO retention_policies (target_table, retention_days, is_active)
VALUES
    ('attacks', 365, TRUE),
    ('common_ip_alerts', 365, TRUE)
ON CONFLICT (target_table) DO NOTHING;
