---
status: open
type: wayfinder:task
blocked_by: ["11-dockerfile-design.md"]
---

## Question

Concevoir le workflow GitHub Actions de build + publication (voir
[Automatisation CI de publication](07-ci-publish-automation.md)) :

- Déclencheur : sur quel évènement (tag `v*`, release GitHub, push sur
  `master` avec changement du Dockerfile/DESCRIPTION, ou combinaison) ?
- Stratégie de tag d'image : suivre `Version:` de `DESCRIPTION`, `latest`,
  ou les deux ?
- Build multi-arch via `docker buildx` (amd64 + arm64, voir [Priorité
  plateformes cible](08-platform-priority.md)).
- Registre cible : `ghcr.io/ltalignani/microhaplot-2` (voir [Distribution
  de l'image](05-distribution.md)) — authentification via
  `GITHUB_TOKEN`/permissions du repo.
- Faut-il un smoke test dans le workflow avant publication (voir
  [Vérification build multi-arch et smoke test](15-multiarch-smoke-test.md))
  ?

## Resolution

_à compléter à la résolution de ce ticket_
