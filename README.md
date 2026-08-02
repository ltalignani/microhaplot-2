
# microhaplot <img src="https://i.ibb.co/68M0tpT/microhaplot-logo.png" align="right" width="200"/>

<!-- badges: start -->

[![CRAN
status](https://www.r-pkg.org/badges/version/microhaplot)](https://CRAN.R-project.org/package=microhaplot)
<!-- badges: end -->

`microhaplot` generates visual summaries of microhaplotypes found in
short read alignments. All you need are alignment SAM or BAM files and a
variant call VCF file. (The latter tells `microhaplot` which SNPs to
include into microhaplotypes). It was designed for extracting and
visualized haplotypes from high-quality amplicon sequencing data. We
have used it extensively to process amplicon sequencing data (with 100
to 500 amplicons) from rockfish and Chinook salmon, generated on an
Illumina MiSeq sequencer. It should be extensible to sequences from
capture arrays, like RAPTURE data.

This software exists as an R package `microhaplot` that includes within
it the code to set up and establish an Rstudio/Shiny server to visualize
and manipulate the data. There are two key steps in the `microhaplot`
workflow:

1.  The first step is to summarize alignment and variant (SNP) data into
    a single data frame that is easily operated upon. This is done using
    the function `microhaplot::prepHaplotFiles`. You must supply a VCF
    file that includes variants that you are interested in extracting,
    and as many SAM or BAM files (one for each individual) that you want
    to extract read information from at each of the variants. The
    function `microhaplot::prepHaplotFiles` makes a call to PERL to parse
    the CIGAR strings in the alignment files to extract the variant
    information at each read and store this information into a data
    frame which gets saved with the installed Shiny app (see below) for
    later use. Depending on the size of the data set, this can take a few
    minutes. BAM files are streamed through `samtools` rather than
    converted to SAM on disk first, so they require `samtools` to be
    installed and on your `PATH` — see **required dependencies** below.
    (BAM input is not currently supported on Windows.)

2.  The second step is to run the microhaplot Shiny app to visualize the
    sequence information, call genotypes using simple read-depth based
    filtering criteria, and curate the loci. microhaplot is suitable for
    quick assessment and quality control of haplotypes generated from
    library runs. Plot summaries include read depth, fraction of
    callable haplotypes, Hardy-Weinberg equilibrium plots, and more.

<center>

<img src="https://i.ibb.co/F5JtHj1/microhaplot-demo-1.gif" align="center" width="500"/>

</center>

See the **Example Data** section to learn about how to run each of these
steps on the example data that are provided with the package.

## Installation and Quick Start

### required Perl dependencies:

You need to have Perl (version \>5.014) installed in your OS in order to
run Microhaplot.  
For Window users, we recommend install it via
<http://strawberryperl.com/>.  
For Mac and Linux users, Perl can be downloaded from
<https://www.perl.org/get.html>

### required samtools dependency (BAM input only):

If you plan to use BAM files (rather than SAM files) with
`prepHaplotFiles`, you also need `samtools` installed and available on
your `PATH`. It's not required if you only ever use SAM files.
Install it from <http://www.htslib.org/> or via your OS package manager
(e.g. `brew install samtools`, `apt install samtools`). BAM input via
`samtools` streaming is currently supported on macOS and Linux only, not
Windows.

You can either clone the repository and build the `microhaplot` package
yourself, or, more easily, you can install it using
[devtools](https://github.com/hadley/devtools). You can get `devtools`
by `install.packages("devtools")`.

**To mac user: remember to install [XQuartz](https://www.xquartz.org/),
when upgrading your macOS to a new major version.**

Once you have `devtools` available in R, you can get `microhaplot` this
way:

``` r
devtools::install_github("ngthomas/microhaplot", build_vignettes = TRUE, build_opts = c("--no-resave-data", "--no-manual"))
```

Once you have installed the `microhaplot` R package with devtools there
you need to use the `microhaplot::mvHaplotype` to establish the
microhaplot Shiny App in a convenient location on your system. The
following line creates the directory `Shiny` in my home directory and
then within that it creates the directory `microhaplot` and fills it
with the Shiny app as well as the example data that go along with that.

``` r
microhaplot::mvShinyHaplot("~/Shiny") # provide a directory path to host the microhaplot app
```

To start familiarizing yourself with microhaplot using the provided
example data. We recommend going through our first vignette. Call it up
with:

``` r
browseVignettes("microhaplot")
```

and check out `microhaplot-walkthrough`.

Now, having done that, we can launch Shiny microhaplot on the example
data:

``` r
library(microhaplot)
app.path <- "~/Shiny/microhaplot"
runShinyHaplot(app.path)
```

## Quick Guide to use microhaplot to parse out SAM/BAM and VCF files

This microhaplot package comes with a small customized sample data drawn
from an actual run of short read sequencing run on Rockfish species. The
sample data contains sequences of eight genomic loci for four
populations of five individuals each, with a total of twenty
individuals.

First you need to create a tab-separate **label** file with 3 info
columns: path to SAM or BAM file name, individual ID, and group label (in
this particular order). If you do not want assign any group label for the
individuals, you can just leave it as “NA”. It is recommended that you
have all of the SAM/BAM files under one directory to make this labeling
task easier.

The `label` file looks like this:

``` txt
s6.sam  s6      copper
s11.sam s11     copper
s13.sam s13     gold
s14.sam s14     kelp
s18.sam s18     gold
```

SAM and BAM files can be freely mixed in the same label file — each row's
file extension (`.sam` or `.bam`, case-insensitive) decides how it's read.
BAM files don't need a `.bai` index. For example:

``` txt
s6.bam  s6      copper
s11.sam s11     copper
s13.bam s13     gold
```

Once you have the label file in place, you can run `prepHaplotFiles`, a
R function that generates tables of microhaplotype, by providing the
following: \* a label to display in haPLOType \* path to the directory
with all SAM/BAM files \* path to the `label` file you just created \*
path to the VCF file  
\* optional number of threads (for non-Windows user); recommend 2 \* \#
of processors

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

## Run microhaplot with Docker (recommended for non-bioinformaticians)

If you'd rather not install R, Perl, or samtools yourself, both the main
microhaplot app and the field genotyping prep wizard are available as a
single Docker image — no R console, no package installation.

### Prerequisites

Install Docker Desktop for your OS:

- [Docker Desktop for Mac](https://www.docker.com/products/docker-desktop/) (Intel and Apple Silicon)
- [Docker Desktop for Linux](https://www.docker.com/products/docker-desktop/)

This first release targets Mac and Linux. It will likely also work on
Windows via Docker Desktop + WSL2, but that hasn't been tested yet.

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

### A note for Windows and BAM files

The main package currently doesn't support BAM input directly on Windows
(only SAM). Running through Docker sidesteps this entirely: the
container is always Linux inside, regardless of your host OS, so BAM
input works the same way on Windows-via-Docker as it does on Mac or
Linux.

### Stopping

``` sh
docker compose down
```

Your data stays in `./microhaplot-data` between runs.

## Field Genotyping Prep app (guided alternative to `prepHaplotFiles`)

If you'd rather not call `prepHaplotFiles` from the R console yourself —
for example, if you're processing a large field campaign (hundreds or
thousands of samples) and would prefer a guided, point-and-click
workflow — `microhaplot` also bundles a second, companion Shiny app that
wraps `prepHaplotFiles` behind a step-by-step wizard. No bioinformatics
background or R scripting is required to use it.

Launch it the same way you'd launch the main app:

``` r
library(microhaplot)
runShinyHaplotPrep()
```

The wizard walks through five steps:

1.  **Select folder** — browse to the local folder containing all of
    your BAM files for this run (no need to upload files one by one).
2.  **Upload files** — provide a metadata TSV (with a header row:
    `bam_file`, `individual_id`, `group`, and an optional `color`
    column) and the VCF defining your target SNPs. A blank template TSV
    is available to download directly from this step.
3.  **Validate** — before anything is extracted, the app checks that
    every BAM referenced in your TSV exists in the selected folder,
    that none of your BAM files are truncated/corrupted (via `samtools
    quickcheck`), and that your VCF's chromosome names match your BAM
    files' reference names. Every problem found is shown at once.
4.  **Extract** — once validation passes, extraction runs in the
    background (your browser stays responsive) with a live progress
    bar, calling the same `prepHaplotFiles` used above — no separate
    extraction engine.
5.  **Done** — the two output `.rds` files are written to
    `~/Shiny/microhaplot` (created automatically on first use, same
    convention as `mvShinyHaplot("~/Shiny")` above) and their paths are
    shown so you know exactly where to find them. Open the main
    `microhaplot` app separately (`runShinyHaplot()`) to explore the
    result.

This app has the same `samtools` requirement as BAM input above, and
BAM input is likewise not currently supported on Windows.

## Troubleshooting

### Run microhaplot in your browser, not RStudio's Viewer pane

If you're using RStudio Desktop, launch microhaplot so it opens in your
default web browser instead of RStudio's built-in Viewer pane:

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

## Suggestions

  - SAM/BAM files: For pair-ended experiment, both directional reads
    should be flashed into one.
