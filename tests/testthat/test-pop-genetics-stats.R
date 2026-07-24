library(testthat)

# ---- fixtures -----------------------------------------------------------------

# Two groups, 5 individuals each, 2 loci — enough variation for real Fst.
make_two_group_data <- function() {
  ids_a <- paste0("a", 1:5)
  ids_b <- paste0("b", 1:5)
  data.frame(
    group = c(rep("popA", 10), rep("popB", 10)),
    id    = c(rep(ids_a, each = 2), rep(ids_b, each = 2)),
    locus = rep(c("L1", "L2"), times = 10),
    haplo = c(
      # popA, L1/L2 pairs per individual (a1..a5)
      "AC", "TT", "AC", "TT", "GT", "TT", "GT", "TT", "AC", "GG",
      # popB, L1/L2 pairs per individual (b1..b5)
      "GT", "GG", "GT", "GG", "AC", "GG", "GT", "GG", "GT", "TT"
    ),
    depth = 100,
    allele.balance = 1.0,
    rank = 1,
    stringsAsFactors = FALSE
  )
}

make_groups_vector <- function(haplo_data) {
  stats::setNames(haplo_data$group, haplo_data$id)[unique(haplo_data$id)]
}

# One group only (all popA) — Fst should be 0, Fis == Fit.
make_single_group_data <- function() {
  d <- make_two_group_data()
  d$group <- "popA"
  d
}

# Two perfectly differentiated groups: no shared haplotypes at any locus.
make_perfectly_differentiated_data <- function() {
  ids_a <- paste0("a", 1:4)
  ids_b <- paste0("b", 1:4)
  data.frame(
    group = c(rep("popA", 4), rep("popB", 4)),
    id    = c(ids_a, ids_b),
    locus = "L1",
    haplo = c(rep("AC", 4), rep("GT", 4)),
    depth = 100,
    allele.balance = 1.0,
    rank = 1,
    stringsAsFactors = FALSE
  )
}

# ---- Cycle 1: compute_fstats — returns all four list elements -----------------

test_that("compute_fstats returns basic, pairwise_fst, betas, allelic_richness for two groups", {
  d <- make_two_group_data()
  enc <- encode_hierfstat(d)
  res <- compute_fstats(enc, make_groups_vector(d))

  expect_type(res, "list")
  expect_true(all(c("basic", "pairwise_fst", "betas", "allelic_richness") %in% names(res)))
})

# ---- Cycle 2: single group -> Fst == 0 and Fis == Fit --------------------------

test_that("with a single group, Fst is 0 and Fis equals Fit", {
  d <- make_single_group_data()
  enc <- encode_hierfstat(d)
  res <- compute_fstats(enc, make_groups_vector(d))

  expect_equal(res$basic$overall[["Fst"]], 0)
  expect_equal(res$basic$overall[["Fis"]], res$basic$overall[["Fit"]])
})

# ---- Cycle 3: perfectly differentiated groups -> Fst approaches 1 -------------

test_that("two perfectly differentiated groups produce Fst near 1", {
  d <- make_perfectly_differentiated_data()
  enc <- encode_hierfstat(d)
  res <- compute_fstats(enc, make_groups_vector(d))

  expect_gt(res$basic$overall[["Fst"]], 0.9)
})

# ---- Cycle 4: pairwise_fst is square, symmetric, NA diagonal ------------------

test_that("pairwise_fst is a square symmetric matrix with NA on the diagonal", {
  d <- make_two_group_data()
  enc <- encode_hierfstat(d)
  res <- compute_fstats(enc, make_groups_vector(d))

  pw <- res$pairwise_fst
  expect_equal(nrow(pw), ncol(pw))
  expect_true(all(is.na(diag(pw))))
  offdiag <- pw
  diag(offdiag) <- 0
  expect_equal(offdiag, t(offdiag))
})

# ---- Cycle 5: allelic_richness rarefies to smallest group sample size ---------

test_that("allelic_richness rarefies to the smallest group sample size", {
  d <- make_two_group_data()
  # Drop one individual from popB so popA (5) > popB (4).
  d <- d[d$id != "b5", ]
  enc <- encode_hierfstat(d)
  res <- compute_fstats(enc, make_groups_vector(d))

  # min.all = 2 * smallest per-group sample size (diploid)
  expect_equal(res$allelic_richness$min.all, 2 * 4)
})

# ---- Cycle 6: betas has global betaW and per-locus values ---------------------

test_that("betas result has a global betaW and a per-locus data.frame", {
  d <- make_two_group_data()
  enc <- encode_hierfstat(d)
  res <- compute_fstats(enc, make_groups_vector(d))

  expect_true(is.numeric(res$betas$global))
  expect_true(all(c("L1", "L2") %in% rownames(res$betas$per_locus)))
  expect_true("betaW" %in% colnames(res$betas$per_locus))
})
