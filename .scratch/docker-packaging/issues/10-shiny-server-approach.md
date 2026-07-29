---
status: closed
type: wayfinder:grilling
---

## Question

Comment le serveur Shiny doit-il tourner à l'intérieur des conteneurs :
`shiny::runApp()` direct, ou un vrai Shiny Server (ex: image
`rocker/shiny`) ?

## Resolution

**R + `shiny::runApp()` directement, sans Shiny Server.** Chaque conteneur
lance `Rscript -e 'microhaplot::runShinyHaplot(...)'` /
`runShinyHaplotPrep()` avec `host = "0.0.0.0"` — image plus légère, même
mécanisme que l'usage actuel en local, pas de configuration Shiny Server à
maintenir. Usage local mono-utilisateur, pas besoin de la gestion
multi-session d'un vrai serveur applicatif.
