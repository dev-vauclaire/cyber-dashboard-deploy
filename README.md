# Cyber Dashboard Deploy

Ce dossier contient la stack Docker Compose permettant de déployer Cyber
Dashboard : base PostgreSQL, migrations, API, scheduler, corrélateur,
frontend et reverse proxy HTTPS.

## Sommaire

- [Présentation de l'application](#présentation-de-lapplication)
- [Architecture](#architecture)
- [Déploiement de production](#déploiement-de-production)
- [Démarrage en développement](#démarrage-en-développement)
- [Points de fiabilité vérifiés](#points-de-fiabilité-vérifiés)

## Présentation de l'application

Cyber Dashboard sert à détecter si plusieurs infrastructures supervisées
subissent une attaque commune.

L'application fonctionne en trois étapes :

1. **Collecte** : le scheduler récupère les journaux d'attaques depuis les
   outils de cybersécurité configurés, puis les stocke en base PostgreSQL.
2. **Corrélation** : le corrélateur recherche les adresses IP attaquantes
   présentes dans plusieurs sources et crée une alerte lorsqu'une IP est
   commune à plusieurs environnements.
3. **Enrichissement** : le dashboard permet de consulter les alertes,
   d'enrichir les données avec une CTI légère et d'envoyer un e-mail au
   contact abuse associé à l'adresse IP.

## Architecture

La stack est composée de plusieurs conteneurs, chacun avec un rôle dédié.

| Service Compose | Rôle |
| --- | --- |
| `db` | Stocke les attaques, les alertes, les sources et la configuration applicative. |
| `migrate` | Exécute les migrations Alembic au démarrage, puis s'arrête. |
| `api` | Expose l'API utilisée par le frontend. |
| `scheduler` | Collecte les attaques et met à jour les données applicatives. |
| `common-ip-correlator` | Corrèle les adresses IP communes entre plusieurs sources. |
| `frontend` | Sert l'interface utilisateur. |
| `reverse-proxy` | Termine le TLS et route le trafic vers le frontend ou l'API. |

Les images de production sont configurées par variables d'environnement. Les
sources applicatives sont réparties dans deux dépôts :

| Composant | Dépôt |
| --- | --- |
| Frontend | [cyber-dashboard-frontend](https://github.com/dev-vauclaire/cyber-dashboard-frontend) |
| API, scheduler, corrélateur et migrations | [cyber-dashboard-backend](https://github.com/dev-vauclaire/cyber-dashboard-backend) |

![Schéma de la stack Docker](./assets/dockerStackSchemaV2.png)

## Déploiement de production

Toutes les commandes suivantes sont à exécuter depuis ce dossier :

```bash
cd cyber-dashboard-deploy
```

### Prérequis

- Un hôte Linux est recommandé.
- Docker Engine et Docker Compose v2 doivent être installés.
- Les ports `80` et `443` doivent être disponibles sur l'hôte.
- Un certificat TLS valide doit être disponible pour le nom DNS exposé.
- Une clé maître de chiffrement Fernet doit être créée ou récupérée.
- Le fichier `postgres/init.sql` doit exister, même pour une installation vide.

Le dimensionnement matériel dépend du volume d'attaques collectées, de la
rétention et du nombre de sources. Aucun benchmark de charge n'est fourni dans
ce dépôt. Pour une petite installation ou une recette, prévoir au minimum
`2 vCPU`, `4 Go` de RAM et `20 Go` de disque, puis augmenter selon la
volumétrie PostgreSQL.

### 1. Préparer l'environnement

Créez le fichier `.env` à partir de l'exemple fourni :

```bash
cp .env.example .env
chmod 600 .env
```

Modifiez ensuite `.env` avec les valeurs de production.

| Variable | Description | Statut |
| --- | --- | --- |
| `POSTGRES_USER` | Utilisateur PostgreSQL. | Obligatoire |
| `POSTGRES_PASSWORD` | Mot de passe PostgreSQL. | Obligatoire, à changer |
| `POSTGRES_DB` | Nom de la base PostgreSQL. | Obligatoire |
| `DB_HOST` | Hôte PostgreSQL vu depuis les conteneurs, généralement `db`. | Obligatoire |
| `DB_PORT` | Port PostgreSQL, généralement `5432`. | Obligatoire |
| `API_NAME` | Nom logique de l'API. | Recommandé |
| `API_HOST` | Adresse d'écoute logique de l'API, généralement `0.0.0.0`. | Recommandé |
| `API_PORT` | Port interne de l'API, généralement `8000`. | Recommandé |
| `API_LOG_LEVEL` | Niveau de logs de l'API. | Recommandé |
| `CORRELATOR_BATCH_SIZE` | Taille des lots traités par le corrélateur. | Obligatoire |
| `CORRELATOR_POLL_INTERVAL_SECONDS` | Pause entre deux cycles du corrélateur. | Obligatoire |
| `CORRELATOR_LOG_LEVEL` | Niveau de logs du corrélateur. | Obligatoire |
| `CORRELATOR_COMPUTE_AVERAGE_PROCESSING_TIME` | Active le calcul du temps moyen de traitement. | Obligatoire |
| `LIMIT_REQUEST_PER_DAY` | Limite quotidienne utilisée par le scheduler. | Obligatoire |
| `LOG_LEVEL` | Niveau de logs du scheduler. | Obligatoire |
| `OGO_BASE_URL` | URL de base OGO pour les validations et collectes. | Obligatoire |
| `SERENICITY_BASE_URL` | URL de base Serenicity. | Obligatoire |
| `CYBER_DASHBOARD_SECRET_KEY_FILE` | Chemin interne de la clé montée dans les conteneurs ; le compose fourni le fixe à `/run/secrets/cyber_dashboard_secret_key`. | Garder la valeur de l'exemple |
| `CYBER_DASHBOARD_SECRET_KEY` | Clé maître fournie directement par variable d'environnement. | Optionnel, laisser vide si le fichier secret est monté |
| `CYBER_DASHBOARD_API_IMAGE` | Image de production de l'API. | Obligatoire |
| `CYBER_DASHBOARD_SCHEDULER_IMAGE` | Image de production du scheduler. | Obligatoire |
| `CYBER_DASHBOARD_COMMON_IP_IMAGE` | Image de production du corrélateur. | Obligatoire |
| `CYBER_DASHBOARD_FRONTEND_IMAGE` | Image de production du frontend. | Obligatoire |
| `CYBER_DASHBOARD_MIGRATE_IMAGE` | Image de production du conteneur de migration. | Obligatoire |

Si vous migrez d'anciens identifiants collecteurs, vous pouvez aussi définir
`OGO_USERNAME`, `OGO_API_KEY` et `SERENICITY_API_KEY`. Ces variables sont
optionnelles et ne sont utilisées que par le conteneur `migrate`.

### 2. Préparer la clé maître

La clé maître doit être disponible sur l'hôte dans :

```text
secrets/cyber_dashboard_secret_key
```

Elle est montée dans les conteneurs sous :

```text
/run/secrets/cyber_dashboard_secret_key
```

Le contenu attendu est une clé Fernet, c'est-à-dire une valeur base64 URL-safe
encodant 32 octets. Pour générer une nouvelle clé :

```bash
mkdir -p secrets
python3 -c 'import base64, os; print(base64.urlsafe_b64encode(os.urandom(32)).decode())' \
  > secrets/cyber_dashboard_secret_key
chmod 600 secrets/cyber_dashboard_secret_key
```

Si vous migrez une base qui contient déjà des secrets chiffrés, réutilisez la
clé maître historique. Une nouvelle clé empêcherait le déchiffrement des
secrets existants.

### 3. Préparer HTTPS

Nginx attend les fichiers suivants :

```text
certs/fullchain.pem
certs/privkey.pem
```

Permissions recommandées :

```bash
chmod 644 certs/fullchain.pem
chmod 600 certs/privkey.pem
```

La configuration Nginx active HSTS. N'utilisez cette configuration que lorsque
le certificat et le nom DNS sont stables pour le domaine servi.

### 4. Préparer l'initialisation PostgreSQL

Le compose monte `postgres/init.sql` dans l'image PostgreSQL. Ce fichier doit
donc exister.

Pour une installation neuve :

```bash
mkdir -p postgres
touch postgres/init.sql
```

Pour migrer une ancienne base V1, placez le dump SQL dans ce fichier :

```bash
cp /chemin/vers/dump-v1.sql postgres/init.sql
chmod 644 postgres/init.sql
```

Ce script est exécuté uniquement lors de la première initialisation du volume
PostgreSQL `db_data`. Si le volume existe déjà, PostgreSQL n'exécutera pas de
nouveau `postgres/init.sql`.

Le conteneur `migrate` inspecte ensuite la base :

1. base vide : exécution de `alembic upgrade head` ;
2. base V1 reconnue : marquage de la révision de base, puis migration ;
3. base déjà versionnée Alembic : migration jusqu'à `head` ;
4. schéma inconnu : arrêt de sécurité.

### 5. Valider la configuration

Vérifiez la configuration Compose avant de démarrer :

```bash
docker compose -f docker-compose.prod.yaml config
```

Cette commande doit s'exécuter sans erreur et afficher les services résolus.

### 6. Démarrer la stack

Le fichier `docker-compose.prod.yaml` consomme des images déjà publiées dans un
registry. Il ne build rien localement.

```bash
docker compose -f docker-compose.prod.yaml pull
docker compose -f docker-compose.prod.yaml up -d
```

### 7. Vérifier le démarrage

```bash
docker compose -f docker-compose.prod.yaml ps -a
docker compose -f docker-compose.prod.yaml logs -f migrate
docker compose -f docker-compose.prod.yaml logs -f api scheduler common-ip-correlator reverse-proxy
```

Vérifiez ensuite l'endpoint de santé :

```bash
curl https://votre-domaine.example/health
```

Pour un certificat auto-signé en recette, ajoutez `-k` à la commande `curl`.

## Démarrage en développement

Le fichier `docker-compose.dev.yaml` build les images depuis les dossiers
locaux `../cyber-dashboard-backend` et `../cyber-dashboard-frontend`.

```bash
docker compose -f docker-compose.dev.yaml up --build -d
```

Pour charger les données de démonstration :

```bash
docker compose -f docker-compose.dev.yaml --profile demo-data up seed-dev
```

## Points de fiabilité vérifiés

- La syntaxe de `docker-compose.prod.yaml` et `docker-compose.dev.yaml` est
  valide avec `docker compose ... config`.
- Le scheduler reçoit bien les variables obligatoires attendues par le code,
  notamment `LIMIT_REQUEST_PER_DAY`.
- Le conteneur `migrate` reçoit la même clé maître que l'API et le scheduler.
- La commande de génération de clé documentée produit une clé compatible avec
  Fernet.
- Le fichier `postgres/init.sql` est documenté comme obligatoire parce qu'il
  est monté explicitement par les deux fichiers Compose.
