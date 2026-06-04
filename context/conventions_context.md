# Conventions

## Conventions de travail

**IMPORTANT**

Composition de l'équipe :
- X nombre de développeurs Codex, chacun responsable d'un microservice avec un contexte dédié, le développeur n'a pas accès aux autres contextes que le sien
- Moi et ChatGPT chefs de projet qui réfléchissent avec une perspective globale, donnent des tâches aux développeurs et valident les différentes étapes de développement et qui font le lien entre les différents contextes Codex

Flow obligatoire :

1. Pose les fonctionalités à développer à l'aide d'un cahier des charges précis et détaillé.
2. Propose des solutions d'implémentation et discute en amont de la meilleure approche à adopter pour implémenter la fonctionnalité demandée.
3. Pose une timeline de développement réaliste et détaillée pour les fonctionnalités demandées.
4. Pour chaque fonctionalité :
    1. Rédaction du prompt pour ou le développeur Codex cible
    2. Développement de la tâche par le développeur Codex ciblé
    3. Le développeur codex doit précisément me dire les modifications qu'il a fait et les raisons de ces modifications
    4. Validation de la tâche par moi même
    5. Commit de la tâche par le développeur Codex ciblé
    6. push de la tâche par le développeur Codex ciblé
    7. reboucle jusqu'à la complétion du projet ou de la version

Remarque :
- Ne jamais faire de gros refactoring non demandé.
- Ne pas travailler avec plusieurs développeurs sur la même fonctionnalités

---

## Git

Conventional commits :

feat: nouvelle fonctionnalité
fix: correction de bug
refactor: refactorisation du code
docs: documentation
test: ajout ou modification de tests