-- Index pour accélérer les recherches du corrélateur
CREATE INDEX idx_attacks_status ON attacks(correlation_status) WHERE correlation_status = 'pending';
CREATE INDEX idx_attacks_attacker_ip ON attacks(attacker_ip);