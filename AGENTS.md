@RTK.md

## Git

@conventional-commits.md
Gitflow : branches `feature/*`, `fix/*`, `release/*` depuis `develop`, merge vers `main` à la release.
Ne **jamais** merge en fast-forward, toujours `--no-ff`.

## Commandes Bash

Préférer ces outils aux équivalents par défaut. Fallback silencieux si absent.

- **Recherche de contenu** : `rg` plutôt que `grep`
- **Recherche de fichiers** : `fd` plutôt que `find`
- **JSON** : `jq` pour tout parsing, filtrage ou transformation
- **YAML/TOML** : `yq`
- **GitHub** : `gh` pour PRs, issues, reviews, CI, releases. Ne pas scraper github.com ni taper l'API REST quand `gh` suffit.
- **GitLab** : `glab` pour MRs, issues, reviews, CI, releases. Idem.

## Workflow agents IA

- **Invoque le skill `superpowers:using-superpowers` en début de session si demande de développement, fonctionnalité ou implémentation ; pas pour une question simple.**
- **Vérifie dans le navigateur** (skill `playwright-cli`) sur **toute** US à incidence UI.
- Toujours terminer une tâche de code par :
  - `/simplify`
  - `/ponytail:ponytail-review`
  - Faire les ajustements si nécessaire.

## Orchestration du workflow

### 1. Plan mode par défaut

- Entrer en plan mode pour TOUTE tâche non triviale (3+ étapes ou décision d'architecture).
- Si ça dérape, STOP et re-planifier immédiatement — ne pas s'acharner.
- Écrire des specs détaillées en amont pour réduire l'ambiguïté.

### 2. Stratégie sous-agents

- Utiliser les sous-agents librement pour garder le contexte principal propre.
- Déléguer recherche, exploration et analyse parallèle aux sous-agents.

### 3. Boucle d'auto-amélioration

- Après TOUTE correction de l'utilisateur : noter le pattern dans `tasks/lessons.md`.
- Écrire des règles pour soi-même qui évitent de reproduire l'erreur.

### 4. Vérification avant « terminé »

- Ne jamais marquer une tâche comme terminée sans prouver qu'elle fonctionne.
- Lancer les tests, vérifier les logs, démontrer la correction.
- Lancer `/simplify`, lancer `/ponytail:ponytail-review`.

### 5. Exiger de l'élégance (équilibré)

- Pour les changements non triviaux : se demander « existe-t-il une façon plus élégante ? ».
- Si un fix semble bricolé : « connaissant tout ce que je sais maintenant, implémente la solution élégante ».
- Sauter cette étape pour les fixes simples et évidents — ne pas sur-concevoir.

## Principes fondamentaux

- **Simplicité d'abord** : rendre chaque changement aussi simple que possible. Impact minimal.
- **Pas de paresse** : trouver les causes racines. Pas de fix temporaire. Standards senior.
- **Impact minimal** : ne toucher que le nécessaire. Éviter d'introduire des bugs.
