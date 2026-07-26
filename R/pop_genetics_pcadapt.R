# Pure-function pcadapt outlier scan over one-hot encoded haplotype matrices.
# No Shiny dependencies, no side effects.

#' Run a pcadapt scan on a one-hot dosage matrix.
#'
#' Wraps pcadapt::read.pcadapt(type = "lfmm") + pcadapt::pcadapt(). Returns
#' the pcadapt result object, which carries one pvalue per matrix column.
#'
#' pcadapt internally drops columns below its own minor-allele-frequency
#' threshold (min.maf, default 0.05) before computing its partial SVD, and
#' requires K to be strictly less than the number of columns that survive
#' that filter. microhaplot's one-hot columns are frequently rare
#' haplotype/locus combinations, so that survivor count can be much smaller
#' than ncol(onehot_matrix) — asking for more components than that leaves
#' pcadapt with a generic, misleading "Can't compute SVD" error. K is
#' capped defensively here to the same MAF-based count pcadapt computes
#' internally, so the scan degrades gracefully instead of crashing.
#'
#' @param onehot_matrix numeric matrix (individuals x locus__haplo columns),
#'   as returned by encode_onehot().
#' @param K integer. Number of principal components to use.
#' @param min.maf numeric. Minor-allele-frequency threshold, passed through
#'   to pcadapt::pcadapt() and used to pre-compute the effective column
#'   count for capping K. Must match pcadapt's own default/argument so the
#'   cap reflects what pcadapt will actually do.
#' @return a pcadapt result object (see pcadapt::pcadapt()).
#' @export
run_pcadapt_scan <- function(onehot_matrix, K, min.maf = 0.05) {
  af <- colMeans(onehot_matrix, na.rm = TRUE) / 2
  maf <- pmin(af, 1 - af)
  p2 <- sum(maf >= min.maf, na.rm = TRUE)

  if (p2 < 2L) {
    stop(sprintf(
      "run_pcadapt_scan: only %d column(s) pass the min.maf = %s filter; need at least 2 to run a scan.",
      p2, min.maf
    ))
  }

  K <- min(K, p2 - 1L, nrow(onehot_matrix) - 1L)

  input <- pcadapt::read.pcadapt(onehot_matrix, type = "lfmm")
  pcadapt::pcadapt(input, K = K, min.maf = min.maf)
}

#' Derive per-locus names from one-hot column names ("locus__haplo" -> "locus").
#'
#' @param onehot_colnames character vector of "locus__haplo"-style column names.
#' @return character vector of locus names, same length as onehot_colnames.
#' @export
locus_names_from_onehot <- function(onehot_colnames) {
  sub("__.*$", "", onehot_colnames)
}

#' Apply Benjamini-Hochberg correction, reduced to one row per locus.
#'
#' `locus_names` has one entry per pcadapt_result$pvalues entry (i.e. per
#' one-hot column); loci sharing multiple haplotype columns are reduced to
#' their minimum pvalue before BH correction. pcadapt sets a column's
#' pvalue to NA when it fails the `min.maf` filter (common for rare
#' haplotype-column variants), so the minimum is taken over the non-NA
#' pvalues within a locus; a locus is only NA overall if every one of its
#' columns was filtered.
#'
#' @param pcadapt_result a pcadapt result object, as returned by run_pcadapt_scan().
#' @param locus_names character vector, one entry per pcadapt_result$pvalues entry.
#' @param alpha numeric. BH significance threshold.
#' @return data.frame with columns locus, pvalue, padj, outlier.
#' @export
get_outliers_bh <- function(pcadapt_result, locus_names, alpha) {
  pvals <- pcadapt_result$pvalues
  locus_order <- unique(locus_names)
  min_pvalue <- vapply(locus_order, function(lo) {
    vals <- pvals[locus_names == lo]
    vals <- vals[!is.na(vals)]
    if (length(vals) == 0L) return(NA_real_)
    min(vals)
  }, numeric(1))

  df <- data.frame(locus = locus_order, pvalue = unname(min_pvalue), stringsAsFactors = FALSE)
  df$padj <- stats::p.adjust(df$pvalue, method = "BH")
  df$outlier <- df$padj <= alpha
  df
}
