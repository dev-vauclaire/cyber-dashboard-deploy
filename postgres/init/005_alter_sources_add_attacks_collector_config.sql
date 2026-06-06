/*
 * Migrations V2 - rattachement optionnel des sources a une configuration de collecteur.
 */

ALTER TABLE sources
ADD COLUMN IF NOT EXISTS attacks_collector_config_id INT NULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'sources_attacks_collector_config_id_fkey'
          AND conrelid = 'sources'::regclass
    ) THEN
        ALTER TABLE sources
        ADD CONSTRAINT sources_attacks_collector_config_id_fkey
        FOREIGN KEY (attacks_collector_config_id)
        REFERENCES attacks_collector_config(id)
        ON DELETE SET NULL;
    END IF;
END$$;
