# Dashboard cyber déploiement

## Aperçu

Ce dépôt permet de déployer un dashboard de cyber, qui corrèle des addresses IP issues de différentes sources (OGO, Serenicity).
Pour cela, l'application orchestre plusieurs projets GitHub packagés sous forme d'images Docker. 

**Chaque module a une responsabilité**
| Module | GitHub | Docker Hub | Responsabilité |
| --- | --- | --- | --- |
| Frontend | [GitHub](https://github.com/dev-vauclaire/cyber-dashboard-frontend) | [Docker Hub](https://hub.docker.com/repository/docker/devauclaire/cyber-dashboard-frontend/general) | Interface web |
| API | [GitHub](https://github.com/dev-vauclaire/cyber-dashboard-api.git) | [Docker Hub](https://hub.docker.com/r/devauclaire/cyber-dashboard-api) | API |
| Scheduler | [GitHub](https://github.com/dev-vauclaire/cyber-dashboard-scheduler.git) | [Docker Hub](https://hub.docker.com/r/devauclaire/cyber-dashboard-scheduler) | Récupère périodiquement les IP |
| Common IP Correlator | [GitHub](https://github.com/dev-vauclaire/cyber-dashboard-common-ip.git) | [Docker Hub](https://hub.docker.com/r/devauclaire/cyber-dashboard-common-ip) | Corrélation des adresses IP communes |
| Base de données | Image officielle PostgreSQL | [Docker Hub](https://hub.docker.com/_/postgres) | Base de données |
| Reverse proxy | Image officielle Nginx | [Docker Hub](https://hub.docker.com/_/nginx) | Reverse proxy |

## Architecture

![Schéma de la stack Docker](./assets/dockerStackSchema.png "Schéma de la stack Docker")

Flow de la stack : 
1. Le **scheduler** récupère périodiquement les adresses IP depuis les APIs OGO et Serenicity, et les stocke dans la base de données.
2. Le **common IP correlator** récupère les nouvelles adresses IP stockées, les compares avec les adresses IP déjà présentes dans sa mémoire RAM. Si il trouve une addresse commune à plusieurs sources, il stocke cette information sous forme d'alerte dans la base de données.
3. l'**API** expose les données de la BDD.
4. Le **reverse proxy** reçoit les requêtes HTTP, les redirige vers l'API ou le frontend selon le chemin d'accès, et gère la sécurité et les certificats SSL.
5. Le **frontend** interroge l'API pour afficher les données et les alertes de corrélation à l'utilisateur.

## Installation

### Prérequis

- Linux, Ubuntu recommandé (amd64)
- Docker et Docker Compose installés
- Pour OGO :
    - URL de base de l'API OGO
    - username OGO
    - Clé API OGO
    - Nom ou identifiant du site OGO à synchroniser
- Pour Serenicity :
    - URL de base de l'API Serenicity
    - Clé API Serenicity

### 1. Cloner le repository

```bash
git clone https://github.com/dev-vauclaire/cyber-dashboard-deploy.git
cd cyber-dashboard-deploy
```

### 2. Créer manuellement le fichier `.env`

La stack lit sa configuration depuis un fichier `.env` placé à la racine du dossier de déploiement.

#### Variables d'environnement

| Variable | Description | Exemple |
| --- | --- | --- |
| `POSTGRES_USER` | Utilisateur PostgreSQL créé au démarrage | `cyber_dashboard` |
| `POSTGRES_PASSWORD` | Mot de passe PostgreSQL | `change-me` |
| `POSTGRES_DB` | Nom de la base de données PostgreSQL | `cyber_dashboard` |
| `DATABASE_URL` | URL de connexion utilisée par l'API | `postgresql://cyber_dashboard:change-me@db:5432/cyber_dashboard` |
| `API_NAME` | Nom affiché ou utilisé par l'API | `Cyber Dashboard API` |
| `API_HOST` | Adresse d'écoute de l'API dans le conteneur | `0.0.0.0` |
| `API_PORT` | Port d'écoute de l'API dans le conteneur | `8000` |
| `API_LOG_LEVEL` | Niveau de logs de l'API | `INFO` |
| `SCHEDULER_DB_HOST` | Hôte PostgreSQL utilisé par le scheduler | `db` |
| `SCHEDULER_DB_PORT` | Port PostgreSQL utilisé par le scheduler | `5432` |
| `SCHEDULER_DB_NAME` | Base PostgreSQL utilisée par le scheduler | `cyber_dashboard` |
| `SCHEDULER_DB_USER` | Utilisateur PostgreSQL utilisé par le scheduler | `cyber_dashboard` |
| `SCHEDULER_DB_PASSWORD` | Mot de passe PostgreSQL utilisé par le scheduler | `change-me` |
| `LIMIT_REQUEST_PER_DAY` | Limite de requêtes par jour vers les APIs externes | `24` |
| `LOG_LEVEL` | Niveau de logs du scheduler | `INFO` |
| `HTTP_TIMEOUT_SECONDS` | Timeout HTTP des appels externes | `30` |
| `POLL_SAFETY_WINDOW_SECONDS` | Fenêtre de sécurité pour la récupération périodique | `300` |
| `OGO_BASE_URL` | URL de base de l'API OGO | `https://example.ogo.local` |
| `OGO_USERNAME` | Identifiant OGO | `user@example.com` |
| `OGO_API_KEY` | Clé API OGO | `change-me` |
| `OGO_SITE_NAME_OR_ID` | Nom ou identifiant du site OGO à synchroniser | `site-1` |
| `OGO_JOURNAL_PAGE_SIZE` | Taille des pages récupérées depuis le journal OGO | `100` |
| `SERENICITY_BASE_URL` | URL de base de l'API Serenicity | `https://example.serenicity.local` |
| `SERENICITY_API_KEY` | Clé API Serenicity | `change-me` |
| `CORRELATOR_DB_HOST` | Hôte PostgreSQL utilisé par le corrélateur | `db` |
| `CORRELATOR_DB_PORT` | Port PostgreSQL utilisé par le corrélateur | `5432` |
| `CORRELATOR_DB_NAME` | Base PostgreSQL utilisée par le corrélateur | `cyber_dashboard` |
| `CORRELATOR_DB_USER` | Utilisateur PostgreSQL utilisé par le corrélateur | `cyber_dashboard` |
| `CORRELATOR_DB_PASSWORD` | Mot de passe PostgreSQL utilisé par le corrélateur | `change-me` |
| `CORRELATOR_BATCH_SIZE` | Nombre d'éléments traités par lot | `500` |
| `CORRELATOR_POLL_INTERVAL_SECONDS` | Intervalle entre deux traitements | `60` |
| `CORRELATOR_LOG_LEVEL` | Niveau de logs du corrélateur | `INFO` |
| `CORRELATOR_COMPUTE_AVERAGE_PROCESSING_TIME` | Active le calcul du temps moyen de traitement | `true` |

#### Créer `.env` depuis `.env.example`

```bash
cp .env.example .env
nano .env
```

Adaptez ensuite les valeurs en fonction de votre usage

### 3. Lancer la stack

Commande Docker Compose :

```bash
docker compose -f docker-compose.prod.yaml up -d
```

### 4. Vérifier les services

Vérifier l'état des conteneurs :

```bash
docker compose -f docker-compose.prod.yaml ps
```

### 5. Accéder à l'app

Une fois la stack démarrée, l'application est disponible à l'adresse suivante :

```text
http://localhost:80
```

Depuis un serveur distant, remplacez `localhost` par l'adresse IP ou le nom de domaine du serveur :

## À faire

- [ ] Activer HTTPS
- [ ] Sécuriser les variables sensibles
- [ ] Ajouter un mode d'authentification
