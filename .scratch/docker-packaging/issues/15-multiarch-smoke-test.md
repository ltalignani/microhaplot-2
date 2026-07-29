---
status: closed
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

## Resolution — hors périmètre de cette carte

Ce ticket demande une **vérification**, pas une décision : il faudrait
écrire le Dockerfile et le docker-compose.yml réels (à partir des
décisions déjà prises dans [Conception du
Dockerfile](11-dockerfile-design.md) et [Conception du
docker-compose](12-compose-design.md)) et les faire tourner pour de vrai.
Rien à trancher ici que la planification puisse résoudre — c'est du
travail d'implémentation, pas du wayfinding.

**Ne se ferme pas sans suite :** son contenu (build multi-arch réussi,
`docker compose up` fonctionnel, extraction réelle côté `prep`, `.rds`
visible côté `main` sans redémarrage, compatibilité Apple Silicon) devient
les **critères d'acceptation** du ticket qui implémentera concrètement le
Dockerfile/docker-compose lors du passage `/to-spec` → `/to-tickets` →
`/implement` — à ne pas perdre en route, juste déplacé de la phase
planification vers la phase d'exécution.
