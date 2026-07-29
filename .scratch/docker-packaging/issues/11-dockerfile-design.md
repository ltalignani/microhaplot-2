---
status: open
type: wayfinder:task
blocked_by: []
---

## Question

Concevoir le Dockerfile unique servant aux deux conteneurs (main + prep) :

- Image de base R à utiliser (version, distribution Linux) — pas de Shiny
  Server (voir [Approche serveur Shiny](10-shiny-server-approach.md)).
- Installation des dépendances système : Perl (>5.014), `samtools`
  (requis pour le support BAM), bibliothèques système requises par les
  packages R (ggplot2, hierfstat, pcadapt, etc.).
- Installation du package `microhaplot` lui-même (depuis le repo, à une
  version/tag donné).
- Deux points d'entrée possibles dans la même image : un pour
  `runShinyHaplot()`, un pour `runShinyHaplotPrep()`, sélectionnables via
  une commande/variable d'environnement passée par docker-compose.
- Support multi-arch (amd64 + arm64) — voir [Priorité plateformes
  cible](08-platform-priority.md).

## Resolution

_à compléter à la résolution de ce ticket_
