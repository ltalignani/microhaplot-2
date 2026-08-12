
# microhaplot <img src="https://i.ibb.co/68M0tpT/microhaplot-logo.png" align="right" width="200"/>

<!-- badges: start -->

[![CRAN
status](https://www.r-pkg.org/badges/version/microhaplot)](https://CRAN.R-project.org/package=microhaplot)
<!-- badges: end -->

> **This is microhaplot 2**, an extended fork of
> [ngthomas/microhaplot](https://github.com/ngthomas/microhaplot) maintained
> by Loïc Talignani (Université de Montpellier). On top of the original
> package it adds a
> **Population Genetics** module (F-statistics, allelic diversity, PCA,
> outlier detection), a **Field Genotyping Prep** app that wraps the
> extraction behind a guided wizard, **BAM input** support, and a **Docker**
> distribution that requires no local R installation.

`microhaplot` generates visual summaries of microhaplotypes found in
short read alignments. All you need are alignment SAM or BAM files and a
variant call VCF file. (The latter tells `microhaplot` which SNPs to
include into microhaplotypes). It was designed for extracting and
visualized haplotypes from high-quality amplicon sequencing data. We
have used it extensively to process amplicon sequencing data (with 100
to 500 amplicons) from rockfish and Chinook salmon, generated on an
Illumina MiSeq sequencer. It should be extensible to sequences from
capture arrays, like RAPTURE data.

There are two key steps in the `microhaplot` workflow:

1.  **Extraction.** Alignment and variant (SNP) data are summarized into
    a single data frame. You supply a VCF file listing the variants you
    want to extract, and as many SAM or BAM files (one per individual)
    as you want to extract read information from. CIGAR strings in the
    alignment files are parsed to pull the variant information out of
    each read. Depending on the size of the data set, this can take a
    few minutes.

2.  **Visualization.** A Shiny app lets you explore the sequence
    information, call genotypes using read-depth based filtering
    criteria, curate loci, and run population genetics analyses. Plot
    summaries include read depth, fraction of callable haplotypes,
    Hardy-Weinberg equilibrium plots, F-statistics, PCA, and more.

<center>

<img src="https://i.ibb.co/F5JtHj1/microhaplot-demo-1.gif" align="center" width="500"/>

</center>

There are two ways to run all of this. **Docker is the recommended
route** and needs nothing installed but Docker Desktop — no R, no Perl,
no `samtools`, and no R console. If you would rather work in R, the
package can also be installed directly; see [Installing as an R
package](#installing-as-an-r-package) at the end.

## Quick start with Docker

Both apps — the main visualization app and the field genotyping prep
wizard — ship as a single Docker image.

### Prerequisites

Install Docker Desktop for your OS:

- [Docker Desktop for Mac](https://www.docker.com/products/docker-desktop/) (Intel and Apple Silicon)
- [Docker Desktop for Linux](https://www.docker.com/products/docker-desktop/)

This release targets Mac and Linux. It will likely also work on Windows
via Docker Desktop + WSL2, but that hasn't been tested yet.

### One-time setup

Download `docker-compose.yml` from this repo (no need to clone it):

``` sh
curl -O https://raw.githubusercontent.com/ltalignani/microhaplot-2/master/docker-compose.yml
```

Create a folder on your machine where you'll drop your BAM/VCF/TSV files
and where the generated `.rds` files will appear:

``` sh
mkdir -p ./microhaplot-data
```

### Launch

``` sh
docker compose up
```

Then open:

- the field genotyping prep wizard at <http://localhost:3839>
- the main microhaplot app at <http://localhost:3838>

Both apps share the same `./microhaplot-data` folder — files you extract
in the prep wizard show up immediately in the main app, no copying, no
restart.

### Alignments that live elsewhere

The containers can only see what you mount, so BAM files outside
`./microhaplot-data` won't appear in the prep wizard's folder browser.
Rather than copying them, point `MICROHAPLOT_INPUT_DIR` at the folder and
it is mounted read-only as `input` inside the shared folder:

``` sh
MICROHAPLOT_INPUT_DIR=/path/to/my/bam/folder docker compose up
```

The same variable can go in a `.env` file next to `docker-compose.yml`.

### Stopping

``` sh
docker compose down
```

Your data stays in `./microhaplot-data` between runs.

### A note for Windows and BAM files

Called directly from R on Windows, `prepHaplotFiles` doesn't support BAM
input (only SAM). Running through Docker sidesteps this entirely: the
container is always Linux inside, regardless of your host OS, so BAM
input works the same way on Windows-via-Docker as it does on Mac or
Linux.

### A full walkthrough

The **Extracting haplotypes with Docker** vignette takes you from
`docker compose up` to a dataset open in the main app, step by step and
with screenshots, using a bundled 20-sample demo dataset.

## The Field Genotyping Prep wizard

The prep wizard (<http://localhost:3839> under Docker,
`runShinyHaplotPrep()` from R) wraps the extraction step behind a
point-and-click interface. No bioinformatics background or R scripting is
required to use it, which makes it the natural tool for processing a
field campaign of hundreds or thousands of samples.

It walks through five steps:

1.  **Select folder** — browse to the folder containing all of your BAM
    files for this run (no need to upload files one by one). Under
    Docker, the folder browser's `home` *is* your shared
    `./microhaplot-data` folder.
2.  **Upload files** — provide a metadata TSV (with a header row:
    `bam_file`, `individual_id`, `group`, and an optional `color`
    column) and the VCF defining your target SNPs. A blank template TSV
    is available to download directly from this step.
3.  **Validate** — before anything is extracted, the app checks that
    every BAM referenced in your TSV exists in the selected folder, that
    none of your BAM files are truncated or corrupted (via `samtools
    quickcheck`), and that your VCF's chromosome names match your BAM
    files' reference names. Every problem found is shown at once.
4.  **Extract** — once validation passes, extraction runs in the
    background (your browser stays responsive) with a live progress bar,
    calling the same `prepHaplotFiles` used from the R console — not a
    separate extraction engine.
5.  **Done** — the two output `.rds` files are written to
    `~/Shiny/microhaplot` and their paths are shown so you know exactly
    where to find them. Open the main app to explore the result.

The wizard takes BAM files only. If your alignments are SAM, either
convert them (`samtools view -b`) or use `prepHaplotFiles` from R, which
accepts both.

## Example data

The package ships with a small sample dataset drawn from an actual short
read sequencing run on rockfish: eight genomic loci for four populations
of five individuals each, twenty individuals in total.

- `inst/extdata/sebastes_bam.tar.gz` — BAM files, a VCF, and a ready-made
  metadata TSV. This is what the prep wizard and the Docker vignette use.
- `inst/extdata/sebastes_sam.tar.gz` — the same samples as SAM, with the
  3-column label file `prepHaplotFiles` expects.

Two further example datasets, `fish1.rds` and `fish2.rds`, come
pre-loaded in the main app's **Data Set** dropdown and are the basis of
the **microhaplot walkthrough** vignette.

## Installing as an R package

If you prefer to work from an R console, or you're on a system where
Docker isn't available (an HPC cluster, for example), install the package
directly.

### Required Perl dependency

You need Perl (version \>5.014) installed on your OS.
For Windows users, we recommend installing it via
<http://strawberryperl.com/>.
For Mac and Linux users, Perl can be downloaded from
<https://www.perl.org/get.html>

### Required samtools dependency (BAM input only)

If you plan to use BAM files (rather than SAM files) with
`prepHaplotFiles`, you also need `samtools` installed and available on
your `PATH`. It's not required if you only ever use SAM files. Install it
from <http://www.htslib.org/> or via your OS package manager (e.g.
`brew install samtools`, `apt install samtools`). BAM input via
`samtools` streaming is supported on macOS and Linux only, not Windows.

**Mac users: remember to install [XQuartz](https://www.xquartz.org/)
when upgrading macOS to a new major version.**

### Install

``` r
# install.packages("devtools")
devtools::install_github("ltalignani/microhaplot-2", build_vignettes = TRUE, build_opts = c("--no-resave-data", "--no-manual"))
```

Then place the Shiny app somewhere convenient. The following creates
`Shiny/microhaplot` in your home directory and fills it with the app and
the example datasets:

``` r
microhaplot::mvShinyHaplot("~/Shiny")
```

### Extract and visualize

First create a tab-separated **label** file with 3 columns, in this
order: SAM or BAM file name, individual ID, and group label. Use `NA` if
you don't want to assign a group. Keeping all your alignment files in one
directory makes this easier.

The `label` file looks like this:

``` txt
s6.sam  s6      copper
s11.sam s11     copper
s13.sam s13     gold
s14.sam s14     kelp
s18.sam s18     gold
```

SAM and BAM files can be freely mixed in the same label file — each row's
file extension (`.sam` or `.bam`, case-insensitive) decides how it's
read. BAM files don't need a `.bai` index:

``` txt
s6.bam  s6      copper
s11.sam s11     copper
s13.bam s13     gold
```

Then run `prepHaplotFiles`, giving it a run label, the directory holding
your alignment files, the label file, the VCF, and optionally a number of
threads (non-Windows only):

``` r
library(microhaplot)

# to access package sample case study dataset of rockfish
run.label <- "sebastes"

sam.path <- tempdir()
untar(system.file("extdata",
                  "sebastes_sam.tar.gz",
                  package="microhaplot"),
      exdir = sam.path)

label.path <- file.path(sam.path, "label.txt")
vcf.path <- file.path(sam.path, "sebastes.vcf")
out.path <- tempdir()
app.path <- "~/Shiny/microhaplot"

# for your dataset: customize the following paths
# sam.path <- "~/microhaplot/extdata/"
# label.path <- "~/microhaplot/extdata/label.txt"
# vcf.path <- "~/microhaplot/extdata/sebastes.vcf"
# app.path <- "~/Shiny/microhaplot"

haplo.read.tbl <- prepHaplotFiles(run.label = run.label,
                            sam.path = sam.path,
                            out.path = out.path,
                            label.path = label.path,
                            vcf.path = vcf.path,
                            app.path = app.path,
                            n.jobs = 4) # assume running on dual core

runShinyHaplot(app.path)
```

To use the prep wizard instead of calling `prepHaplotFiles` yourself, launch
it with no arguments; it writes its output to `~/Shiny/microhaplot`, which is
where `runShinyHaplot` above expects to find it:

``` r
runShinyHaplotPrep()
```

The vignettes go further:

``` r
browseVignettes("microhaplot")
```

## Troubleshooting

### Docker: "permission denied" writing to `./microhaplot-data`

The containers run as a non-root user (UID/GID `1000:1000` by default) so
they can write into your mounted data folder without needing `root`
inside the container. On most Linux distributions this matches the
first regular user account, so it works out of the box — but if your
own UID/GID differ (check with `id -u` and `id -g`), or you're on a
platform where they don't line up automatically, downloads and
extractions into `./microhaplot-data` may fail with a permissions error.

Fix it by pointing the containers at your actual UID/GID via a `.env`
file placed next to `docker-compose.yml`:

``` sh
cat <<EOF > .env
MICROHAPLOT_UID=$(id -u)
MICROHAPLOT_GID=$(id -g)
EOF
```

The same `.env` file also lets you override the shared data folder
(`MICROHAPLOT_DATA_DIR`, default `./microhaplot-data`), the host ports
(`MICROHAPLOT_MAIN_PORT`/`MICROHAPLOT_PREP_PORT`, default `3838`/`3839`),
and the image version (`MICROHAPLOT_VERSION`, default `latest`) —
none of `docker-compose.yml` itself needs editing.

### Run microhaplot in your browser, not RStudio's Viewer pane

This applies to the R installation route only. If you're using RStudio
Desktop, launch microhaplot so it opens in your default web browser
instead of RStudio's built-in Viewer pane:

``` r
library(microhaplot)
options(shiny.launch.browser = TRUE)
runShinyHaplot("~/Shiny/microhaplot")
```

RStudio's Viewer pane doesn't always recycle graphics devices cleanly
between plot renders, which can eventually surface as a
`too many open devices` error — more likely to show up in tabs with a lot
of plots, such as **Population Genetics**. Running in an external browser
avoids this.

### "too many open devices" error

If you hit this error anyway (for example, after a long session with a
lot of navigation between tabs), close every open graphics device and
try again:

``` r
while (!is.null(dev.list())) dev.off()
```

## Suggestions

  - SAM/BAM files: For pair-ended experiment, both directional reads
    should be flashed into one.
