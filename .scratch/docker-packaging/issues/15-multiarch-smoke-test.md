---
status: open
type: wayfinder:task
blocked_by: ["11-dockerfile-design.md", "12-compose-design.md"]
---

## Question

Vérifier de bout en bout que l'image construite fonctionne réellement :

- Build multi-arch (amd64 + arm64) réussit sans erreur.
- `docker-compose up` démarre les deux services correctement.
- Le conteneur `prep` peut effectivement exécuter une extraction
  (`prepHaplotFiles`) sur un jeu de données d'exemple (BAM + VCF), samtools
  et Perl étant bien présents et fonctionnels dans l'image.
- Le .rds produit apparaît bien et est chargeable côté conteneur `main`
  via le volume partagé (voir [Partage des .rds entre les deux
  conteneurs](09-rds-sharing.md)), sans redémarrage.
- Sur Apple Silicon (arm64) en particulier, confirmer qu'aucune dépendance
  (samtools, packages R compilés) ne pose de problème de compatibilité.

## Resolution

_à compléter à la résolution de ce ticket_
