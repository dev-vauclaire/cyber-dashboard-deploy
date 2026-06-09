-- Index pour accélérer les lots atomiques du corrélateur
CREATE INDEX IF NOT EXISTS idx_attacks_pending_occurred_at
ON attacks (occurred_at, id)
WHERE correlation_status = 'pending';

-- Pour remettre rapidement en file les attaques restées bloquées en processing
CREATE INDEX IF NOT EXISTS idx_attacks_processing_id
ON attacks (id)
WHERE correlation_status = 'processing';

-- Pour reconstruire l'état mémoire du corrélateur depuis les attaques traitées
CREATE INDEX IF NOT EXISTS idx_attacks_completed_ip_source_occurred_at
ON attacks (attacker_ip, source_id, occurred_at)
WHERE correlation_status = 'completed';

-- Pour total d’attaques entre 2 dates, liste paginée, stats par source et top types d’attaque
CREATE INDEX IF NOT EXISTS idx_attacks_occurred_at
ON attacks (occurred_at DESC, id DESC);

-- Pour filtrer par source + date
CREATE INDEX IF NOT EXISTS idx_attacks_source_occurred_at
ON attacks (source_id, occurred_at DESC, id DESC);

-- Pour filtrer par type d’attaque + date
CREATE INDEX IF NOT EXISTS idx_attacks_type_occurred_at
ON attacks (attack_type, occurred_at DESC, id DESC)
WHERE attack_type IS NOT NULL;

-- Pour la liste paginée des alertes IP communes
CREATE INDEX IF NOT EXISTS idx_common_ip_alerts_rank
ON common_ip_alerts (distinct_source_count DESC, last_seen_at DESC, attacker_ip ASC);

-- Pour filtrer et compter les alertes IP communes par dernière observation
CREATE INDEX IF NOT EXISTS idx_common_ip_alerts_last_seen
ON common_ip_alerts (last_seen_at DESC);

-- Pour filtrer les alertes IP communes par source
CREATE INDEX IF NOT EXISTS idx_common_ip_alert_sources_source_alert
ON common_ip_alert_sources (source_id, alert_id);
