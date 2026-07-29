---
status: closed
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

**Un seul `docker-compose.yml`, deux services, même image, différenciés par
`MICROHAPLOT_APP`** (voir [Conception du Dockerfile](11-dockerfile-design.md)) :

```yaml
services:
  main:
    image: ghcr.io/ltalignani/microhaplot-2:${MICROHAPLOT_VERSION:-latest}
    environment:
      MICROHAPLOT_APP: main
    volumes:
      - ${MICROHAPLOT_DATA_DIR:-./microhaplot-data}:/home/appuser
    ports:
      - "3838:3838"
    user: "${MICROHAPLOT_UID:-1000}:${MICROHAPLOT_GID:-1000}"

  prep:
    image: ghcr.io/ltalignani/microhaplot-2:${MICROHAPLOT_VERSION:-latest}
    environment:
      MICROHAPLOT_APP: prep
    volumes:
      - ${MICROHAPLOT_DATA_DIR:-./microhaplot-data}:/home/appuser
    ports:
      - "3839:3838"
    user: "${MICROHAPLOT_UID:-1000}:${MICROHAPLOT_GID:-1000}"
```

**Volume partagé :** un seul chemin hôte (`MICROHAPLOT_DATA_DIR`, défaut
`./microhaplot-data` relatif à l'endroit où `docker-compose.yml` est
lancé) monté au même point (`/home/appuser`) dans les deux services — c'est
le point de montage qui EST le `$HOME` du conteneur (voir [Conception du
Dockerfile](11-dockerfile-design.md)), donc `~/Shiny/microhaplot` résout
au même dossier physique des deux côtés sans configuration
supplémentaire. Toutes les variables sont surchargeables via un fichier
`.env` à côté du `docker-compose.yml` (voir [Documentation
utilisateur](14-user-documentation.md) pour la doc destinée à
l'utilisateur final).

**Ports :** port interne toujours `3838` (défaut Shiny) des deux côtés ;
côté hôte, `main` sur `3838` et `prep` sur `3839` pour éviter toute
collision entre les deux services sur la même machine. Choix documentés
mais reconfigurables si l'utilisateur a déjà un service sur ces ports.

**UID/GID :** `MICROHAPLOT_UID`/`MICROHAPLOT_GID` (défaut `1000:1000`,
l'UID standard du premier utilisateur sur la plupart des distributions
Linux et compatible avec le comportement de partage de fichiers de Docker
Desktop pour Mac) pour que le conteneur non-root (`appuser`, voir
[Conception du Dockerfile](11-dockerfile-design.md)) puisse écrire dans le
dossier hôte monté sans problème de permissions. À documenter comme
ajustable pour les utilisateurs Linux dont l'UID diffère (`id -u`/`id -g`).

**Pas de `depends_on` entre les deux services — confirmé.** Le service
`main` sait s'auto-amorcer si le volume est vierge (l'entrypoint appelle
`mvShinyHaplot()` si `~/Shiny/microhaplot` n'existe pas encore, voir
[Conception du Dockerfile](11-dockerfile-design.md)) ; les deux services
peuvent démarrer dans n'importe quel ordre, y compris `main` seul sans que
`prep` ait jamais tourné.

**Pas de `restart:` (politique par défaut, `no`).** Usage local
mono-utilisateur démarré explicitement via une commande terminal (voir
[UX de lancement](04-launch-ux.md)) — un redémarrage automatique surprise
au lancement de Docker Desktop serait un comportement inattendu pour ce
public, pas un service qu'on veut voir tourner en permanence en arrière-plan.
