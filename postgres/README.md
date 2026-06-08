# Organisation des scripts SQL

Les scripts de base de donnees sont separes en deux chemins.

## dev-init

`postgres/dev-init/` est utilise par `docker-compose.dev.yaml`.

Ce dossier sert a initialiser une base de developpement depuis zero. Les scripts doivent creer directement le schema final attendu par l'application, puis injecter les donnees de reference et le jeu de donnees de demonstration.

Pour reinitialiser la base de developpement :

```bash
docker compose -f docker-compose.dev.yaml down -v
docker compose -f docker-compose.dev.yaml up --build
```

La commande `down -v` supprime le volume PostgreSQL de developpement. Au prochain `up`, PostgreSQL rejoue les scripts montes dans `/docker-entrypoint-initdb.d`.

## prod-migrations

`postgres/prod-migrations/` conserve les scripts historiques V1. Les migrations incrementales V2 seront ajoutees dans ce dossier au fur et a mesure.

Ce dossier sert de reference pour faire evoluer une base de production depuis la V1 vers le schema final. Les fichiers doivent rester ordonnes numeriquement et ne doivent pas contenir de jeu de donnees de demonstration.

Les migrations de production ne sont pas rejouees automatiquement sur une base PostgreSQL qui possede deja un volume initialise. Elles doivent etre appliquees selon la procedure de migration retenue pour l'environnement cible.
