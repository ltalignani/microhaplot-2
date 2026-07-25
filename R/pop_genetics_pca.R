# Pure-function PCA and projection over one-hot encoded haplotype matrices.
# No Shiny dependencies, no side effects.

#' Run PCA on a centred and scaled one-hot dosage matrix.
#'
#' Returns scores (individuals x K), loadings (columns x K), pct_var (%
#' variance explained per PC), and the centre/scale parameters needed to
#' project new individuals onto the same axes.
#'
#' @param onehot_matrix numeric matrix (individuals x locus__haplo columns),
#'   as returned by encode_onehot().
#' @param K integer. Number of principal components to keep.
#' @return list with $scores, $loadings, $pct_var, $means, $sds.
#' @export
run_pca <- function(onehot_matrix, K) {
  # prcomp(scale. = TRUE) errors on zero-variance columns; remove them first.
  col_vars <- apply(onehot_matrix, 2, stats::var, na.rm = TRUE)
  constant <- is.na(col_vars) | col_vars == 0
  if (any(constant)) {
    warning(sprintf("run_pca: %d constant column(s) removed before PCA", sum(constant)))
    onehot_matrix <- onehot_matrix[, !constant, drop = FALSE]
  }
  if (ncol(onehot_matrix) == 0L)
    stop("run_pca: no variable columns remain after removing constant columns")

  pca <- stats::prcomp(onehot_matrix, center = TRUE, scale. = TRUE)
  K <- min(K, ncol(pca$x))

  list(
    scores   = pca$x[, seq_len(K), drop = FALSE],
    loadings = pca$rotation[, seq_len(K), drop = FALSE],
    pct_var  = 100 * (pca$sdev^2 / sum(pca$sdev^2))[seq_len(K)],
    means    = pca$center,
    sds      = pca$scale
  )
}

#' Project new individuals onto an existing PCA's axes.
#'
#' Columns present in query_onehot but absent from the reference PCA's
#' loadings are dropped, with a warning. Missing reference columns are not
#' filled in — the projection uses only the shared columns' loadings.
#'
#' @param pca_result list as returned by run_pca().
#' @param query_onehot numeric matrix (individuals x locus__haplo columns)
#'   to project onto pca_result's axes.
#' @return numeric matrix (individuals x K) of projected scores.
#' @export
project_onto_pca <- function(pca_result, query_onehot) {
  ref_cols <- rownames(pca_result$loadings)
  query_cols <- colnames(query_onehot)

  dropped <- setdiff(query_cols, ref_cols)
  if (length(dropped) > 0L) {
    warning(sprintf(
      "project_onto_pca: columns absent from reference dropped: %s",
      paste(dropped, collapse = ", ")
    ))
  }

  shared <- intersect(query_cols, ref_cols)
  centered <- sweep(query_onehot[, shared, drop = FALSE], 2, pca_result$means[shared], "-")
  scaled <- sweep(centered, 2, pca_result$sds[shared], "/")

  scaled %*% pca_result$loadings[shared, , drop = FALSE]
}

#' Align a query one-hot matrix to a reference one-hot matrix's column set.
#'
#' Columns present in query_onehot but absent from ref_onehot are dropped.
#' Columns present in ref_onehot but absent from query_onehot are added,
#' filled with that reference column's mean (imputation).
#'
#' Ported for completeness alongside the rest of pop_genetics_pca.R; inert
#' until the external reference-panel merge feature (out of scope for this
#' effort — see .scratch/popgen-v1-port/map.md) is ported.
#'
#' @param query_onehot numeric matrix (individuals x locus__haplo columns).
#' @param ref_onehot numeric matrix (individuals x locus__haplo columns).
#' @return numeric matrix aligned to ref_onehot's column set.
#' @export
align_query_to_reference <- function(query_onehot, ref_onehot) {
  ref_cols  <- colnames(ref_onehot)
  ref_means <- colMeans(ref_onehot)

  aligned <- matrix(0, nrow = nrow(query_onehot), ncol = length(ref_cols),
                     dimnames = list(rownames(query_onehot), ref_cols))

  shared <- intersect(colnames(query_onehot), ref_cols)
  aligned[, shared] <- query_onehot[, shared, drop = FALSE]

  missing_cols <- setdiff(ref_cols, colnames(query_onehot))
  for (col in missing_cols) {
    aligned[, col] <- ref_means[[col]]
  }

  aligned
}
