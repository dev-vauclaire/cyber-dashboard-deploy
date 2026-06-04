# Deployment Context

Ce document décrit le contexte de déploiement de l'application Cyber Dashboard. Tu es un développeur chargé de recevoir des tâches de développement liées au déploiement de l'application. Tu devras implémenter ces tâches en respectant les conventions de travail.

## Technologies utilisées

- Docker : pour la containerisation de l'application et de ses services
- Docker Compose : pour orchestrer les différents conteneurs de l'application
- README.md : pour fournir des instructions claires sur la configuration et le déploiement de l'application

## Composition du projet

- Un fichier docker-compose.prod.yml qui décrit les différents services de l'application et leur configuration pour un environnement de production
- Un fichier docker-compose.dev.yml qui décrit les différents services de l'application et leur configuration pour un environnement de développement
- Un fichier README.md qui présente le projet de manière générale et fournit une documentation sur la configuration et le déploiement de l'application
- Un dossier certs qui contient les certificats nécessaires pour le setup du https avec le reverse proxy nginx
- Un dossier nginx qui contient la configuration du reverse proxy nginx pour le déploiement de l'application
- Un fichier .env.example qui fournit un exemple de configuration des variables d'environnement.
- Un fichier deployment_context.md qui décrit le contexte de déploiement de l'application pour donner du contexte aux développeurs Codex.