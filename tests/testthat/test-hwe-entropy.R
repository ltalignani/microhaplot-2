library(testthat)
source(here::here("app/R/hwe_entropy.R"))

# ---- fixture -----------------------------------------------------------------

make_hwe_data <- function() {
  data.frame(
    group          = c("A","A","A","A","A","A","B"),
    id             = c("i1","i1","i2","i3","i4","i4","i5"),
    locus          = rep("L1", 7),
    haplo          = c("AC","GT","AC","AC","AC","GT","GT"),
    depth          = c(100, 50, 80, 90, 70, 60, 100),
    allele.balance = c(1.0, 0.5,1.0,1.0,1.0, 0.5,1.0),
    rank           = c(1,   2,   1,  1,  1,   2,  1  ),
    stringsAsFactors = FALSE
  )
}

# At L1:
#   i1: rank1=AC, rank2=GT  → diplotype AC/GT (het)
#   i2: rank1=AC             → diplotype AC/AC (hom)
#   i3: rank1=AC             → diplotype AC/AC (hom)
#   i4: rank1=AC, rank2=GT  → diplotype AC/GT (het)
#   i5: rank1=GT             → diplotype GT/GT (hom)
#
# Allele counts from diploid (2*5=10 alleles):
#   AC: i1(1)+i2(2)+i3(2)+i4(1)+i5(0) = 6  →  p_AC = 0.6
#   GT: i1(1)+i2(0)+i3(0)+i4(1)+i5(2) = 4  →  p_GT = 0.4
#
# Observed diplotype freqs (N=5):
#   AC/GT = 2/5 = 0.4
#   AC/AC = 2/5 = 0.4
#   GT/GT = 1/5 = 0.2
#
# Expected HWE:
#   AC/AC = 0.6^2          = 0.36
#   AC/GT = 2 * 0.6 * 0.4 = 0.48
#   GT/GT = 0.4^2          = 0.16
#
# Shannon entropy: -(0.6*log2(0.6) + 0.4*log2(0.4)) ≈ 0.971 bits

# ---- Cycle 1: shannon_entropy_per_locus — structure -------------------------

test_that("shannon_entropy_per_locus returns data.frame with locus and entropy", {
  tbl <- shannon_entropy_per_locus(make_hwe_data())

  expect_s3_class(tbl, "data.frame")
  expect_true(all(c("locus", "entropy") %in% names(tbl)))
  expect_equal(nrow(tbl), 1L)   # one locus in fixture
})

# ---- Cycle 2: shannon_entropy_per_locus — uniform distribution → H = 1 -----

test_that("shannon_entropy_per_locus returns 1.0 for two equal-frequency alleles", {
  d <- data.frame(
    locus = "L1", id = c("i1","i2"), rank = 1L,
    haplo = c("AC","GT"), group = "A",
    depth = 1L, allele.balance = 1.0,
    stringsAsFactors = FALSE
  )
  tbl <- shannon_entropy_per_locus(d)

  expect_equal(tbl$entropy[tbl$locus == "L1"], 1.0, tolerance = 1e-9)
})

# ---- Cycle 3: shannon_entropy_per_locus — single allele → H = 0 ------------

test_that("shannon_entropy_per_locus returns 0 when all haplotypes are identical", {
  d <- data.frame(
    locus = "L1", id = c("i1","i2","i3"), rank = 1L,
    haplo = "AC", group = "A",
    depth = 1L, allele.balance = 1.0,
    stringsAsFactors = FALSE
  )
  tbl <- shannon_entropy_per_locus(d)

  expect_equal(tbl$entropy[tbl$locus == "L1"], 0.0, tolerance = 1e-9)
})

# ---- Cycle 4: shannon_entropy_per_locus — known values ----------------------

test_that("shannon_entropy_per_locus computes correct entropy for known frequencies", {
  tbl <- shannon_entropy_per_locus(make_hwe_data())
  expected_H <- -(0.6 * log2(0.6) + 0.4 * log2(0.4))

  expect_equal(tbl$entropy[tbl$locus == "L1"], expected_H, tolerance = 1e-9)
})

# ---- Cycle 5: shannon_entropy_per_locus — multiple loci ---------------------

test_that("shannon_entropy_per_locus returns one row per locus", {
  d <- rbind(
    make_hwe_data(),
    data.frame(group="A", id="j1", locus="L2", haplo="TT",
               depth=50L, allele.balance=1.0, rank=1L,
               stringsAsFactors=FALSE)
  )
  tbl <- shannon_entropy_per_locus(d)

  expect_equal(nrow(tbl), 2L)
  expect_equal(sort(tbl$locus), c("L1","L2"))
  expect_equal(tbl$entropy[tbl$locus == "L2"], 0.0, tolerance = 1e-9)
})

# ---- Cycle 6: haplo_freq_tbl — structure ------------------------------------

test_that("haplo_freq_tbl returns data.frame with required columns", {
  tbl <- haplo_freq_tbl(make_hwe_data())

  expect_s3_class(tbl, "data.frame")
  expect_true(all(c("locus","haplotype.1","haplotype.2",
                    "obs.freq","expected.freq") %in% names(tbl)))
})

# ---- Cycle 7: haplo_freq_tbl — obs.freq sums to 1 --------------------------

test_that("haplo_freq_tbl obs.freq sums to 1 per locus", {
  tbl <- haplo_freq_tbl(make_hwe_data())

  for (loc in unique(tbl$locus)) {
    expect_equal(sum(tbl$obs.freq[tbl$locus == loc]), 1.0, tolerance = 1e-9)
  }
})

# ---- Cycle 8: haplo_freq_tbl — expected.freq sums to 1 ---------------------

test_that("haplo_freq_tbl expected.freq sums to 1 per locus", {
  tbl <- haplo_freq_tbl(make_hwe_data())

  for (loc in unique(tbl$locus)) {
    expect_equal(sum(tbl$expected.freq[tbl$locus == loc]), 1.0, tolerance = 1e-9)
  }
})

# ---- Cycle 9: haplo_freq_tbl — known obs.freq values -----------------------

test_that("haplo_freq_tbl computes correct observed diplotype frequencies", {
  tbl <- haplo_freq_tbl(make_hwe_data())
  l1  <- tbl[tbl$locus == "L1", ]

  obs_ac_gt <- l1$obs.freq[l1$haplotype.1 == "AC" & l1$haplotype.2 == "GT"]
  obs_ac_ac <- l1$obs.freq[l1$haplotype.1 == "AC" & l1$haplotype.2 == "AC"]
  obs_gt_gt <- l1$obs.freq[l1$haplotype.1 == "GT" & l1$haplotype.2 == "GT"]

  expect_equal(obs_ac_gt, 0.4, tolerance = 1e-9)
  expect_equal(obs_ac_ac, 0.4, tolerance = 1e-9)
  expect_equal(obs_gt_gt, 0.2, tolerance = 1e-9)
})

# ---- Cycle 10: haplo_freq_tbl — known expected.freq values -----------------

test_that("haplo_freq_tbl computes correct HWE expected frequencies", {
  tbl <- haplo_freq_tbl(make_hwe_data())
  l1  <- tbl[tbl$locus == "L1", ]

  exp_ac_ac <- l1$expected.freq[l1$haplotype.1 == "AC" & l1$haplotype.2 == "AC"]
  exp_ac_gt <- l1$expected.freq[l1$haplotype.1 == "AC" & l1$haplotype.2 == "GT"]
  exp_gt_gt <- l1$expected.freq[l1$haplotype.1 == "GT" & l1$haplotype.2 == "GT"]

  expect_equal(exp_ac_ac, 0.36, tolerance = 1e-9)
  expect_equal(exp_ac_gt, 0.48, tolerance = 1e-9)
  expect_equal(exp_gt_gt, 0.16, tolerance = 1e-9)
})

# ---- Cycle 11: haplo_freq_tbl — canonical ordering -------------------------

test_that("haplo_freq_tbl canonical haplotype.1 <= haplotype.2 in each row", {
  tbl <- haplo_freq_tbl(make_hwe_data())

  expect_true(all(tbl$haplotype.1 <= tbl$haplotype.2))
})
