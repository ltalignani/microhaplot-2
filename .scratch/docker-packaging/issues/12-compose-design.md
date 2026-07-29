---
status: open
type: wayfinder:task
blocked_by: ["11-dockerfile-design.md"]
---

## Question

Concevoir le `docker-compose.yml` qui orchestre les deux services :

- Un service `prep` (runShinyHaplotPrep) et un service `main`
  (runShinyHaplot), tous deux basés sur la même image (voir [Conception du
  Dockerfile](11-dockerfile-design.md)), avec des commandes/points d'entrée
  différents.
- Un volume partagé monté dans les deux conteneurs comme `app.path` (voir
  [Partage des .rds entre les deux conteneurs](09-rds-sharing.md) et
  [Transfert de fichiers utilisateur](03-data-transfer.md)) — chemin hôte
  configurable (ex: variable d'environnement ou valeur par défaut
  documentée).
- Ports exposés pour chaque service, et lesquels sont recommandés/à
  documenter pour éviter les collisions avec d'autres apps locales de
  l'utilisateur.
- Pas de dépendance de démarrage stricte entre les deux services (l'un
  n'a pas besoin d'attendre l'autre pour démarrer), à confirmer.

## Resolution

_à compléter à la résolution de ce ticket_
