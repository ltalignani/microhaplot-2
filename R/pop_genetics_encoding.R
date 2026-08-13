# Pure-function encoding of haplo_data into hierfstat and one-hot matrices.
# No Shiny dependencies, no side effects.

#' Encode haplo_data as a hierfstat-compatible individuals x loci matrix.
#'
#' Each locus's unique haplotypes are assigned integer allele codes
#' (alphabetical order). Each individual's diplotype is packed into a single
#' cell as code1 * 100 + code2 (hierfstat convention). Individuals absent at
#' a locus get NA.
#'
#' Only rank 1 and rank 2 haplotypes are numbered, because only those can
#' become part of a diplotype below. Numbering every haplotype ever seen at
#' a locus — including the long tail of low-rank sequencing noise, which on
#' a real amplicon panel runs to thousands per locus — pushed codes far
#' past 99 and broke the packing: hierfstat::getal() infers a single allele
#' width for the whole matrix from its maximum value, so one oversized code
#' anywhere makes it split every genotype at the wrong digit boundary, and
#' the statistics come out wrong without any error being raised.
#'
#' @param haplo_data data.frame with columns group, id, locus, haplo, rank.
#' @return list with $matrix (individuals x loci) and $allele_codes.
#' @export
encode_hierfstat <- function(haplo_data) {
  ids  <- sort(unique(haplo_data$id))
  loci <- sort(unique(haplo_data$locus))

  callable <- haplo_data[haplo_data$rank <= 2L, ]

  allele_codes <- lapply(loci, function(lo) {
    haplos <- sort(unique(callable$haplo[callable$locus == lo]))
    codes <- seq_along(haplos)
    names(codes) <- haplos
    codes
  })
  names(allele_codes) <- loci

  # Two digits per allele is what the packing below assumes and what
  # hierfstat infers for any matrix whose maximum stays under 10000. Rather
  # than silently overflow into numbers it would misread, refuse.
  crowded <- names(allele_codes)[vapply(allele_codes, length, 1L) > 99L]
  if (length(crowded) > 0) {
    stop("more than 99 called alleles at ", length(crowded), " locus/loci (",
         paste(utils::head(crowded, 3), collapse = ", "),
         if (length(crowded) > 3) ", ..." else "",
         "); hierfstat cannot encode these. Tighten the genotype-calling ",
         "criteria, or drop these loci.", call. = FALSE)
  }

  m <- matrix(NA_integer_, nrow = length(ids), ncol = length(loci),
              dimnames = list(ids, loci))

  for (lo in loci) {
    codes <- allele_codes[[lo]]
    sub <- haplo_data[haplo_data$locus == lo, ]
    for (ind in ids) {
      rows <- sub[sub$id == ind, ]
      if (nrow(rows) == 0L) next
      rank1 <- rows$haplo[rows$rank == 1L][1L]
      rank2_vals <- rows$haplo[rows$rank == 2L]
      rank2 <- if (length(rank2_vals) > 0L) rank2_vals[1L] else rank1
      code1 <- codes[[rank1]]
      code2 <- codes[[rank2]]
      m[ind, lo] <- as.integer(code1 * 100L + code2)
    }
  }

  list(matrix = m, allele_codes = allele_codes)
}

#' Encode haplo_data as a one-hot dosage matrix (individuals x haplotype-columns).
#'
#' Column names follow `locus__haplo`. Column-mean imputation fills NA cells
#' left by individuals absent at a locus. Loci with 100% missing data are
#' dropped with a warning.
#'
#' @param haplo_data data.frame with columns group, id, locus, haplo, rank.
#' @return numeric matrix (individuals x locus__haplo columns).
#' @export
encode_onehot <- function(haplo_data) {
  ids  <- sort(unique(haplo_data$id))
  loci <- sort(unique(haplo_data$locus))

  fully_missing_loci <- character(0)
  col_specs <- do.call(rbind, lapply(loci, function(lo) {
    haplos <- sort(unique(stats::na.omit(haplo_data$haplo[haplo_data$locus == lo])))
    if (length(haplos) == 0L) {
      fully_missing_loci[length(fully_missing_loci) + 1L] <<- lo
      return(NULL)
    }
    data.frame(locus = lo, haplo = haplos, stringsAsFactors = FALSE)
  }))
  if (length(fully_missing_loci) > 0L) {
    warning(sprintf(
      "encode_onehot: locus/loci with 100%% missing data dropped: %s",
      paste(fully_missing_loci, collapse = ", ")
    ))
  }
  loci <- setdiff(loci, fully_missing_loci)
  col_names <- paste(col_specs$locus, col_specs$haplo, sep = "__")

  m <- matrix(NA_real_, nrow = length(ids), ncol = length(col_names),
              dimnames = list(ids, col_names))

  for (lo in loci) {
    sub <- haplo_data[haplo_data$locus == lo, ]
    for (ind in ids) {
      rows <- sub[sub$id == ind, ]
      if (nrow(rows) == 0L) next
      rank1 <- rows$haplo[rows$rank == 1L][1L]
      rank2_vals <- rows$haplo[rows$rank == 2L]
      rank2 <- if (length(rank2_vals) > 0L) rank2_vals[1L] else rank1
      for (h in c(rank1, rank2)) {
        col <- paste(lo, h, sep = "__")
        val <- m[ind, col]
        m[ind, col] <- if (is.na(val)) 1 else val + 1
      }
      # Any haplotype at this locus not carried by the individual is 0, not NA.
      locus_cols <- col_names[col_specs$locus == lo]
      zero_cols <- setdiff(locus_cols, c(paste(lo, rank1, sep = "__"), paste(lo, rank2, sep = "__")))
      for (col in zero_cols) if (is.na(m[ind, col])) m[ind, col] <- 0
    }
  }

  # Column-mean imputation (Price et al. 2006) for remaining NA cells.
  for (j in seq_len(ncol(m))) {
    col_mean <- mean(m[, j], na.rm = TRUE)
    na_rows <- is.na(m[, j])
    if (any(na_rows)) m[na_rows, j] <- col_mean
  }

  m
}
