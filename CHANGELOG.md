# CHANGELOG

All notable changes to this project will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [2.0.0] — 2026-06-02

Complete rewrite as a shared server-side Shiny application deployed on
SKAT3/K3s infrastructure at IRD. Backward-incompatible with v1.x.

### Added

- **Rsamtools extraction engine** — pure-R BAM→haplotype pipeline replaces
  the Perl `hapture.pl` script; reads indexed BAM files directly, no Perl
  installation required (issue #3).
- **VCF-driven locus definition** — SNP positions are now read from a standard
  VCF file; indels are automatically excluded, matching legacy hapture behaviour.
- **Modular Shiny architecture** — application split into independent Shiny
  modules: `dataInputModule`, `summaryModule`, `filterAnnotationModule`,
  `outputModule`, `inferentialModule`.
- **Data Input tab** — CSV metadata upload (bam_file / individual_id / group),
  VCF upload, server-side BAM path resolution, per-BAM progress bar (issue #4).
- **Summary tab** — interactive visualisations by locus, individual and group:
  read depth, allele balance ratios, callable fraction (issue #5).
- **Filter & Annotation tab** — per-locus filter controls (min read depth,
  min allelic ratio, max allele count), Accept/Reject status, free-text
  comments (issue #6).
- **Output tab** — CSV download of raw haplotype table and filtered diplotype
  summary; field selector controls exported columns (issue #7).
- **HWE & Shannon entropy metrics** — Hardy-Weinberg equilibrium diplotype
  frequencies and Shannon entropy computed per locus (issue #8).
- **Inferential Analysis tab** — placeholder for future Bayesian haplotype
  phasing (Gibbs sampler); clearly marked as under development (issue #9).
- **Server deployment stack** — Dockerfile (rocker/shiny base), Kubernetes
  manifests (Deployment, Service, IngressRoute for Traefik), GitHub Actions
  CI/CD pipeline pushing images to GHCR, ArgoCD Application manifest for
  GitOps delivery on SKAT3 (issue #2).
- **bslib / shinyWidgets UI** — modern Bootstrap 5 theme via bslib 0.7+,
  replacing legacy Bootstrap 3 Shiny default.
- **Pure-function layer** — business logic extracted into standalone R files
  (`input_validation.R`, `filter_annotation.R`, `summary_stats.R`,
  `output_utils.R`, `hwe_entropy.R`) for unit-testability independent of Shiny.
- **testthat test suite** — automated unit tests for pure functions.
- **Sticky session support** — Traefik IngressRoute configured with
  `RSHINY_SESSION` cookie for session affinity in multi-replica deployments.

### Changed

- **Deployment model** — from an R package installed locally by each user to
  a shared web service accessible at `https://skat3.ird.fr/microhaplot2/`
  with no local installation required.
- **Input format** — SAM/BAM files must now be **indexed** (`.bam` + `.bai`);
  raw SAM input is no longer supported.
- **Locus definition** — replaces the per-locus `hapture` label files with a
  single standard VCF file.
- **Metadata format** — CSV with columns `bam_file`, `individual_id`, `group`
  replaces the previous R-object–based sample description.
- **Package version** bumped to `2.0.0`; `Authors@R` updated to add
  Loïc Talignani (IRD) as co-author and maintainer.
- **R requirement** raised to R ≥ 4.4.0 (was R ≥ 3.5.0 in v1).
- **Dependencies** — Rsamtools, VariantAnnotation, BiocParallel added;
  `shiny`, `ggplot2`, `dplyr`, `DT` updated to current minimum versions.

### Removed

- **Perl dependency** — `hapture.pl` SAM-parsing script removed entirely.
- **`prepHaplotFiles()`** — no longer needed; BAM extraction is done
  server-side inside the Shiny session.
- **`runShinyHaplot()` / `mvShinyHaplot()`** — replaced by the K8s/Docker
  deployment model.
- **`n.jobs` parallelism parameter** — parallel extraction is now handled via
  BiocParallel inside the server process.
- **pkgdown site** — documentation website workflow removed (not applicable
  to a server app).
- **CRAN-compatibility constraints** — package is no longer intended for
  CRAN submission.

---

## [1.0.2] — 2020

*Upstream release by Thomas Ng (ngthomas/microhaplot). No changes made by IRD.*

- CRAN compliance fixes (donttest, @return Roxygen tags, replaced print/cat
  with message/warning).

## [1.0.1] — 2019

*Upstream release by Thomas Ng.*

- Upgraded to CRAN-compliance version.

## [1.0.0] — 2019

*Original release by Thomas Ng.*

- `prepHaplotFiles()` — parallel SAM file processing via Perl `hapture.pl`.
- `runShinyHaplot()` — launches the local Shiny visualization app.
- `mvShinyHaplot()` — copies the Shiny app directory to a user-specified location.
- `n.jobs` parameter for non-Windows parallel SAM processing.

---

[2.0.0]: https://github.com/ltalignani/microhaplot-2/compare/v1.0.2...loic-dev
[1.0.2]: https://github.com/ngthomas/microhaplot/releases/tag/v1.0.2
[1.0.1]: https://github.com/ngthomas/microhaplot/releases/tag/v1.0.1
[1.0.0]: https://github.com/ngthomas/microhaplot/releases/tag/v1.0.0
