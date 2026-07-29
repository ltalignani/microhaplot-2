# PRD: Docker packaging for microhaplot + prepHaplotFiles

Source: [docker-packaging wayfinder map](map.md) — all decisions below were
made during that wayfinding effort; see the linked tickets for the full
reasoning behind each one.

## Problem Statement

microhaplot's two Shiny apps — the main visualization/genotype-calling app
(`runShinyHaplot`) and the field genotyping prep wizard
(`runShinyHaplotPrep`) — currently require a non-bioinformatician user to
install R, the `microhaplot` package and its dependencies, Perl, and
`samtools` (for BAM support) directly on their own machine. This is a real
barrier for the target audience of the prep wizard in particular: field
technicians and lab staff who are not comfortable installing or
troubleshooting a scientific computing stack, and who currently need
hands-on help (or a pre-configured machine) just to get started. BAM
support is also explicitly unavailable on Windows today, which excludes
part of this audience outright.

## Solution

Package both apps into a single Docker image, orchestrated by a
`docker-compose.yml` that a user can download without cloning the repo.
Once Docker Desktop is installed, the user runs one command to start both
apps, drops their input files into one shared local folder, and gets their
output back from that same folder — no R, Perl, or samtools installation,
no R console interaction at all. The image is built and published
automatically by CI, so no local build step is required either.

As a side effect of running inside a Linux container regardless of host
OS, the existing "BAM not supported on Windows" restriction no longer
applies when the apps are run this way — a real capability gain for
Windows users, achieved without any code change.

## User Stories

1. As a field technician with no R experience, I want to install one
   piece of software (Docker Desktop) and run one command, so that I can
   start using microhaplot without learning R or a package manager.
2. As a field technician, I want to drop my BAM/VCF/TSV files into a
   single folder I already know about, so that I don't need to understand
   Docker volumes or container filesystems to get my data in.
3. As a field technician, I want the `.rds` files produced by the prep
   wizard to show up automatically in the main app, so that I don't have
   to manually copy files between tools.
4. As a Windows user, I want BAM file support to work the same way it does
   for Mac/Linux users, so that my OS choice doesn't limit which input
   formats I can use.
5. As a returning user, I want to stop and restart the apps without losing
   any of my previously extracted `.rds` files, so that my accumulated
   work is safe across sessions.
6. As a user running the apps for the first time on a fresh machine, I
   want the main app to work even if I've never run the prep wizard yet,
   so that pre-existing `.rds` files (or ones I add manually) are usable
   immediately.
7. As a lab manager onboarding a new field technician, I want to hand them
   a single `docker-compose.yml` file and a link to the documentation, so
   that I don't have to walk them through an R installation myself.
8. As the maintainer, I want a new image published automatically whenever
   I tag a release, so that a bugfix (like the recent pcadapt "Can't
   compute SVD" fix) reaches Docker users without a manual publishing
   step I might forget.
9. As the maintainer, I want the CI workflow to smoke-test the image
   before publishing it, so that a broken image is never pushed to the
   registry for users to discover first.
10. As a Mac (Intel or Apple Silicon) or Linux user, I want a working image
    for my architecture without needing to build anything myself, so that
    "pull and run" is genuinely all that's required.
11. As a user on a machine where ports 3838/3839 are already taken by
    another local service, I want to be able to reconfigure the ports
    microhaplot uses, so that I'm not blocked by a collision I didn't
    cause.
12. As a Linux user whose UID doesn't match the container's default, I
    want to be able to override it, so that the shared volume remains
    writable without resorting to `sudo` or loosening file permissions
    system-wide.
13. As a user reading the documentation, I want the Docker path presented
    as the recommended option for non-bioinformaticians, with the existing
    manual R installation still documented for those who prefer it, so
    that both audiences are served without either path feeling like an
    afterthought.
14. As a user who hits a problem, I want the existing Troubleshooting
    section extended to cover Docker-specific issues (e.g. permission
    errors on the shared volume), so that I have one place to look
    regardless of which installation path I took.

## Implementation Decisions

- **Scope:** both `runShinyHaplot()` (main app) and `runShinyHaplotPrep()`
  (prep wizard) are containerized. No changes to either app's R code, UI,
  or server logic — this is packaging only.

- **Single image, two docker-compose services.** One Dockerfile builds one
  image; `docker-compose.yml` runs it twice as separate services (`main`
  and `prep`) differentiated by an environment variable,
  `MICROHAPLOT_APP` (`main` or `prep`), read by the image's entrypoint
  script to decide which `Rscript` invocation to run.

- **Base image: `rocker/r-ver:4.5.0`.** Debian-based, official multi-arch
  (amd64 + arm64) R image from the Rocker Project. No Shiny Server: each
  service runs `shiny::runApp()` directly via
  `options(shiny.host = "0.0.0.0", shiny.port = 3838)`, matching how the
  apps already run locally today, just bound to all interfaces so the host
  can reach them.

- **System dependencies installed via apt:** `perl`, `samtools` (BAM
  support), `build-essential` + `gfortran` (compiling `pcadapt`/`RSpectra`),
  and the graphics/network dev libraries `ggiraph`'s dependency chain
  needs (`libcairo2-dev`, `libfreetype6-dev`, `libfontconfig1-dev`,
  `libpng-dev`, `libtiff5-dev`, `libjpeg-dev`, `libcurl4-openssl-dev`,
  `libssl-dev`, `libxml2-dev`, `zlib1g-dev`).

- **Package installed from repo source at image build time** (not
  `devtools::install_github` at runtime) — the Dockerfile lives in this
  repo and builds from its own checked-out content, with R package
  dependencies from `DESCRIPTION` installed via `remotes::install_deps()`.

- **Data sharing mechanism — the key architectural finding of this
  effort:** `inst/shiny/microhaplot-prep/server.R` already hardcodes
  `~/Shiny/microhaplot` (via `path.expand("~/Shiny")`) as the prep
  wizard's extraction target. No new sharing mechanism needs to be built:
  running both containers with the same `$HOME`, bind-mounted to the
  user's shared data folder, makes `~/Shiny/microhaplot` resolve to the
  identical physical location in both containers automatically. The
  container runs as a non-root user (`appuser`) whose home directory *is*
  the volume mount point.

- **`mvShinyHaplot()` is safe to call idempotently on every container
  start.** It performs `file.copy(app.dir, path, overwrite = TRUE,
  recursive = TRUE)`, which overwrites the app's own bundled files
  (`ui.R`/`server.R`/the bundled `fish1.rds`/`fish2.rds` example datasets)
  but never deletes files already present in the target that aren't part
  of the source — so a user's previously extracted `.rds` files are never
  at risk from this call.

- **Entrypoint behavior differs slightly between the two services:** the
  `main` service's entrypoint must check whether `~/Shiny/microhaplot`
  exists and call `mvShinyHaplot()` if not, before calling
  `runShinyHaplot()` — otherwise a fresh, empty volume (before any
  extraction has ever run) would make `runShinyHaplot()` fail immediately
  with "Could not find Shiny directory". The `prep` service needs no
  equivalent logic in its entrypoint: this exact check already exists
  inside `runShinyHaplotPrep()`'s own server code, triggered lazily on the
  first extraction.

- **No `depends_on` between the two compose services** — per the point
  above, `main` can start standalone on a fresh volume without `prep` ever
  having run.

- **No automatic `restart:` policy** — usage is a manually-started local
  tool (`docker compose up` / `docker compose down`), not a
  long-running background service; an unexpected restart on Docker
  Desktop startup would surprise this audience rather than help it.

- **Ports:** both services listen on `3838` internally; docker-compose
  maps `main` to host port `3838` and `prep` to host port `3839`, both
  overridable.

- **Volume path and UID/GID are environment-variable overridable** (with
  sensible defaults — `./microhaplot-data` for the data folder, `1000:1000`
  for UID/GID) via a `.env` file alongside `docker-compose.yml`, covering
  the Linux permission-matching case without complicating the default Mac
  experience.

- **Distribution: pre-built image on GitHub Container Registry**
  (`ghcr.io/ltalignani/microhaplot-2`), multi-arch (amd64 + arm64). Users
  only need `docker-compose.yml` (downloadable directly, e.g. via `curl`)
  and Docker Desktop — no git clone, no local build, no compiler toolchain
  on the user's machine.

- **CI publish workflow**, triggered on `v*` git tags (matching the
  existing `DESCRIPTION` version/release cadence):
  1. A `build-and-smoke-test` job builds a single-arch image (`load:
     true`) and runs it via `docker compose up`, verifying both services
     respond.
  2. A `publish` job, gated on the first job succeeding (`needs:`),
     rebuilds multi-arch (`linux/amd64,linux/arm64`) and pushes to
     `ghcr.io`, tagged with both the git tag value (e.g. `v1.0.3`) and
     `latest`.
  3. Authentication uses the automatically-provided `GITHUB_TOKEN` with
     `packages: write` permission — no manually provisioned secret.

- **Windows/BAM restriction is lifted mechanically, with no code
  change.** `prepHaplotFiles()`'s existing Windows check tests
  `.Platform$OS.type` of the process actually running the code. Inside a
  Linux container this is always `"unix"`, regardless of the host OS
  (including Windows via Docker Desktop/WSL2) — so the restriction simply
  never triggers under Docker. This only needs to be documented, not
  implemented.

- **README documentation:** a new section, "Run microhaplot with Docker
  (recommended for non-bioinformaticians)", placed before the existing
  "Field Genotyping Prep app" section, presenting Docker as the
  recommended path while keeping the manual R installation instructions
  available below it for bioinformaticians who prefer that route. Content
  covers: Docker Desktop prerequisite, downloading `docker-compose.yml`
  without cloning the repo, creating the shared data folder, the
  `docker compose up`/`down` commands, and an explicit note on the
  Windows/BAM capability gain under Docker. UID/GID and `.env` overrides
  are deliberately left out of the main quickstart and covered in the
  existing Troubleshooting section instead, to avoid front-loading detail
  most Mac users will never need.

## Testing Decisions

- **A single test seam: an end-to-end Docker smoke test**, not testthat
  unit tests — this effort changes no R logic (confirmed during
  wayfinding: `runShinyHaplot()`, `runShinyHaplotPrep()`,
  `mvShinyHaplot()`, and `prepHaplotFiles()` are all reused unmodified),
  so the meaningful behavior to verify is the packaging itself, from the
  user's point of view.
- The smoke test is what the CI publish workflow's
  `build-and-smoke-test` job runs before any image is published (see
  Implementation Decisions above), and should also be runnable locally by
  the maintainer during development of the Dockerfile/compose file.
- What the smoke test must verify, end to end:
  1. The image builds successfully.
  2. `docker compose up` starts both services without error.
  3. Both the `main` and `prep` services respond on their respective
     ports.
  4. Running an extraction through the `prep` service against a sample
     BAM+VCF dataset (the package's existing bundled example data, e.g.
     the `sebastes` extdata used elsewhere in this package's own test
     suite) succeeds — confirming `samtools` and Perl are present and
     functional inside the image.
  5. The resulting `.rds` file is visible and loadable from the `main`
     service through the shared volume, without restarting any container.
  6. On Apple Silicon (arm64) specifically, no dependency (samtools,
     compiled R packages) fails to build or run.
- No unit-test-level verification of individual Dockerfile steps
  (presence of `samtools`, `$HOME` resolution in isolation, etc.) — the
  end-to-end smoke test is the single, highest seam, per the "fewer seams
  across the codebase, the better" guidance; those lower-level failures
  would surface as smoke-test failures anyway, with clear enough logs to
  diagnose.

## Out of Scope

- Cloud or Kubernetes deployment — this is strictly a local, single-user,
  single-machine Docker packaging effort. Consistent with the earlier,
  separate decision to remove Docker/k8s deployment vestiges from the
  `microhaplot2` (bslib rewrite) repo.
- Authentication or multi-user access control — no such layer is planned;
  usage is assumed to be one user on their own machine.
- Any change to the business logic of `prepHaplotFiles()`, the Population
  Genetics modules, or any other app functionality — this spec is
  packaging and deployment only.
- Guaranteed/tested Windows support. The image will very likely also work
  on Windows via Docker Desktop + WSL2 (see the Windows/BAM decision
  above), but this milestone targets and tests Mac (Intel + Apple Silicon)
  and Linux only.
- A double-clickable launcher script per OS to avoid the terminal
  entirely — the launch UX for this milestone is a single terminal
  command (`docker compose up`).
- Building the actual Dockerfile, docker-compose.yml, and CI workflow
  files, and running the real end-to-end verification described in
  Testing Decisions above — those are implementation work for the
  `/to-tickets` → `/implement` cycle that follows this spec, not something
  resolved by this planning effort itself.

## Further Notes

- This repo (`/Users/loictalignani/microhaplot`) is microhaplot **v1**
  (the classic shinyBS/Bootstrap 3 app, fork `ltalignani/microhaplot-2` on
  GitHub) — distinct from `microhaplot2`, the bslib-based rewrite, which
  had its own Docker/k8s vestiges intentionally removed earlier. The two
  are unrelated efforts on different products; this spec does not
  reintroduce what was removed there.
- Full decision history and reasoning for every point above lives in the
  [docker-packaging wayfinder map](map.md) and its linked tickets — useful
  context if any decision here needs revisiting during implementation.
- The recent pcadapt "Can't compute SVD" bugfix (already committed to this
  repo) is a good concrete example of why the automated CI publish
  workflow matters: without it, a Docker image could silently lag behind
  bugfixes already released in the R package itself.
