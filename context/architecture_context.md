# Architecture du projet Cyber Dashboard

Ce document donne du contexte sur l'architecture du projet Cyber Dashboard. Il décrit le type d'architecture, les services clés, les technologies utilisées et les interactions entre les différentes parties du système.

## Type d'architecture

Microservices

## Services clés

1. **frontend** :
- Role : Ce service est responsable de renvoyer l'interface utilisateur.
- Communication : Il communique avec l'API REST pour récupérer des données pertinentes ou pour changer l'état de l'application.
- Technologies : React, TypeScript, Material UI
2. **API REST** :
- Role : Ce service est responsable de la communication avec la base de données et les appels api d'enrichissement cti externes.
- Communication : Il communique avec la base de données pour stocker et récupérer des données.
- Technologies : Python, FastAPI
3. **base de données** :
- Role : Ce service est responsable du stockage des données. Il utilise PostgreSQL pour stocker les données structurées.
- Communication : Il communique avec le scheduler pour stocker les résultats de l'inventaire des sources et la collecte des attaques, avec le common-ip pour stocker les résultats des alertes d'IP communes, et avec l'API REST pour stocker et récupérer des données.
- Technologies : PostgreSQL
4. **reverse proxy** :
- Role : Ce service est responsable de la gestion du trafic entrant et de la redirection des requêtes vers les services appropriés (frontend, API REST). Il permet également de set up le https
- Communication : Il communique avec le frontend et l'API REST pour rediriger les requêtes entrantes vers le bon service.
- Technologies : Nginx
5. **scheduler** :
- Role : Ce service est responsable de l'exécution de tâches planifiées, telles que l'inventaire des sources et la collecte des attaques détectés par ces mêmes sources.
- Communication : Il communique avec la base de données pour stocker les résultats de l'inventaire des sources et la collecte des attaques.
- Technologies : Python
6. **common-ip** :
- Role : Ce service est responsable de la logique de corrélation des adresses IP.
- Communication : Il communique avec la base de données pour récupérer les attaques non traités et pour stocker les résultats de la corrélation.
- Technologies : Python
