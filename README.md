# Cyber Dashboard Deploy

Ce dépôt orchestre le déploiement Docker de Cyber Dashboard V2.

La stack déployée repose maintenant sur :
- `cyber-dashboard-backend` pour l'API, le scheduler, le corrélateur d'IP communes et les migrations Alembic
- `cyber-dashboard-frontend` pour l'interface web
- PostgreSQL et Nginx pour la persistance et l'exposition HTTP/HTTPS

## Arborescence attendue

Le dépôt de déploiement reste séparé du monorepo backend. En local, l'arborescence attendue est la suivante :

```text
cyber-dashboard/
├── cyber-dashboard-backend/
├── cyber-dashboard-deploy/
└── cyber-dashboard-frontend/
```

## Architecture de la stack

Les services principaux sont :
- `db` : PostgreSQL
- `migrate` : service one-shot qui exécute `python scripts/migrate.py`
- `api` : backend FastAPI
- `scheduler` : inventaire, collecte et rétention
- `common-ip-correlator` : corrélation des IP communes
- `frontend` : interface web
- `reverse-proxy` : terminaison TLS et routage HTTP/HTTPS

Le schéma de base de données n'est plus créé par des scripts SQL locaux montés dans PostgreSQL.
La seule source de vérité du schéma est désormais :
- `cyber-dashboard-backend/alembic`
- `cyber-dashboard-backend/packages/database/models`

## Variables d'environnement

Crée le fichier `.env` à partir de l'exemple :

```bash
cp .env.example .env
chmod 600 .env
```

Variables attendues :

| Variable | Description |
| --- | --- |
| `POSTGRES_USER` | Utilisateur PostgreSQL |
| `POSTGRES_PASSWORD` | Mot de passe PostgreSQL |
| `POSTGRES_DB` | Nom de la base PostgreSQL |
| `DB_HOST` | Hôte PostgreSQL vu depuis les conteneurs, généralement `db` |
| `DB_PORT` | Port PostgreSQL, généralement `5432` |
| `API_NAME` | Nom logique de l'API |
| `API_HOST` | Adresse d'écoute logique de l'API |
| `API_PORT` | Port logique de l'API |
| `API_LOG_LEVEL` | Niveau de logs de l'API |
| `LOG_LEVEL` | Niveau de logs du scheduler |
| `CORRELATOR_BATCH_SIZE` | Taille de lot du corrélateur |
| `CORRELATOR_POLL_INTERVAL_SECONDS` | Pause entre deux cycles du corrélateur |
| `CORRELATOR_LOG_LEVEL` | Niveau de logs du corrélateur |
| `CORRELATOR_COMPUTE_AVERAGE_PROCESSING_TIME` | Active le calcul du temps moyen |
| `OGO_BASE_URL` | URL de base OGO V2 pour les validations et collectes |
| `SERENICITY_BASE_URL` | URL de base Serenicity |
| `CYBER_DASHBOARD_SECRET_KEY_FILE` | Chemin du secret monté dans les conteneurs |
| `CYBER_DASHBOARD_SECRET_KEY` | Secret direct en variable d'environnement, utilisé seulement si le fichier n'est pas monté |
| `CYBER_DASHBOARD_API_IMAGE` | Image prod de l'API |
| `CYBER_DASHBOARD_SCHEDULER_IMAGE` | Image prod du scheduler |
| `CYBER_DASHBOARD_COMMON_IP_IMAGE` | Image prod du corrélateur |
| `CYBER_DASHBOARD_FRONTEND_IMAGE` | Image prod du frontend |
| `CYBER_DASHBOARD_MIGRATE_IMAGE` | Image prod du conteneur de migration |

Les anciennes variables de credentials collecteur ne sont plus utilisées par la stack V2 :
- `OGO_USERNAME`
- `OGO_API_KEY`
- `OGO_SITE_NAME_OR_ID`
- `SERENICITY_API_KEY`

La configuration des collecteurs se fait désormais dans la base et via l'API.

## Secrets

La clé maître doit être disponible dans :

```text
secrets/cyber_dashboard_secret_key
```

Cette clé est montée dans les conteneurs API et scheduler sous :

```text
/run/secrets/cyber_dashboard_secret_key
```

Le dossier `secrets/` ne doit jamais être commité avec de vrais secrets.

Exemple de génération locale :

```bash
openssl rand -hex 32 > secrets/cyber_dashboard_secret_key
chmod 600 secrets/cyber_dashboard_secret_key
```

## Développement

### Démarrage standard

```bash
docker compose -f docker-compose.dev.yaml up --build
```

Au démarrage :
1. PostgreSQL lance un volume vide.
2. Le service `migrate` applique Alembic avec `python scripts/migrate.py`.
3. L'API, le scheduler et le corrélateur démarrent uniquement après succès de la migration.
4. Le frontend et Nginx démarrent ensuite.

### Avec seed de démonstration

Le profil `demo-data` exécute les scripts SQL placés dans `postgres/seeds/dev/` après la migration :

```bash
docker compose -f docker-compose.dev.yaml --profile demo-data up --build
```

### Reset complet de la base locale

```bash
docker compose -f docker-compose.dev.yaml down -v
docker compose -f docker-compose.dev.yaml up --build
```

### Vérifications utiles

```bash
docker compose -f docker-compose.dev.yaml config
docker compose -f docker-compose.dev.yaml ps -a
docker compose -f docker-compose.dev.yaml logs -f
curl http://127.0.0.1:8000/health
```

## Production

Le fichier `docker-compose.prod.yaml` consomme des images publiées dans un registry.
Il ne build rien localement.

L'image `CYBER_DASHBOARD_MIGRATE_IMAGE` doit embarquer le contenu nécessaire pour exécuter `/app/scripts/migrate.py`.
Le contrat de référence peut être construit à partir de `cyber-dashboard-backend/Dockerfile.migrate`.

### Démarrage

```bash
docker compose -f docker-compose.prod.yaml up -d
```

Le service `migrate` s'exécute en one-shot au démarrage puis les services backend démarrent une fois la migration terminée avec succès.

### Vérifications

```bash
docker compose -f docker-compose.prod.yaml config
docker compose -f docker-compose.prod.yaml ps -a
docker compose -f docker-compose.prod.yaml logs -f
```

## HTTPS

Les certificats attendus par Nginx sont :

```text
certs/fullchain.pem
certs/privkey.pem
```

Permissions recommandées :

```bash
chmod 600 certs/privkey.pem
chmod 644 certs/fullchain.pem
```

## Points d'attention

- Une base vide est initialisée uniquement par Alembic, jamais par des scripts SQL montés au runtime.
- Le dépôt de déploiement ne porte plus la vérité du schéma PostgreSQL.
- Les éventuels jeux de données de développement doivent rester limités au dossier `postgres/seeds/dev/`.
