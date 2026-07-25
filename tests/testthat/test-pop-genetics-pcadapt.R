library(testthat)

# ---- fixture -----------------------------------------------------------------

make_onehot <- function() {
  set.seed(7)
  m <- matrix(sample(0:2, 20 * 8, replace = TRUE), nrow = 20, ncol = 8)
  rownames(m) <- paste0("i", 1:20)
  colnames(m) <- paste0("L", rep(1:4, each = 2), "__", c("A", "B"))
  storage.mode(m) <- "double"
  m
}

# ---- Cycle 1: run_pcadapt_scan returns a pcadapt result with per-column pvalues

test_that("run_pcadapt_scan returns pcadapt result with one pvalue per column", {
  m <- make_onehot()
  res <- suppressWarnings(run_pcadapt_scan(m, K = 2))

  expect_true(!is.null(res$pvalues))
  expect_equal(length(res$pvalues), ncol(m))
})

# ---- Cycle 2: locus_names_from_onehot strips everything after "__" ----------

test_that("locus_names_from_onehot strips the __haplo suffix", {
  cols <- c("L1__A", "L1__B", "L2__A", "L23__CC")
  expect_equal(locus_names_from_onehot(cols), c("L1", "L1", "L2", "L23"))
})

# ---- Cycle 3: get_outliers_bh returns locus/pvalue/padj/outlier columns -----

test_that("get_outliers_bh returns a data.frame with locus, pvalue, padj, outlier", {
  m <- make_onehot()
  res <- suppressWarnings(run_pcadapt_scan(m, K = 2))
  loci <- locus_names_from_onehot(colnames(m))

  out <- get_outliers_bh(res, loci, alpha = 0.1)

  expect_named(out, c("locus", "pvalue", "padj", "outlier"))
  expect_equal(nrow(out), length(unique(loci)))
  expect_type(out$outlier, "logical")
})

# ---- Cycle 4: get_outliers_bh takes the min pvalue per locus ----------------

test_that("get_outliers_bh reduces to one row per locus via minimum pvalue", {
  fake_res <- list(pvalues = c(0.5, 0.01, 0.2, 0.9))
  loci <- c("L1", "L1", "L2", "L2")

  out <- get_outliers_bh(fake_res, loci, alpha = 0.1)

  expect_equal(out$locus, c("L1", "L2"))
  expect_equal(out$pvalue, c(0.01, 0.2))
})

# ---- Cycle 4b: get_outliers_bh ignores NA pvalues within a locus -----------
# pcadapt sets a column's pvalue to NA when it fails the min.maf filter; a
# locus with several one-hot columns is only ever fully excluded if EVERY
# column for it was filtered, not just one.

test_that("get_outliers_bh takes the min of the non-NA pvalues within a locus", {
  fake_res <- list(pvalues = c(NA, 0.02, 0.3, NA))
  loci <- c("L1", "L1", "L2", "L2")

  out <- get_outliers_bh(fake_res, loci, alpha = 0.1)

  # L1 = [NA, 0.02] -> 0.02 (NA ignored); L2 = [0.3, NA] -> 0.3 (NA ignored)
  expect_equal(out$pvalue, c(0.02, 0.3))
})

test_that("get_outliers_bh returns NA for a locus whose every column pvalue is NA", {
  fake_res <- list(pvalues = c(NA, NA, 0.3, 0.4))
  loci <- c("L1", "L1", "L2", "L2")

  out <- get_outliers_bh(fake_res, loci, alpha = 0.1)

  expect_true(is.na(out$pvalue[out$locus == "L1"]))
  expect_false(is.na(out$pvalue[out$locus == "L2"]))
})

# ---- Cycle 5: alpha = 0 marks no outliers -----------------------------------

test_that("alpha = 0 marks no loci as outliers", {
  fake_res <- list(pvalues = c(1e-10, 0.5, 0.9))
  loci <- c("L1", "L2", "L3")

  out <- get_outliers_bh(fake_res, loci, alpha = 0)

  expect_false(any(out$outlier))
})

# ---- Cycle 6: alpha = 1 marks all loci as outliers --------------------------

test_that("alpha = 1 marks all loci as outliers", {
  fake_res <- list(pvalues = c(1e-10, 0.5, 0.9))
  loci <- c("L1", "L2", "L3")

  out <- get_outliers_bh(fake_res, loci, alpha = 1)

  expect_true(all(out$outlier))
})
