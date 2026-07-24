# F-statistics computation, wrapping hierfstat. Pure function, no Shiny deps.

# Assemble a hierfstat-ready data.frame (pop, locus1, locus2, ...) from the
# encode_hierfstat() matrix and a per-individual group assignment. `pop` is
# coded as an integer factor (hierfstat's basic.stats() does numeric
# arithmetic on the pop column and errors on character/single-level input);
# the group-name <-> code mapping is returned alongside for relabelling.
build_hierfstat_df <- function(hierfstat_encoded, groups) {
  m <- hierfstat_encoded$matrix
  group_labels <- unname(groups[rownames(m)])
  pop_factor <- factor(group_labels, levels = sort(unique(group_labels)))
  dat <- data.frame(pop = as.integer(pop_factor), as.data.frame(m),
                     stringsAsFactors = FALSE, check.names = FALSE)
  list(dat = dat, levels = levels(pop_factor))
}

# hierfstat::betas() and internals do apply(data[, -1], 2, ...), which errors
# when only one locus column remains (drop-to-vector). Duplicating the sole
# locus column sidesteps this without changing the weighted-average betaW.
widen_single_locus <- function(dat) {
  loci <- setdiff(names(dat), "pop")
  if (length(loci) != 1L) return(dat)
  dat[[paste0(loci, "_dup")]] <- dat[[loci]]
  dat
}

# Per-locus BetaS via hierfstat::betas(), computed one locus at a time.
# hierfstat::betas() requires >= 2 locus columns internally (apply() over a
# data.frame), so each locus is duplicated to satisfy that while leaving the
# weighted-average betaW unaffected (duplicating a value doesn't change its
# average).
compute_per_locus_betas <- function(dat) {
  loci <- setdiff(names(dat), "pop")
  betaW <- vapply(loci, function(lo) {
    sub <- dat[, c("pop", lo), drop = FALSE]
    sub[[paste0(lo, "_dup")]] <- sub[[lo]]
    hierfstat::betas(sub, diploid = TRUE)$betaW
  }, numeric(1))
  data.frame(betaW = betaW, row.names = loci)
}

#' Compute F-statistics for a hierfstat-encoded matrix.
#'
#' @param hierfstat_encoded list as returned by encode_hierfstat() (#12);
#'   must contain $matrix (individuals x loci, hierfstat-coded diplotypes).
#' @param groups named character vector, names are individual ids matching
#'   rownames(hierfstat_encoded$matrix), values are group labels.
#' @return list with $basic (hierfstat::basic.stats() plus a derived Fit
#'   column), $pairwise_fst (square symmetric matrix, NA diagonal),
#'   $betas (list with $global and $per_locus), $allelic_richness
#'   (hierfstat::allelic.richness() output, rarefied to the smallest group).
#' @export
compute_fstats <- function(hierfstat_encoded, groups) {
  built <- build_hierfstat_df(hierfstat_encoded, groups)
  dat <- built$dat

  basic <- hierfstat::basic.stats(dat, diploid = TRUE)
  basic$perloc$Fit <- 1 - (1 - basic$perloc$Fis) * (1 - basic$perloc$Fst)
  basic$overall[["Fit"]] <- 1 - (1 - basic$overall[["Fis"]]) * (1 - basic$overall[["Fst"]])

  # Pairwise Fst and BetaS are undefined with a single group; hierfstat
  # errors rather than degrading gracefully, so short-circuit here. Callers
  # (the sub-tab UI) are expected to gate on >= 2 groups before this point.
  n_groups <- length(built$levels)
  if (n_groups >= 2L) {
    pairwise_fst <- as.matrix(hierfstat::pairwise.WCfst(dat, diploid = TRUE))
    dimnames(pairwise_fst) <- list(built$levels, built$levels)

    betas_full <- hierfstat::betas(widen_single_locus(dat), diploid = TRUE)
    betas_list <- list(global = betas_full$betaW, per_locus = compute_per_locus_betas(dat))
  } else {
    pairwise_fst <- matrix(NA_real_, 1L, 1L, dimnames = list(built$levels, built$levels))
    betas_list <- list(global = NA_real_, per_locus = data.frame(betaW = numeric(0)))
  }

  allelic_richness <- hierfstat::allelic.richness(dat, diploid = TRUE)
  colnames(allelic_richness$Ar) <- built$levels

  list(
    basic = basic,
    pairwise_fst = pairwise_fst,
    betas = betas_list,
    allelic_richness = allelic_richness
  )
}
