# Cyber Dashboard - Global Context

Ce document vise à fournir un contexte global sur l'ensemble du projet Cyber Dashboard.

## Vision du projet

Cyber Dashboard est une application web orientée cybersécurité.

Objectif :
Corréler des attaques provenant de plusieurs capteurs/sources afin de détecter rapidement des adresses IP malveillantes communes à plusieurs sources.

- Sources actuellement prises en charge :
  - OGO
  - Serenicity Lurio
  - Serenicity Detoxio

Le projet n'est pas conçu pour de la sur-ingénierie : la simplicité et la lisibilité priment.

---

## Objectifs métier

Faire un tableau de bord simple qui :
- Permet de visualiser les attaques détectées par différentes sources
- Manager ses sources disponibles (ajout, suppression, configuration)
- Permet de visualiser les alertes d'IP communes à plusieurs sources
- Exposer des statistiques :
  - total attaques
  - répartition par source
  - alertes d'IP communes
  - liste paginée d’attaques
- Faire de l'enrichissement CTI light (géolocalisation, ASN, etc.) sur les adresses IP malveillantes détectées
- Permettre de lancer une alerte via un email au fournisseur de l'adresse IP malveillante détectée
- Permettre une installation et un déploiement simples de l'application via Docker et Docker Compose

---

## Contraintes métier

Le projet est destiné à un environnement entreprise.

Contraintes fortes :

- fiabilité
- traçabilité
- maintenabilité
- sécurité
- faible temps de détection
- simplicité de déploiement

Les données sensibles ne doivent jamais être stockées dans le code.

---

## Règles d’évolution

Avant toute évolution :

1. analyser impact BDD
2. analyser impact API
3. analyser impact scheduler
4. analyser impact frontend
5. analyser impact common-ip
6. analyser impact reverse-proxy
7. analyser impact documentation
