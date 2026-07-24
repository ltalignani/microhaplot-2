# Pure data.frame shaping helpers turning compute_fstats() output into
# table/plot-ready shapes. No Shiny deps, no side effects.

#' Per-locus Ho/He/Fis/Fst/Fit table with a "Global" summary row appended.
#' He is taken as Hs (within-subpopulation expected heterozygosity), the
#' standard hierfstat proxy for He.
#'
#' @param fstats list as returned by compute_fstats().
#' @return data.frame with columns locus, Ho, He, Fis, Fst, Fit.
#' @export
fstats_perloc_table <- function(fstats) {
  perloc <- fstats$basic$perloc
  overall <- fstats$basic$overall

  tbl <- data.frame(
    locus = rownames(perloc),
    Ho    = perloc$Ho,
    He    = perloc$Hs,
    Fis   = perloc$Fis,
    Fst   = perloc$Fst,
    Fit   = perloc$Fit,
    stringsAsFactors = FALSE
  )

  global_row <- data.frame(
    locus = "Global",
    Ho    = unname(overall[["Ho"]]),
    He    = unname(overall[["Hs"]]),
    Fis   = unname(overall[["Fis"]]),
    Fst   = unname(overall[["Fst"]]),
    Fit   = unname(overall[["Fit"]]),
    stringsAsFactors = FALSE
  )

  rbind(tbl, global_row)
}

#' Long-format pairwise Fst: one row per (group1, group2) cell, diagonal kept
#' as NA. Suitable for a ggplot2 geom_tile() heatmap.
#'
#' @param fstats list as returned by compute_fstats().
#' @return data.frame with columns group1, group2, fst.
#' @export
pairwise_fst_long <- function(fstats) {
  pw <- fstats$pairwise_fst
  groups <- rownames(pw)

  df <- expand.grid(group1 = groups, group2 = groups, stringsAsFactors = FALSE)
  df$fst <- mapply(function(g1, g2) pw[g1, g2], df$group1, df$group2)
  df
}

#' Per-locus BetaS table with a "Global" summary row appended.
#'
#' @param fstats list as returned by compute_fstats().
#' @return data.frame with columns locus, betaW.
#' @export
betas_table <- function(fstats) {
  per_locus <- fstats$betas$per_locus
  tbl <- data.frame(locus = rownames(per_locus), betaW = per_locus$betaW,
                     stringsAsFactors = FALSE)
  global_row <- data.frame(locus = "Global", betaW = fstats$betas$global,
                            stringsAsFactors = FALSE)
  rbind(tbl, global_row)
}

#' Long-format rarefied allelic richness: one row per (locus, group).
#'
#' @param fstats list as returned by compute_fstats().
#' @return data.frame with columns locus, group, richness.
#' @export
allelic_richness_table <- function(fstats) {
  ar <- fstats$allelic_richness$Ar
  df <- as.data.frame(as.table(as.matrix(ar)), stringsAsFactors = FALSE)
  names(df) <- c("locus", "group", "richness")
  df
}
