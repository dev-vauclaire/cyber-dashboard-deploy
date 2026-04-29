# Dashboard cyber déploiement

## Aperçu

Ce dépôt permet de déployer un dashboard de cyber, qui corrèle des adresses IP issues de différentes sources (OGO, Serenicity).
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
1. Le **scheduler** récupère périodiquement les attaques (avec leur adresse IP associée) depuis les APIs OGO et Serenicity, et les stocke dans la base de données.
2. Le **common IP correlator** récupère les nouvelles adresses IP stockées, les compares avec les adresses IP déjà présentes dans sa mémoire RAM. Si il trouve une adresse commune à plusieurs sources, il stocke/update cette information sous forme d'alerte dans la base de données.
3. l'**API** expose les données de la base de données.
4. Le **reverse proxy** reçoit les requêtes HTTP, les redirige vers l'API ou le frontend selon le chemin d'accès, et gère la sécurité et les certificats SSL.
5. Le **frontend** interroge l'API pour afficher les données et les alertes de corrélation à l'utilisateur.

## Installation

### Prérequis

- Linux, Ubuntu recommandé (amd64)
- [Docker](https://docs.docker.com/get-docker/) et [Docker Compose v2](https://docs.docker.com/compose/install/) installés
- Pour récupérer les données depuis OGO :
    - URL de base de l'API OGO
    - username OGO
    - Clé API OGO
    - Nom ou identifiant du site OGO à synchroniser
- Pour récupérer les données depuis Serenicity :
    - URL de base de l'API Serenicity
    - Clé API Serenicity
- Pour mettre en place le protocole HTTPS :
    - Certificat SSL signé par la PKI interne ou l'équipe IT
    - Clé privée associée au certificat

### 1. Cloner le repository

```bash
git clone https://github.com/dev-vauclaire/cyber-dashboard-deploy.git
cd cyber-dashboard-deploy
```

### 2. Créer manuellement le fichier `.env`

La stack lit sa configuration depuis un fichier `.env` placé à la racine du dossier de déploiement.
les variables d'environnement avec le label [REQUIRED] doivent obligatoirement être définies par l'utilisateur, pour les valeurs avec le label [DEFAULT] l'utilisateur peut soit conserver la valeur par défaut, soit la modifier en fonction de ses besoins. ( il est recommandé de laisser les valeurs par défaut ), les variables avec le lable [KEEP] sont utilisées par les services applicatifs et ne doivent pas être modifiées.

#### Créer `.env` depuis `.env.example`

```bash
cp .env.example .env
nano .env
```

Permissions recommandées :

```bash
chmod 600 .env
```

#### Variables d'environnement

| Variable | Description | Valeur par défaut | Obligatoire |
| --- | --- | --- | --- |
| `POSTGRES_USER` | Utilisateur PostgreSQL créé au démarrage | `cyber_dashboard` | [REQUIRED]
| `POSTGRES_PASSWORD` | Mot de passe PostgreSQL | `change-me` | [REQUIRED]
| `POSTGRES_DB` | Nom de la base de données PostgreSQL | `cyber_dashboard` | [REQUIRED]
| `DB_HOST` | Hôte PostgreSQL utilisé par les services applicatifs | `db` | [KEEP]
| `DB_PORT` | Port PostgreSQL utilisé par les services applicatifs | `5432` | [DEFAULT]
| `API_NAME` | Nom affiché ou utilisé par l'API | `Cyber Dashboard API` | [DEFAULT]
| `API_HOST` | Adresse d'écoute de l'API dans le conteneur | `0.0.0.0` | [DEFAULT]
| `API_PORT` | Port d'écoute de l'API dans le conteneur | `8000` | [KEEP]
| `API_LOG_LEVEL` | Niveau de logs de l'API | `INFO` | [DEFAULT]
| `LIMIT_REQUEST_PER_DAY` | Limite de requêtes par jour vers les APIs externes | `24` | [DEFAULT]
| `LOG_LEVEL` | Niveau de logs du scheduler | `INFO` | [DEFAULT]
| `HTTP_TIMEOUT_SECONDS` | Timeout HTTP des appels externes | `20` | [DEFAULT]
| `POLL_SAFETY_WINDOW_SECONDS` | Fenêtre de sécurité pour la récupération périodique | `300` | [DEFAULT]
| `OGO_BASE_URL` | URL de base de l'API OGO | `https://example.ogo.local` | [REQUIRED]
| `OGO_USERNAME` | Identifiant OGO | `user@example.com` | [REQUIRED]
| `OGO_API_KEY` | Clé API OGO | `change-me` | [REQUIRED]
| `OGO_SITE_NAME_OR_ID` | Nom ou identifiant du site OGO à synchroniser | `www.example.com` | [REQUIRED]
| `SERENICITY_BASE_URL` | URL de base de l'API Serenicity | `https://example.serenicity.local` | [REQUIRED]
| `SERENICITY_API_KEY` | Clé API Serenicity | `change-me` | [REQUIRED]
| `CORRELATOR_BATCH_SIZE` | Nombre d'éléments traités par lot | `500` | [DEFAULT]
| `CORRELATOR_POLL_INTERVAL_SECONDS` | Intervalle entre deux traitements | `10` | [DEFAULT]
| `CORRELATOR_LOG_LEVEL` | Niveau de logs du corrélateur | `INFO` | [DEFAULT]
| `CORRELATOR_COMPUTE_AVERAGE_PROCESSING_TIME` | Active le calcul du temps moyen de traitement | `false` | [DEFAULT]

### 3. Mettre en place HTTPS avec certificat entreprise / PKI interne

Le reverse proxy Nginx termine le TLS : les clients se connectent en HTTPS sur Nginx, puis Nginx redirige les requêtes vers le frontend ou l'API sur le réseau Docker interne.

Les certificats doivent être fournis par l'équipe IT, ou générés via une CSR puis signés par la PKI interne. Les fichiers attendus sont :

```text
certs/fullchain.pem
certs/privkey.pem
```

Ces fichiers ne doivent jamais être commités. Le dossier `certs/` sert uniquement à monter les certificats réels dans le conteneur Nginx.

Permissions recommandées :

```bash
chmod 600 certs/privkey.pem
chmod 644 certs/fullchain.pem
```

#### Générer une CSR

Si l'équipe IT demande une CSR, vous pouvez générer une clé privée et une demande de certificat :

```bash
openssl req -new -newkey rsa:4096 -nodes \
  -keyout certs/privkey.pem \
  -out certs/cyber-dashboard.csr \
  -subj "/CN=Nom_DNS"
```

Le fichier `certs/cyber-dashboard.csr` doit ensuite être transmis à l'équipe IT pour signature. Le certificat signé doit être placé dans `certs/fullchain.pem` et la clé privée dans `certs/privkey.pem`.

> Nom DNS = Nom certificat = Nom utilisé dans navigateur

### 4. Lancer la stack

Commande Docker Compose :

```bash
docker compose -f docker-compose.prod.yaml up -d
```

Cette commande récupère les images Docker depuis Docker Hub, crée les conteneurs, et démarre la stack en arrière-plan.

> ⚠️ Nécessite Docker Compose v2 (`docker compose`, pas `docker-compose`)

### 5. Vérifier les services

Vérifier l'état des conteneurs :

```bash
docker compose -f docker-compose.prod.yaml ps -a
```

Cette commande affiche la liste des conteneurs, leur statut, et les ports exposés. Assurez-vous que tous les conteneurs sont en état "Up".

En cas d'erreur, consultez les logs :

```bash
docker compose -f docker-compose.prod.yaml logs -f
```

Cette commande affiche les logs en temps réel, ce qui peut aider à identifier les problèmes de démarrage ou de configuration.

> ⚠️ Nécessite Docker Compose v2 (`docker compose`, pas `docker-compose`)

### 6. Accéder à l'app

Une fois la stack démarrée, l'application est disponible à l'adresse suivante :

```text
https://Nom_DNS/
```

## À faire

- [ ] Ajouter des tests automatisés ( chaine CI/CD )
- [ ] Ajouter un mode d'authentification
- [ ] Ajouter un inventaire interactif des sources de données ( OGO, Serenicity, etc. )
