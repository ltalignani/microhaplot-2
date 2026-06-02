# #2 — Foundation : Docker + K8s manifests + CI/CD ArgoCD

## What to build

Set up the complete project scaffold for deploying microhaplot2 on SKAT3. This is the foundation all other slices depend on.

End-to-end: a push to `main` triggers GitHub Actions, builds a Docker image, pushes it to GHCR, and ArgoCD automatically deploys it to the `tools` namespace on the K3s cluster at `https://skat3.ird.fr/microhaplot2/`.

Key elements:
- **Dockerfile** based on `rocker/shiny` R 4.4.x. Installs Rsamtools, VariantAnnotation, BiocParallel (via `BiocManager::install()`), bslib, shinyWidgets, DT, dplyr, ggplot2, tidyr, ggiraph. Direct installation, no renv. Container listens on port 3838.
- **GitHub Actions** workflow: build and push image to `ghcr.io/ltalignani/microhaplot-2` on push to `main`.
- **K8s manifests** in `k8s/`: Deployment (image from GHCR), Service (ClusterIP port 3838), IngressRoute Traefik with path-prefix `/microhaplot2/` and strip-prefix middleware, Namespace `tools`.
- **Resource limits**: request 1 CPU / 2Gi RAM, limit 4 CPU / 8Gi RAM.
- **ArgoCD Application** manifest in the SKAT3 hub repo (`templates/infrastructure/argocd/apps/`) pointing to `k8s/` in this repo.
- The app at this stage shows a minimal placeholder UI to confirm the full deploy chain works end-to-end.

## Acceptance criteria

- [ ] `docker build` completes successfully locally
- [ ] GitHub Actions builds and pushes image to GHCR on push to `main`
- [ ] ArgoCD shows the app as Synced and Healthy in the `tools` namespace
- [ ] `https://skat3.ird.fr/microhaplot2/` returns a Shiny page (placeholder UI)
- [ ] Traefik strip-prefix middleware strips `/microhaplot2` before forwarding to the container
- [ ] Pod does not exceed memory limits under idle conditions

## Blocked by

None — can start immediately.
