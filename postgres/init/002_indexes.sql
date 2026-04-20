-- Index pour accélérer les recherches du corrélateur
CREATE INDEX IF NOT EXISTS idx_attacks_pending_occurred_at
ON attacks (occurred_at, id)
WHERE correlation_status = 'pending';

CREATE INDEX IF NOT EXISTS idx_attacks_attacker_ip
ON attacks (attacker_ip);

-- Pour total d’attaques entre 2 dates, liste paginée, stats par source et top types d’attaque
CREATE INDEX IF NOT EXISTS idx_attacks_occurred_at
ON attacks (occurred_at DESC);

-- Pour filtrer par source + date
CREATE INDEX IF NOT EXISTS idx_attacks_source_occurred_at
ON attacks (source_id, occurred_at DESC);

-- Pour filtrer par type d’attaque + date
CREATE INDEX IF NOT EXISTS idx_attacks_type_occurred_at
ON attacks (attack_type, occurred_at DESC)
WHERE attack_type IS NOT NULL;

-- Pour l'inventaire / jointure par type de capteur
CREATE INDEX IF NOT EXISTS idx_sources_sensor_type_id
ON sources (sensor_type_id);