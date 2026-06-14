# PostgreSQL dans `cyber-dashboard-deploy`

Ce dépôt ne porte plus les migrations de schéma PostgreSQL.

La seule source de vérité du schéma Cyber Dashboard V2 est :
- `cyber-dashboard-backend/alembic`
- `cyber-dashboard-backend/packages/database/models`

## Principe

Le service `migrate` de Docker Compose exécute :

```bash
python scripts/migrate.py
```

Ce script, embarqué depuis `cyber-dashboard-backend`, détecte l'état réel de la base puis applique Alembic.

Conséquences :
- aucun dossier PostgreSQL local n'est monté dans `/docker-entrypoint-initdb.d`
- `cyber-dashboard-deploy` ne doit plus contenir de scripts de création de tables ou d'index métier
- les évolutions de schéma doivent être faites dans le monorepo backend, puis consommées ici via le service `migrate`

## Seeds de développement

Le seul usage restant du dossier `postgres/` dans ce dépôt est le seed optionnel de développement :

```text
postgres/
└── seeds/
    └── dev/
```

Les scripts SQL placés dans `postgres/seeds/dev/` sont exécutés uniquement si le profil Compose `demo-data` est activé.

Exemple :

```bash
docker compose -f docker-compose.dev.yaml --profile demo-data up --build
```

Ces scripts doivent :
- rester idempotents autant que possible
- contenir uniquement des données locales de démonstration
- ne jamais devenir une source de vérité du schéma
