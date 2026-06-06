/*
 * Migrations V2 - index de support pour les pages de parametrage et le scheduler V2.
 */

CREATE INDEX IF NOT EXISTS idx_cti_config_is_active
ON cti_config (is_active);

CREATE INDEX IF NOT EXISTS idx_attacks_collector_config_type
ON attacks_collector_config (collector_type);

CREATE INDEX IF NOT EXISTS idx_attacks_collector_config_is_active
ON attacks_collector_config (is_active);

CREATE INDEX IF NOT EXISTS idx_sources_is_active
ON sources (is_active);

CREATE INDEX IF NOT EXISTS idx_sources_attacks_collector_config_id
ON sources (attacks_collector_config_id);

CREATE INDEX IF NOT EXISTS idx_scheduler_state_v2_inventory_status
ON scheduler_state_v2 (last_inventory_status);

CREATE INDEX IF NOT EXISTS idx_scheduler_state_v2_collection_status
ON scheduler_state_v2 (last_collection_status);

CREATE INDEX IF NOT EXISTS idx_scheduler_state_v2_updated_at
ON scheduler_state_v2 (updated_at DESC);
