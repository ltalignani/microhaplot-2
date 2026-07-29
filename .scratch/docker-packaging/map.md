---
label: wayfinder:map
---

## Destination

Un spec (PRD) prêt à passer par `/to-spec` → `/to-tickets` → `/implement`,
décrivant comment empaqueter l'app microhaplot et son compagnon
`prepHaplotFiles` (le wizard `runShinyHaplotPrep`) dans Docker, pour les
rendre facilement installables et utilisables par un utilisateur non
bioinformaticien.

## Notes

- Repo : `/Users/loictalignani/microhaplot` (v1, fork `ltalignani/microhaplot-2`
  sur GitHub — distinct de la réécriture bslib `microhaplot2`).
- Convention locale de ce repo pour les efforts wayfinder :
  `.scratch/<effort>/map.md` + `.scratch/<effort>/issues/NN-*.md`, comme pour
  `bam-input-prephaplotfiles`, `field-prep-app`, `popgen-v1-port`.
- Rappel important : le repo `microhaplot2` (la réécriture bslib) avait
  justement eu ses vestiges Docker/k8s **supprimés** plus tôt dans ce fil de
  travail (dossier `k8s/`, `Dockerfile`, workflow
  `docker-build-push.yml`) — décision distincte, sur un autre repo/produit ;
  ne pas confondre les deux efforts. Ce nouvel effort Docker vise
  spécifiquement microhaplot **v1** et son wizard de préparation.
- Après grilling initial, la quasi-totalité de l'architecture est déjà
  tranchée (voir Decisions so far) — les tickets ouverts restants sont des
  tickets de type `task`, pas de nouvelles décisions de conception.
- Skills à invoquer en aval une fois la carte close : `/to-spec`, puis
  `/to-tickets`, puis `/implement`.

## Decisions so far

- [Périmètre : quelles apps dockeriser](issues/01-scope-which-apps.md) — les deux (main + prep).
- [Topologie des conteneurs](issues/02-container-topology.md) — une image, deux services docker-compose.
- [Transfert de fichiers utilisateur](issues/03-data-transfer.md) — un dossier local monté en volume.
- [UX de lancement](issues/04-launch-ux.md) — une commande terminal unique (`docker-compose up`).
- [Distribution de l'image](issues/05-distribution.md) — image publiée sur ghcr.io, pull direct, pas de build local.
- [Windows/BAM sous Docker](issues/06-windows-bam-restriction.md) — restriction levée mécaniquement, aucun changement de code requis.
- [Automatisation CI de publication](issues/07-ci-publish-automation.md) — GitHub Actions build+push automatisé.
- [Priorité plateformes cible](issues/08-platform-priority.md) — Mac (Intel+ARM) et Linux d'abord, multi-arch amd64+arm64.
- [Partage des .rds entre les deux conteneurs](issues/09-rds-sharing.md) — le volume partagé EST le `app.path` des deux conteneurs.
- [Approche serveur Shiny](issues/10-shiny-server-approach.md) — `shiny::runApp()` nu, pas de Shiny Server.

## Not yet specified

- Support Windows/WSL2 testé et garanti (déféré, pas exclu — voir issue #08).
- Éventuel script wrapper par OS (double-clic) pour masquer le terminal à
  l'utilisateur, si le retour utilisateur montre que la commande terminal
  seule reste un frein (voir issue #04 — non retenu pour ce premier jalon).
- Stratégie de mise à jour de l'image pour un utilisateur existant (comment
  il sait qu'une nouvelle version est disponible, comment il la récupère) —
  pas encore posé.

## Out of scope

- Déploiement cloud/Kubernetes — cohérent avec la suppression récente des
  vestiges k8s/Docker sur le repo `microhaplot2` ; cet effort vise un usage
  Docker **local**, poste par poste, pas un déploiement serveur partagé.
- Authentification / gestion multi-utilisateurs — usage local
  mono-utilisateur supposé, pas de couche d'authentification prévue.
- Modification de la logique métier de `prepHaplotFiles()` ou des modules
  Population Genetics — cet effort est strictement du packaging/déploiement,
  pas une évolution fonctionnelle des apps elles-mêmes.
