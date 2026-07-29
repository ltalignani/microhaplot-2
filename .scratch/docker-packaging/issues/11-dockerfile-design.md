---
status: closed
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

**Image de base : `rocker/r-ver:4.5.0`.** Image officielle du Rocker
Project, Debian (bookworm), multi-arch (amd64+arm64) déjà publiée — cohérent
avec [Priorité plateformes cible](08-platform-priority.md) sans travail de
build supplémentaire, et sans les couches Shiny Server de `rocker/shiny`
(voir [Approche serveur Shiny](10-shiny-server-approach.md)). Version R
pinée à 4.5.0, cohérente avec `Depends: R (>= 3.5.0)` de `DESCRIPTION` et
avec la version locale déjà utilisée par le mainteneur (4.5-arm64).

**Dépendances système (apt) :** `perl` (>5.014 déjà satisfait par Debian
bookworm), `samtools` (support BAM), `build-essential` + `gfortran` (compilation
des packages R avec code compilé : `pcadapt`, dépendances de `RSpectra`),
plus les libs de dev requises par la chaîne graphique de `ggiraph`
(`libcairo2-dev`, `libfreetype6-dev`, `libfontconfig1-dev`, `libpng-dev`,
`libtiff5-dev`, `libjpeg-dev`) et le réseau/XML (`libcurl4-openssl-dev`,
`libssl-dev`, `libxml2-dev`, `zlib1g-dev`).

**Installation du package :** `COPY . /pkg` (le Dockerfile vit dans ce
repo et se construit depuis son propre contenu, pas de dépendance à un
`devtools::install_github` réseau à cette étape) puis installation des
dépendances CRAN listées dans `DESCRIPTION` (`remotes::install_deps()`) et
`R CMD INSTALL /pkg`.

**Découverte clé — pas de nouveau mécanisme de partage à construire : le
chemin `~/Shiny/microhaplot` déjà codé en dur dans
`inst/shiny/microhaplot-prep/server.R` (ligne 81-82, via
`path.expand("~/Shiny")`) fait tout le travail.** Il suffit que les deux
conteneurs tournent avec le même `$HOME`, monté sur le volume partagé (voir
[Partage des .rds entre les deux conteneurs](09-rds-sharing.md)), pour que
`~/Shiny/microhaplot` résolve exactement au même dossier physique dans les
deux conteneurs — sans variable d'environnement custom, sans changement de
code. Utilisateur non-root dédié dans l'image (ex: `appuser`), dont
`$HOME` est fixé au point de montage du volume (ex: `/home/appuser`).

Autre point vérifié : `mvShinyHaplot(path)` fait un
`file.copy(app.dir, path, overwrite = TRUE, recursive = TRUE)` — copie
récursive qui **écrase** les fichiers de code de l'app (ui.R/server.R,
fish1.rds/fish2.rds fournis) mais ne supprime jamais les fichiers déjà
présents dans le dossier cible qui n'existent pas dans la source. Rejouer
`mvShinyHaplot()` à chaque démarrage de conteneur est donc **sûr et
idempotent** : les .rds produits par l'utilisateur ne sont jamais effacés,
et le code de l'app reste toujours synchronisé avec la version du package
installée dans l'image.

**Point d'entrée unique, paramétré par une variable d'environnement
`MICROHAPLOT_APP` (`main` ou `prep`) :**

```sh
#!/usr/bin/env bash
set -e
export HOME=/home/appuser  # = point de montage du volume partagé

case "$MICROHAPLOT_APP" in
  main)
    exec Rscript -e '
      options(shiny.host = "0.0.0.0", shiny.port = 3838)
      shiny_dir <- path.expand("~/Shiny")
      app_path  <- file.path(shiny_dir, "microhaplot")
      if (!dir.exists(app_path)) microhaplot::mvShinyHaplot(shiny_dir)
      microhaplot::runShinyHaplot(app_path)
    '
    ;;
  prep)
    exec Rscript -e '
      options(shiny.host = "0.0.0.0", shiny.port = 3838)
      microhaplot::runShinyHaplotPrep()
    '
    ;;
  *)
    echo "MICROHAPLOT_APP must be 'main' or 'prep'" >&2
    exit 1
    ;;
esac
```

Le conteneur `prep` n'a pas besoin du bloc `if (!dir.exists(...))
mvShinyHaplot(...)` explicite : cette logique existe déjà à l'intérieur de
`runShinyHaplotPrep()`'s `server.R` (voir ligne 81-83), déclenchée
paresseusement à la première extraction. Le conteneur `main`, lui,
n'a pas cette logique dans `runShinyHaplot()` — d'où le besoin de l'ajouter
explicitement dans l'entrypoint, pour que le tout premier lancement (volume
vierge, avant toute extraction côté `prep`) trouve un dossier d'app déjà
peuplé (code + jeux de données d'exemple fish1/fish2) plutôt que d'échouer
avec "Could not find Shiny directory".

**Port interne unique : `3838`** (port par défaut Shiny) dans les deux cas
— c'est le mapping docker-compose côté hôte qui distingue les deux
services (voir [Conception du docker-compose](12-compose-design.md)), pas
le port interne.

**Multi-arch :** construit via `docker buildx build --platform
linux/amd64,linux/arm64` (voir [Conception du workflow CI de
publication](13-ci-publish-workflow.md) pour l'automatisation) ;
`rocker/r-ver` publie déjà les deux architectures, donc aucun changement
supplémentaire requis côté image de base.
