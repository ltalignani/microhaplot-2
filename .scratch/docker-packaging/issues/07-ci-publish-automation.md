---
status: closed
type: wayfinder:grilling
---

## Question

Faut-il automatiser la publication de l'image (GitHub Actions build+push
vers ghcr.io à chaque release/tag), ou le mainteneur publie-t-il
manuellement quand nécessaire ?

## Resolution

**Automatiser via GitHub Actions.** Un workflow build+push sur tag/release
évite d'oublier de republier l'image après un bugfix (comme celui du crash
pcadapt récemment corrigé) — la logique métier et l'image Docker
resteraient sinon désynchronisées silencieusement.
