#!/usr/bin/env Rscript
# Times a single prepHaplotFiles() run against a real (not bundled-fixture)
# BAM/VCF dataset, and prints wall-clock elapsed time plus a few sanity
# counts. Written for wayfinder ticket #37: comparing the current pipeline
# (Perl at commit 45c6546, or microhaplot-extract on this branch) against a
# real dataset, not the small sebastes toy fixture bundled with the
# package -- see research/microhaplot-extract-benchmark.md for the
# reproduction recipe and results.
#
# This script is deliberately checked into the repo; the *data* it points
# at is not (production BAM/VCF/metadata are not committed -- see
# research/microhaplot-extract-benchmark.md for why).
#
# Usage (run from the repo root, in either checkout you want to time):
#   Rscript scripts/benchmark-real-data-extraction.R \
#     --data-dir path/to/bams --label-tsv path/to/metadata.tsv \
#     --vcf path/to/variants.vcf.gz --out-dir /tmp/bench-out \
#     --run-label perl_baseline --n-jobs 9
#
# --label-tsv is the field prep wizard's 4-column metadata format
# (bam_file, individual_id, group, color) -- the same shape
# build_prep_label_file() consumes.

suppressMessages(devtools::load_all(quiet = TRUE))

args <- commandArgs(trailingOnly = TRUE)
opt <- function(flag, default = NULL) {
  i <- which(args == flag)
  if (length(i) == 0) return(default)
  args[i + 1]
}

data_dir <- opt("--data-dir")
label_tsv <- opt("--label-tsv")
vcf_path <- opt("--vcf")
out_dir <- opt("--out-dir", tempfile("bench-out-"))
run_label <- opt("--run-label", "bench")
n_jobs <- as.integer(opt("--n-jobs", "1"))

stopifnot(!is.null(data_dir), !is.null(label_tsv), !is.null(vcf_path))
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

meta <- utils::read.delim(label_tsv, stringsAsFactors = FALSE)
label_path <- file.path(out_dir, "label.txt")
build_prep_label_file(meta, label_path)

app_dir <- file.path(out_dir, "app")
dir.create(app_dir, showWarnings = FALSE, recursive = TRUE)
mvShinyHaplot(app_dir)
app_path <- file.path(app_dir, "microhaplot")

t0 <- Sys.time()
res <- prepHaplotFiles(
  run.label = run_label,
  sam.path = data_dir,
  label.path = label_path,
  vcf.path = vcf_path,
  out.path = out_dir,
  app.path = app_path,
  n.jobs = n_jobs
)
elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))

cat("run.label:", run_label, "\n")
cat("n.jobs:", n_jobs, "\n")
cat("elapsed_seconds:", elapsed, "\n")
cat("rows:", nrow(res), "\n")
cat("unique_ids:", length(unique(res$id)), "\n")
cat("unique_loci:", length(unique(res$locus)), "\n")

saveRDS(res, file.path(out_dir, paste0(run_label, "_result.rds")))
