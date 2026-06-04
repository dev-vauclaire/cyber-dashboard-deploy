# Database Context

Ce document donne du contexte sur les tables de la base de données postgres utilisées dans le projet Cyber Dashboard, ainsi que les rôles associés à ces tables.

## Tables et roles

1. **sources** :
- Rôle : Cette table stocke les informations sur les différentes sources pour la collecte d'attaques

2. **attacks** :
- Rôle : Cette table stocke les attaques collectées à partir des différentes sources. Elle contient des informations telles que l'adresse IP, la source de l'attaque, le timestamp, etc.

3. **common_ip_alerts** :
- Rôle : Cette table stocke les alertes d'IP communes à plusieurs sources. Elle contient des informations telles que l'adresse IP, les sources associées, le nombre d'occurrences, etc.

4. **sensor_types** :
- Rôle : Cette table stocke les différents types de capteurs pris en charge par l'application.

5. **common_ip_alert_sources** :
- Rôle : Cette table stocke les sources associées à chaque alerte d'IP commune. Elle permet de faire le lien entre les alertes d'IP communes et les sources des attaques qui y sont associées.

6. **scheduler_state** :
- Rôle : Cette table stocke l'état du scheduler par rapport à une source. Elle contient des informations telles que la dernière date d'inventaire, la dernière date de collecte des attaques, etc.

## Index et pourquoi