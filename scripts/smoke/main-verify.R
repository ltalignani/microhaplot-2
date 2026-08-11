# Runs *inside* the `main` container (piped in via `docker compose exec -T
# main Rscript -`). Confirms the .rds the `prep` container just produced is
# visible and loadable here through the shared volume, with no restart.

run_label <- Sys.getenv("SMOKE_RUN_LABEL", "smoke")
app <- file.path(Sys.getenv("HOME"), "Shiny", "microhaplot")

for (f in file.path(app, paste0(run_label, c(".rds", "_posinfo.rds")))) {
  if (!file.exists(f)) {
    stop("expected ", f, " in the shared volume, but it is missing")
  }
}

haplo <- readRDS(file.path(app, paste0(run_label, ".rds")))
if (!is.data.frame(haplo)) {
  stop(run_label, ".rds did not contain a data frame")
}
if (nrow(haplo) == 0) {
  stop(run_label, ".rds contained no haplotype rows")
}

expected <- c(
  "group", "id", "locus", "haplo", "depth", "allele.balance", "rank"
)
missing <- setdiff(expected, names(haplo))
if (length(missing)) {
  stop("missing columns in ", run_label, ".rds: ",
       paste(missing, collapse = ", "))
}

posinfo <- readRDS(file.path(app, paste0(run_label, "_posinfo.rds")))
if (nrow(posinfo) == 0) {
  stop(run_label, "_posinfo.rds contained no loci")
}

cat(sprintf(
  paste("main service loaded %s.rds from the shared volume:",
        "%d rows, %d loci, %d individuals\n"),
  run_label, nrow(haplo), nrow(posinfo), length(unique(haplo$id))
))
