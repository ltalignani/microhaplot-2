library(dplyr)

# Default filter parameters used when no per-locus overrides exist.
default_filter_params <- function() {
  list(
    min_rd     = 10L,
    min_ar     = 0.1,
    n_alleles  = 2L,
    max_ar_hm  = 0.9,
    min_ar_hz  = 0.3
  )
}

# Filter haplo_data by read depth, allele ratio, and max haplotypes per individual.
# params: list with fields min_rd, min_ar, n_alleles (max_ar_hm/min_ar_hz reserved for diplotype calling).
# Returns a data.frame subset of haplo_data passing all thresholds.
filter_by_rd_ar <- function(haplo_data, params) {
  result <- haplo_data[
    haplo_data$depth          >= params$min_rd &
    haplo_data$allele.balance >= params$min_ar,
  ]

  if (!is.null(params$n_alleles) && params$n_alleles < Inf) {
    result <- result |>
      dplyr::group_by(id, locus) |>
      dplyr::slice_min(order_by = rank, n = as.integer(params$n_alleles),
                       with_ties = FALSE) |>
      dplyr::ungroup() |>
      as.data.frame()
  }

  as.data.frame(result)
}

# Per-locus summary of how many rows pass the filter.
# Returns columns: locus, n_before, n_after, n_removed, callable.
filter_summary <- function(haplo_data, params) {
  before <- haplo_data |>
    dplyr::group_by(locus) |>
    dplyr::summarise(n_before = dplyr::n(), .groups = "drop")

  filtered <- filter_by_rd_ar(haplo_data, params)

  after <- filtered |>
    dplyr::group_by(locus) |>
    dplyr::summarise(n_after = dplyr::n(), .groups = "drop")

  result <- dplyr::left_join(before, after, by = "locus") |>
    dplyr::mutate(
      n_after   = dplyr::coalesce(n_after, 0L),
      n_removed = n_before - n_after,
      callable  = n_after > 0L
    ) |>
    as.data.frame()

  result
}

# Resolve the effective filter params for a given locus given global params,
# optional per-locus params, and a resolution mode.
# mode: "global"       — always use global_params
#       "local"        — use local_params if non-NULL, else global_params
#       "min_baseline" — element-wise max(global, local)
resolve_filter_params <- function(locus, global_params, local_params,
                                  mode = "global") {
  if (mode == "global" || is.null(local_params)) {
    return(global_params)
  }
  if (mode == "local") {
    return(local_params)
  }
  # mode == "min_baseline": element-wise maximum (more stringent wins)
  Map(function(g, l) max(g, l), global_params, local_params)
}

# Save per-locus annotation (comment + Accept/Reject status) to session_dir.
# Each locus gets its own file so concurrent sessions in different dirs never collide.
save_annotation <- function(locus, comment, status, session_dir) {
  ann <- list(locus = locus, comment = comment, status = status)
  path <- file.path(session_dir, paste0("ann_", locus, ".rds"))
  saveRDS(ann, path)
  invisible(path)
}

# Load saved annotation for a locus. Returns list(locus, comment, status) or NULL.
load_annotation <- function(locus, session_dir) {
  path <- file.path(session_dir, paste0("ann_", locus, ".rds"))
  if (!file.exists(path)) return(NULL)
  readRDS(path)
}

# Load all saved annotations for a session. Returns a data.frame with columns
# locus, comment, status (zero rows if none saved).
load_all_annotations <- function(session_dir) {
  files <- list.files(session_dir, pattern = "^ann_.*\\.rds$", full.names = TRUE)
  if (length(files) == 0L) {
    return(data.frame(locus = character(), comment = character(),
                      status = character(), stringsAsFactors = FALSE))
  }
  rows <- lapply(files, readRDS)
  data.frame(
    locus   = vapply(rows, `[[`, character(1L), "locus"),
    comment = vapply(rows, `[[`, character(1L), "comment"),
    status  = vapply(rows, `[[`, character(1L), "status"),
    stringsAsFactors = FALSE
  )
}
