---
status: closed
type: wayfinder:task
blocked_by: ["11-dockerfile-design.md"]
---

## Question

Concevoir le workflow GitHub Actions de build + publication (voir
[Automatisation CI de publication](07-ci-publish-automation.md)) :

- Déclencheur : sur quel évènement (tag `v*`, release GitHub, push sur
  `master` avec changement du Dockerfile/DESCRIPTION, ou combinaison) ?
- Stratégie de tag d'image : suivre `Version:` de `DESCRIPTION`, `latest`,
  ou les deux ?
- Build multi-arch via `docker buildx` (amd64 + arm64, voir [Priorité
  plateformes cible](08-platform-priority.md)).
- Registre cible : `ghcr.io/ltalignani/microhaplot-2` (voir [Distribution
  de l'image](05-distribution.md)) — authentification via
  `GITHUB_TOKEN`/permissions du repo.
- Faut-il un smoke test dans le workflow avant publication (voir
  [Vérification build multi-arch et smoke test](15-multiarch-smoke-test.md))
  ?

## Resolution

**Déclencheur : un tag git `v*` poussé** (ex: `v1.0.3`), aligné sur le
cycle de release existant (le mainteneur tagge quand la version dans
`DESCRIPTION` est prête à publier). Pas de publication à chaque push sur
`master`, pas de déclenchement manuel requis pour l'usage courant.

**Stratégie de tag d'image : le tag git + `latest`.** L'image est publiée
sous deux tags à chaque run : la valeur exacte du tag git (ex:
`ghcr.io/ltalignani/microhaplot-2:v1.0.3`) et `latest` — conséquence
directe du déclencheur choisi, pas une décision séparée. Un utilisateur qui
suit la doc (`:latest` par défaut, voir [Conception du
docker-compose](12-compose-design.md)) reçoit toujours la dernière version
taggée ; un utilisateur qui veut figer une version précise peut cibler le
tag exact.

**Smoke test avant publication — confirmé.** Le workflow construit
l'image, lance `docker compose up` avec le `docker-compose.yml` du repo
(voir [Conception du docker-compose](12-compose-design.md)), vérifie que
les deux services répondent sur leurs ports respectifs, puis seulement
pousse vers `ghcr.io` si tout est vert. Détail de vérification approfondie
(extraction réelle sur un jeu de données d'exemple) délégué au ticket
[Vérification build multi-arch et smoke test](15-multiarch-smoke-test.md),
qui informera le contenu exact de ce job.

**Structure du workflow (`.github/workflows/docker-publish.yml`) :**

```yaml
on:
  push:
    tags: ["v*"]

permissions:
  contents: read
  packages: write

jobs:
  build-and-smoke-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-qemu-action@v3
      - uses: docker/setup-buildx-action@v3
      - name: Build image (load, single-arch, for smoke test)
        uses: docker/build-push-action@v6
        with:
          load: true
          tags: microhaplot-2:smoke-test
      - name: Smoke test via docker compose
        run: |
          IMAGE_TAG=smoke-test docker compose up -d
          # attend + vérifie que main (3838) et prep (3839) répondent
          docker compose down

  publish:
    needs: build-and-smoke-test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-qemu-action@v3
      - uses: docker/setup-buildx-action@v3
      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - uses: docker/build-push-action@v6
        with:
          platforms: linux/amd64,linux/arm64
          push: true
          tags: |
            ghcr.io/ltalignani/microhaplot-2:${{ github.ref_name }}
            ghcr.io/ltalignani/microhaplot-2:latest
```

**Authentification :** `GITHUB_TOKEN` généré automatiquement par GitHub
Actions (aucun secret à provisionner manuellement), avec la permission
`packages: write` déclarée dans le workflow — cohérent avec [Distribution
de l'image](05-distribution.md) (ghcr.io rattaché au repo
`ltalignani/microhaplot-2`).

**Deux jobs séparés** (`build-and-smoke-test` puis `publish`, ce dernier
dépendant du premier via `needs:`) plutôt qu'un seul : le job de smoke test
construit en single-arch (`load: true`, rapide, pour l'hôte du runner
uniquement) pour vérifier le comportement applicatif, tandis que le job de
publication reconstruit en multi-arch (`push: true`, pas de `load`,
buildx pousse directement chaque plateforme) — évite de payer le coût
d'un build multi-arch complet si le smoke test échoue.
