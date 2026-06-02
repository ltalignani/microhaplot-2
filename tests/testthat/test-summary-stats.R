library(testthat)
source(here::here("app/R/summary_stats.R"))

# ---- fixture -----------------------------------------------------------------

make_haplo_data <- function() {
  data.frame(
    group          = c("A",  "A",  "A",  "B",  "B" ),
    id             = c("i1", "i1", "i2", "i3", "i3"),
    locus          = c("L1", "L1", "L1", "L1", "L2"),
    haplo          = c("AC", "GT", "AC", "CC", "AA"),
    depth          = c(100L, 50L,  80L,  90L,  70L ),
    allele.balance = c(1.0,  0.5,  1.0,  1.0,  1.0 ),
    rank           = c(1L,   2L,   1L,   1L,   1L  ),
    stringsAsFactors = FALSE
  )
}

# fixture: i1 group A at L1 (2 haplos: AC+GT, depth 150 total)
#           i2 group A at L1 (1 haplo:  AC,    depth  80 total)
#           i3 group B at L1 (1 haplo:  CC,    depth  90 total)
#           i3 group B at L2 (1 haplo:  AA,    depth  70 total)
# Total individuals = 3 (i1, i2, i3), total loci = 2 (L1, L2)

# ---- Cycle 1: haplo_density_tbl ----------------------------------------------

test_that("haplo_density_tbl returns per-locus bubble-chart data", {
  tbl <- haplo_density_tbl(make_haplo_data())

  expect_s3_class(tbl, "data.frame")
  expect_true(all(c("locus", "tot_hapl", "ct", "frac") %in% names(tbl)))
})

test_that("haplo_density_tbl counts individuals per haplo-count per locus", {
  tbl <- haplo_density_tbl(make_haplo_data())

  # L1 has 3 individuals: i1 with 2 haplos, i2 and i3 each with 1
  l1 <- tbl[tbl$locus == "L1", ]
  expect_equal(l1$ct[l1$tot_hapl == 1L], 2L)
  expect_equal(l1$ct[l1$tot_hapl == 2L], 1L)
})

test_that("haplo_density_tbl fractions sum to 1 per locus", {
  tbl <- haplo_density_tbl(make_haplo_data())

  for (loc in unique(tbl$locus)) {
    expect_equal(sum(tbl$frac[tbl$locus == loc]), 1.0, tolerance = 1e-9)
  }
})

# ---- Cycle 2: uniq_haplo_per_locus ------------------------------------------

test_that("uniq_haplo_per_locus returns one row per locus", {
  tbl <- uniq_haplo_per_locus(make_haplo_data())

  expect_s3_class(tbl, "data.frame")
  expect_true(all(c("locus", "n_uniq_haplo") %in% names(tbl)))
  expect_equal(nrow(tbl), 2L)
})

test_that("uniq_haplo_per_locus counts distinct haplotypes across all individuals", {
  tbl <- uniq_haplo_per_locus(make_haplo_data())

  # L1 unique haplos: AC, GT, CC → 3
  expect_equal(tbl$n_uniq_haplo[tbl$locus == "L1"], 3L)
  # L2 unique haplos: AA → 1
  expect_equal(tbl$n_uniq_haplo[tbl$locus == "L2"], 1L)
})

# ---- Cycle 3: frac_callable_by_locus ----------------------------------------

test_that("frac_callable_by_locus returns per-locus callable fraction", {
  tbl <- frac_callable_by_locus(make_haplo_data(), n_indiv = 3L)

  expect_s3_class(tbl, "data.frame")
  expect_true(all(c("locus", "n_callable", "frac") %in% names(tbl)))
})

test_that("frac_callable_by_locus computes correct fractions", {
  tbl <- frac_callable_by_locus(make_haplo_data(), n_indiv = 3L)

  # L1: i1, i2, i3 all present → 3/3 = 1.0
  expect_equal(tbl$frac[tbl$locus == "L1"], 1.0)
  # L2: only i3 present → 1/3
  expect_equal(tbl$frac[tbl$locus == "L2"], 1/3, tolerance = 1e-9)
})

# ---- Cycle 4: read_depth_by_locus -------------------------------------------

test_that("read_depth_by_locus returns depth per individual per locus", {
  tbl <- read_depth_by_locus(make_haplo_data())

  expect_s3_class(tbl, "data.frame")
  expect_true(all(c("locus", "id", "group", "tot_depth") %in% names(tbl)))
})

test_that("read_depth_by_locus sums depth across haplotypes for each id×locus", {
  tbl <- read_depth_by_locus(make_haplo_data())

  # i1 at L1: depth 100 + 50 = 150
  expect_equal(tbl$tot_depth[tbl$id == "i1" & tbl$locus == "L1"], 150L)
  # i2 at L1: depth 80
  expect_equal(tbl$tot_depth[tbl$id == "i2" & tbl$locus == "L1"], 80L)
  # i3 at L2: depth 70
  expect_equal(tbl$tot_depth[tbl$id == "i3" & tbl$locus == "L2"], 70L)
})

# ---- Cycle 5: allele_balance_by_indiv ----------------------------------------

test_that("allele_balance_by_indiv returns allele.balance per read per id", {
  tbl <- allele_balance_by_indiv(make_haplo_data())

  expect_s3_class(tbl, "data.frame")
  expect_true(all(c("id", "group", "locus", "allele.balance", "depth") %in% names(tbl)))
})

test_that("allele_balance_by_indiv filters by min_ar", {
  tbl_all <- allele_balance_by_indiv(make_haplo_data(), min_ar = 0)
  tbl_hi  <- allele_balance_by_indiv(make_haplo_data(), min_ar = 0.9)

  # With min_ar=0.9, the rank-2 row (ar=0.5) for i1/L1 should be excluded
  expect_true(nrow(tbl_all) > nrow(tbl_hi))
  expect_true(all(tbl_hi$allele.balance >= 0.9))
})

# ---- Cycle 6: haplo_counts_by_indiv -----------------------------------------

test_that("haplo_counts_by_indiv returns per-individual haplo-count distribution", {
  tbl <- haplo_counts_by_indiv(make_haplo_data())

  expect_s3_class(tbl, "data.frame")
  expect_true(all(c("id", "n_hap_locus", "n_locus") %in% names(tbl)))
})

test_that("haplo_counts_by_indiv counts loci with each haplo-count per individual", {
  tbl <- haplo_counts_by_indiv(make_haplo_data())

  # i1 has: L1→2 haplos. (L2 not present for i1 in fixture)
  i1 <- tbl[tbl$id == "i1", ]
  expect_equal(i1$n_locus[i1$n_hap_locus == 2L], 1L)

  # i3 has: L1→1 haplo, L2→1 haplo → n_hap_locus=1, n_locus=2
  i3 <- tbl[tbl$id == "i3", ]
  expect_equal(i3$n_locus[i3$n_hap_locus == 1L], 2L)
})

# ---- Cycle 7: frac_callable_by_indiv ----------------------------------------

test_that("frac_callable_by_indiv returns per-individual callable fraction", {
  tbl <- frac_callable_by_indiv(make_haplo_data(), n_loci = 2L)

  expect_s3_class(tbl, "data.frame")
  expect_true(all(c("id", "group", "n_callable_loci", "frac_callable") %in% names(tbl)))
})

test_that("frac_callable_by_indiv computes correct fractions", {
  tbl <- frac_callable_by_indiv(make_haplo_data(), n_loci = 2L)

  # i1: present at L1 only → 1/2 = 0.5
  expect_equal(tbl$frac_callable[tbl$id == "i1"], 0.5)
  # i2: present at L1 only → 1/2 = 0.5
  expect_equal(tbl$frac_callable[tbl$id == "i2"], 0.5)
  # i3: present at L1 and L2 → 2/2 = 1.0
  expect_equal(tbl$frac_callable[tbl$id == "i3"], 1.0)
})

# ---- Cycle 8: plot functions return ggplot objects --------------------------

test_that("plot_haplo_density returns a ggplot object", {
  tbl  <- haplo_density_tbl(make_haplo_data())
  loci <- c("L1", "L2")
  p    <- plot_haplo_density(tbl, loci_subset = loci)
  expect_s3_class(p, "ggplot")
})

test_that("plot_uniq_haplo_per_locus returns a ggplot object", {
  tbl  <- uniq_haplo_per_locus(make_haplo_data())
  loci <- c("L1", "L2")
  p    <- plot_uniq_haplo_per_locus(tbl, loci_subset = loci)
  expect_s3_class(p, "ggplot")
})

test_that("plot_frac_callable_indiv returns a ggplot object", {
  tbl  <- frac_callable_by_locus(make_haplo_data(), n_indiv = 3L)
  loci <- c("L1", "L2")
  p    <- plot_frac_callable_indiv(tbl, loci_subset = loci)
  expect_s3_class(p, "ggplot")
})

test_that("plot_read_depth_violin returns a ggplot object", {
  tbl  <- read_depth_by_locus(make_haplo_data())
  loci <- c("L1", "L2")
  p    <- plot_read_depth_violin(tbl, loci_subset = loci)
  expect_s3_class(p, "ggplot")
})

test_that("plot_allele_balance_by_indiv returns a ggplot object", {
  tbl   <- allele_balance_by_indiv(make_haplo_data())
  indiv <- c("i1", "i2", "i3")
  p     <- plot_allele_balance_by_indiv(tbl, indiv_subset = indiv)
  expect_s3_class(p, "ggplot")
})

test_that("plot_uniq_haplo_by_indiv returns a ggplot object", {
  tbl   <- haplo_counts_by_indiv(make_haplo_data())
  indiv <- c("i1", "i2", "i3")
  p     <- plot_uniq_haplo_by_indiv(tbl, indiv_subset = indiv)
  expect_s3_class(p, "ggplot")
})

test_that("plot_frac_callable_loci_by_indiv returns a ggplot object", {
  tbl   <- frac_callable_by_indiv(make_haplo_data(), n_loci = 2L)
  indiv <- c("i1", "i2", "i3")
  p     <- plot_frac_callable_loci_by_indiv(tbl, indiv_subset = indiv)
  expect_s3_class(p, "ggplot")
})

test_that("no plot function uses deprecated ggplot2 guide=FALSE", {
  tbl_locus <- haplo_density_tbl(make_haplo_data())
  tbl_uniq  <- uniq_haplo_per_locus(make_haplo_data())
  tbl_frac  <- frac_callable_by_locus(make_haplo_data(), n_indiv = 3L)
  tbl_depth <- read_depth_by_locus(make_haplo_data())
  tbl_ab    <- allele_balance_by_indiv(make_haplo_data())
  tbl_hc    <- haplo_counts_by_indiv(make_haplo_data())
  tbl_fcl   <- frac_callable_by_indiv(make_haplo_data(), n_loci = 2L)
  loci      <- c("L1", "L2")
  indiv     <- c("i1", "i2", "i3")

  # None of the plots should generate deprecation warnings from ggplot2
  expect_no_warning(plot_haplo_density(tbl_locus, loci))
  expect_no_warning(plot_uniq_haplo_per_locus(tbl_uniq, loci))
  expect_no_warning(plot_frac_callable_indiv(tbl_frac, loci))
  expect_no_warning(plot_read_depth_violin(tbl_depth, loci))
  expect_no_warning(plot_allele_balance_by_indiv(tbl_ab, indiv))
  expect_no_warning(plot_uniq_haplo_by_indiv(tbl_hc, indiv))
  expect_no_warning(plot_frac_callable_loci_by_indiv(tbl_fcl, indiv))
})
