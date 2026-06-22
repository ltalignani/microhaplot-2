# microhaplot2

![microhaplot2 logo](man/figures/microhaplot-sticker.png)

Microhaplotype constructor and visualizer — modernised server edition.

**Live app** : <https://skat3.ird.fr/microhaplot2/>

> This repository is a fork of [ngthomas/microhaplot](https://github.com/ngthomas/microhaplot)
> (v1.0.2, 2020). The original package required a local R + Perl installation
> and processed SAM files. microhaplot2 is a rewrite designed to run as a
> shared Shiny server on the SKAT3 infrastructure at IRD, processing indexed
> BAM files via Rsamtools — no local installation required.

---

## What it does

microhaplot2 extracts and visualises microhaplotypes from short-read alignments.
You provide:

- **Indexed BAM files** (one per individual, `.bam` + `.bai`)
- **A VCF file** listing the SNP positions that define your microhaplotype loci
- **A CSV metadata file** mapping each BAM to an individual ID and a group label

The app extracts haplotype sequences at each locus using Rsamtools, computes
allele balance ratios, and lets you interactively filter, curate, and export
the results.

Typical use cases: amplicon sequencing panels, RADseq, WGS targeted at known loci.
The sebastes rockfish dataset (8 loci, 20 individuals) is included for testing.

---

## Using the web app

Go to <https://skat3.ird.fr/microhaplot2/> — no login required.

### 1. Prepare your metadata CSV

Three columns, tab- or comma-separated:

```csv
bam_file,individual_id,group
s6.bam,s6,copper
s11.bam,s11,copper
s13.bam,s13,gold
```

A blank template is downloadable from the app's **Data Input** tab.

### 2. Deposit your BAM files

Place your `.bam` and `.bai` files in the shared data directory on the server
(contact your SKAT3 administrator for access to `/data/lovelace/`).

> **Note** : large-file upload via browser is not supported. Files must be
> pre-deposited on the server's local storage volume.

### 3. Run the analysis

In the app:

1. **Data Input** tab → upload your CSV metadata and VCF file
2. Click **Run extraction** — a progress bar shows per-BAM progress
3. Explore results in **Summary**, **Filter & Annotation**, and **Output** tabs

### 4. Export results

- **Output** tab → download the raw haplotype table or the filtered diplotype
  summary as CSV
- Field selector controls which columns are included

---

## Tabs overview

| Tab | Description |
| --- | ----------- |
| **Data Input** | Upload CSV metadata, VCF, validate BAM paths, run extraction |
| **Summary** | Visualisations by locus, individual, and group (read depth, allele balance, callable fraction) |
| **Filter & Annotation** | Per-locus filtering thresholds (min read depth, min allelic ratio, n alleles), Accept/Reject status, free-text comments |
| **Output** | Download raw and filtered tables as CSV |
| **Inferential Analysis** | *En développement* — Bayesian haplotype phasing (Gibbs sampler), planned for v3 |

---

## Repository structure

```text
app/                        # Shiny application (modular)
├── app.R                   # Entry point
└── R/
    ├── extraction.R        # Rsamtools BAM → haplotype engine (pure R, no Perl)
    ├── dataInputModule.R   # CSV + VCF upload, BAM validation, progress bar
    ├── summaryModule.R     # Locus / individual / group visualisations
    ├── filterAnnotationModule.R  # Per-locus filters + annotations
    ├── outputModule.R      # CSV downloads
    ├── inferentialModule.R # Placeholder tab
    ├── input_validation.R  # Pure functions: CSV/VCF/BAM validation
    ├── filter_annotation.R # Pure functions: filtering logic
    ├── summary_stats.R     # Pure functions: summary computations
    ├── hwe_entropy.R       # Pure functions: HW frequencies + Shannon entropy
    └── output_utils.R      # Pure functions: table formatting
k8s/                        # Kubernetes manifests (SKAT3 / K3s)
├── namespace.yaml
├── deployment.yaml         # rocker/shiny image, resource limits 1CPU/2Gi→4CPU/8Gi
├── service.yaml
├── ingressroute.yaml       # Traefik path-prefix /microhaplot2/
└── argocd-app.yaml         # ArgoCD Application pointing to this k8s/ directory
tests/testthat/             # Unit tests (testthat)
├── fixtures/               # s6.bam, s6.bam.bai, sebastes.vcf (test data)
├── test-extraction.R
├── test-filter-annotation.R
├── test-input-validation.R
├── test-hwe-entropy.R
├── test-output-utils.R
└── test-summary-stats.R
Dockerfile                  # rocker/shiny:4.4.1 + Rsamtools + VariantAnnotation
.github/workflows/
└── docker-build-push.yml   # Build + push to ghcr.io on push to main
```

---

## Usage local (sans serveur)

microhaplot2 peut être lancé sur votre propre machine, sans passer par
`skat3.ird.fr`. Deux méthodes selon votre profil.

### Méthode A — Clone du repo (recommandé)

```bash
git clone https://github.com/ltalignani/microhaplot-2.git
cd microhaplot-2
```

```r
# Installer les dépendances (une seule fois)
source("install_deps.R")

# Lancer l'app
Sys.setenv(MICROHAPLOT_DATA_DIR = "/chemin/vers/mes/bam")
shiny::runApp("app/")
```

### Méthode B — Installation via devtools

```r
# Installer les dépendances (une seule fois)
source("install_deps.R")

# Installer le package
devtools::install_github("ltalignani/microhaplot-2")
```

---

## Development

### Prerequisites

- R ≥ 4.4

Install all dependencies at once using the provided script:

```r
source("install_deps.R")
```

Or run it from a terminal:

```bash
Rscript install_deps.R
```

This installs both CRAN packages (`shiny`, `bslib`, `shinyWidgets`, `DT`,
`dplyr`, `ggplot2`, `tidyr`, `ggiraph`, `here`) and Bioconductor packages
(`Rsamtools`, `VariantAnnotation`, `BiocParallel`).

> **Note**: install packages individually (not as part of the tidyverse
> meta-package) to avoid version conflicts with shared dependencies such
> as `rlang`.

### Run locally

```r
shiny::runApp("app/")
```

Set `MICROHAPLOT_DATA_DIR` to point to your local BAM directory
(default: `/data/lovelace`):

```r
Sys.setenv(MICROHAPLOT_DATA_DIR = "~/my-bam-files")
shiny::runApp("app/")
```

### Run tests

```r
devtools::test()
```

### Build and run the Docker image

```bash
docker build -t microhaplot2 .
docker run --rm -p 3838:3838 \
  -v /path/to/bam/files:/data/lovelace:ro \
  microhaplot2
# then open http://localhost:3838/microhaplot2/
```

---

## Deployment (SKAT3 / GitOps)

Pushing to `main` triggers GitHub Actions (`.github/workflows/docker-build-push.yml`),
which builds the Docker image and pushes it to `ghcr.io/ltalignani/microhaplot-2`.

ArgoCD watches this repository and automatically applies the `k8s/` manifests to
the `tools` namespace on the K3s cluster at `skat3.ird.fr`.

The app is served at `https://skat3.ird.fr/microhaplot2/` via Traefik with
strip-prefix middleware.

---

## Key differences from microhaplot v1

| | microhaplot v1 | microhaplot2 |
| - | -------------- | ------------ |
| **Access** | Local R package install | Web app at skat3.ird.fr |
| **Input files** | SAM (unindexed) | BAM + BAI (indexed) |
| **Extraction** | Perl script `hapture` | Rsamtools (pure R) |
| **Parallelism** | Shell `& wait;` | BiocParallel |
| **UI framework** | shinyBS (Bootstrap 3) | bslib (Bootstrap 5) |
| **Code structure** | Monolithic server.R (3887 lines) | Shiny modules |
| **Multi-user** | Not supported (file conflicts) | Session-isolated temp dirs |
| **Windows support** | Yes | No (container is Linux) |

---

## Citation

If you use microhaplot2 in your research, please cite the original microhaplot:

> Ng, Thomas C. & Anderson Eric C. (2017). ngthomas/microhaplot: microhaplotype
> viewer. Zenodo. <https://doi.org/10.5281/zenodo.821679>

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.821679.svg)](https://doi.org/10.5281/zenodo.821679)

---

## License

GPL-3 — see [LICENSE.md](LICENSE.md).
