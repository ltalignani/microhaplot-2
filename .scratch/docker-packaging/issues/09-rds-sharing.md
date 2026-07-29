---
status: closed
type: wayfinder:grilling
---

## Question

L'app principale microhaplot (`runShinyHaplot`) charge ses .rds depuis un
dossier fixe (établi par `mvShinyHaplot`, ex: `~/Shiny/microhaplot`).
Comment le conteneur "prep" doit-il rendre ses .rds générés visibles au
conteneur "main" ?

## Resolution

**Le même volume monté sert de `app.path` pour les deux conteneurs.** Le
dossier de données partagé (voir [Transfert de fichiers
utilisateur](03-data-transfer.md)) EST directement le dossier
`~/Shiny/microhaplot` à l'intérieur des deux conteneurs — le wizard prep y
écrit ses .rds, l'app principale les voit apparaître immédiatement, sans
copie ni redémarrage.
