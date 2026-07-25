# Pure-function pcadapt outlier scan over one-hot encoded haplotype matrices.
# No Shiny dependencies, no side effects.

#' Run a pcadapt scan on a one-hot dosage matrix.
#'
#' Wraps pcadapt::read.pcadapt(type = "lfmm") + pcadapt::pcadapt(). Returns
#' the pcadapt result object, which carries one pvalue per matrix column.
#'
#' @param onehot_matrix numeric matrix (individuals x locus__haplo columns),
#'   as returned by encode_onehot().
#' @param K integer. Number of principal components to use.
#' @return a pcadapt result object (see pcadapt::pcadapt()).
#' @export
run_pcadapt_scan <- function(onehot_matrix, K) {
  input <- pcadapt::read.pcadapt(onehot_matrix, type = "lfmm")
  pcadapt::pcadapt(input, K = K)
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
