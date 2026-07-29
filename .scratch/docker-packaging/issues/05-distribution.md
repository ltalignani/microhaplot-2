---
status: closed
type: wayfinder:grilling
---

## Question

L'utilisateur récupère-t-il une image Docker déjà construite (pull) ou
construit-il l'image lui-même localement (build) à partir du repo ?

## Resolution

**Image publiée sur un registre, pull direct.** Publication sur GitHub
Container Registry (ghcr.io), rattachée au repo `ltalignani/microhaplot-2`
existant. L'utilisateur n'a besoin que du `docker-compose.yml` (et de
Docker Desktop) — pas de clone git, pas de build local, pas de
compilateur R/Perl requis sur sa machine.
