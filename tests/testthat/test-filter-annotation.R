library(testthat)
source(here::here("app/R/filter_annotation.R"))

# ---- fixture -----------------------------------------------------------------

make_haplo_data <- function() {
  data.frame(
    group          = c("A",  "A",  "A",  "A",  "B",  "B",  "B" ),
    id             = c("i1", "i1", "i2", "i2", "i3", "i3", "i3"),
    locus          = c("L1", "L1", "L1", "L1", "L1", "L1", "L2"),
    haplo          = c("AC", "GT", "AC", "TT", "CC", "GG", "AA"),
    depth          = c(100L, 50L,  80L,  5L,   90L,  3L,   70L ),
    allele.balance = c(0.67, 0.33, 0.94, 0.06, 0.97, 0.03, 1.0 ),
    rank           = c(1L,   2L,   1L,   2L,   1L,   2L,   1L  ),
    stringsAsFactors = FALSE
  )
}

# fixture layout:
# i1/L1: rank1=AC(depth=100, ar=0.67), rank2=GT(depth=50, ar=0.33)
# i2/L1: rank1=AC(depth=80,  ar=0.94), rank2=TT(depth=5,  ar=0.06)  ← TT fails min_rd and min_ar
# i3/L1: rank1=CC(depth=90,  ar=0.97), rank2=GG(depth=3,  ar=0.03)  ← GG fails both
# i3/L2: rank1=AA(depth=70,  ar=1.0)

# ---- Cycle 1: default_filter_params ------------------------------------------

test_that("default_filter_params returns a list with all required fields", {
  p <- default_filter_params()

  expect_type(p, "list")
  expect_true(all(c("min_rd", "min_ar", "n_alleles", "max_ar_hm", "min_ar_hz") %in% names(p)))
  expect_true(is.numeric(p$min_rd))
  expect_true(is.numeric(p$min_ar))
  expect_true(is.numeric(p$n_alleles))
})

# ---- Cycle 2: filter_by_rd_ar — min_rd ---------------------------------------

test_that("filter_by_rd_ar drops rows below min_rd", {
  params <- default_filter_params()
  params$min_rd <- 10L
  params$min_ar <- 0
  params$n_alleles <- 99L

  filtered <- filter_by_rd_ar(make_haplo_data(), params)

  # depth=5 (i2/L1 rank2) and depth=3 (i3/L1 rank2) should be dropped
  expect_true(all(filtered$depth >= 10L))
  expect_equal(nrow(filtered), 5L)
})

test_that("filter_by_rd_ar with min_rd=0 keeps all rows", {
  params <- default_filter_params()
  params$min_rd <- 0L
  params$min_ar <- 0
  params$n_alleles <- 99L

  filtered <- filter_by_rd_ar(make_haplo_data(), params)
  expect_equal(nrow(filtered), nrow(make_haplo_data()))
})

# ---- Cycle 3: filter_by_rd_ar — min_ar ---------------------------------------

test_that("filter_by_rd_ar drops rows below min_ar", {
  params <- default_filter_params()
  params$min_rd <- 0L
  params$min_ar <- 0.1
  params$n_alleles <- 99L

  filtered <- filter_by_rd_ar(make_haplo_data(), params)

  # ar=0.06 (i2/L1 rank2) and ar=0.03 (i3/L1 rank2) should be dropped
  expect_true(all(filtered$allele.balance >= 0.1))
  expect_equal(nrow(filtered), 5L)
})

# ---- Cycle 4: filter_by_rd_ar — n_alleles ------------------------------------

test_that("filter_by_rd_ar keeps at most n_alleles rows per id+locus", {
  params <- default_filter_params()
  params$min_rd <- 0L
  params$min_ar <- 0
  params$n_alleles <- 1L

  filtered <- filter_by_rd_ar(make_haplo_data(), params)

  # each (id, locus) combo should have at most 1 row
  counts <- table(paste(filtered$id, filtered$locus))
  expect_true(all(counts <= 1L))
})

test_that("filter_by_rd_ar n_alleles=1 keeps the rank-1 haplotype", {
  params <- default_filter_params()
  params$min_rd <- 0L
  params$min_ar <- 0
  params$n_alleles <- 1L

  filtered <- filter_by_rd_ar(make_haplo_data(), params)
  expect_true(all(filtered$rank == 1L))
})

# ---- Cycle 5: filter_by_rd_ar — combined filters + edge cases ----------------

test_that("filter_by_rd_ar combined min_rd and min_ar filters correctly", {
  params <- default_filter_params()
  params$min_rd <- 10L
  params$min_ar <- 0.1
  params$n_alleles <- 99L

  filtered <- filter_by_rd_ar(make_haplo_data(), params)
  expect_true(all(filtered$depth >= 10L))
  expect_true(all(filtered$allele.balance >= 0.1))
})

test_that("filter_by_rd_ar returns empty data.frame when all rows fail", {
  params <- default_filter_params()
  params$min_rd <- 9999L
  params$min_ar <- 0
  params$n_alleles <- 99L

  filtered <- filter_by_rd_ar(make_haplo_data(), params)
  expect_s3_class(filtered, "data.frame")
  expect_equal(nrow(filtered), 0L)
})

test_that("filter_by_rd_ar preserves all columns", {
  params <- default_filter_params()
  params$min_rd <- 0L
  params$min_ar <- 0
  params$n_alleles <- 99L

  filtered <- filter_by_rd_ar(make_haplo_data(), params)
  expect_true(all(names(make_haplo_data()) %in% names(filtered)))
})

# ---- Cycle 6: filter_summary -------------------------------------------------

test_that("filter_summary returns a data.frame with required columns", {
  params <- default_filter_params()
  params$min_rd <- 10L
  params$min_ar <- 0.1
  params$n_alleles <- 99L

  s <- filter_summary(make_haplo_data(), params)

  expect_s3_class(s, "data.frame")
  expect_true(all(c("locus", "n_before", "n_after", "n_removed", "callable") %in% names(s)))
})

test_that("filter_summary has one row per locus", {
  params <- default_filter_params()
  params$min_rd <- 0L
  params$min_ar <- 0
  params$n_alleles <- 99L

  s <- filter_summary(make_haplo_data(), params)
  expect_equal(nrow(s), 2L)  # L1 and L2
  expect_setequal(s$locus, c("L1", "L2"))
})

test_that("filter_summary n_before + n_removed equals original count", {
  params <- default_filter_params()
  params$min_rd <- 10L
  params$min_ar <- 0.1
  params$n_alleles <- 99L

  s <- filter_summary(make_haplo_data(), params)
  orig_per_locus <- table(make_haplo_data()$locus)

  for (loc in s$locus) {
    expect_equal(s$n_before[s$locus == loc], as.integer(orig_per_locus[loc]))
    expect_equal(s$n_before[s$locus == loc],
                 s$n_after[s$locus == loc] + s$n_removed[s$locus == loc])
  }
})

test_that("filter_summary callable is TRUE when locus has rows after filter", {
  params <- default_filter_params()
  params$min_rd <- 0L
  params$min_ar <- 0
  params$n_alleles <- 99L

  s <- filter_summary(make_haplo_data(), params)
  expect_true(all(s$callable))
})

test_that("filter_summary callable is FALSE when all rows removed", {
  params <- default_filter_params()
  params$min_rd <- 9999L
  params$min_ar <- 0
  params$n_alleles <- 99L

  s <- filter_summary(make_haplo_data(), params)
  expect_true(all(!s$callable))
})

# ---- Cycle 7: resolve_filter_params ------------------------------------------

test_that("resolve_filter_params mode='global' always returns global_params", {
  global <- list(min_rd = 10L, min_ar = 0.1, n_alleles = 2L,
                 max_ar_hm = 0.9, min_ar_hz = 0.3)
  local  <- list(min_rd = 5L,  min_ar = 0.05, n_alleles = 3L,
                 max_ar_hm = 0.8, min_ar_hz = 0.2)

  resolved <- resolve_filter_params("L1", global, local, mode = "global")
  expect_equal(resolved$min_rd, 10L)
  expect_equal(resolved$min_ar, 0.1)
  expect_equal(resolved$n_alleles, 2L)
})

test_that("resolve_filter_params mode='local' returns local params when available", {
  global <- list(min_rd = 10L, min_ar = 0.1, n_alleles = 2L,
                 max_ar_hm = 0.9, min_ar_hz = 0.3)
  local  <- list(min_rd = 5L,  min_ar = 0.05, n_alleles = 3L,
                 max_ar_hm = 0.8, min_ar_hz = 0.2)

  resolved <- resolve_filter_params("L1", global, local, mode = "local")
  expect_equal(resolved$min_rd, 5L)
  expect_equal(resolved$n_alleles, 3L)
})

test_that("resolve_filter_params mode='local' falls back to global when local is NULL", {
  global <- list(min_rd = 10L, min_ar = 0.1, n_alleles = 2L,
                 max_ar_hm = 0.9, min_ar_hz = 0.3)

  resolved <- resolve_filter_params("L1", global, NULL, mode = "local")
  expect_equal(resolved$min_rd, 10L)
})

test_that("resolve_filter_params mode='min_baseline' uses element-wise maximum", {
  global <- list(min_rd = 10L, min_ar = 0.1, n_alleles = 2L,
                 max_ar_hm = 0.9, min_ar_hz = 0.3)
  local  <- list(min_rd = 5L,  min_ar = 0.2, n_alleles = 3L,
                 max_ar_hm = 0.8, min_ar_hz = 0.2)

  # min_rd: max(10, 5) = 10; min_ar: max(0.1, 0.2) = 0.2; n_alleles: max(2, 3) = 3
  resolved <- resolve_filter_params("L1", global, local, mode = "min_baseline")
  expect_equal(resolved$min_rd, 10L)
  expect_equal(resolved$min_ar, 0.2)
  expect_equal(resolved$n_alleles, 3L)
})

# ---- Cycle 8: annotation save / load -----------------------------------------

test_that("save_annotation writes to session temp dir and load_annotation reads it back", {
  session_dir <- tempfile("session_")
  dir.create(session_dir)
  on.exit(unlink(session_dir, recursive = TRUE))

  save_annotation("L1", comment = "good locus", status = "Accept", session_dir)
  ann <- load_annotation("L1", session_dir)

  expect_equal(ann$comment, "good locus")
  expect_equal(ann$status, "Accept")
})

test_that("load_annotation returns NULL for unsaved locus", {
  session_dir <- tempfile("session_")
  dir.create(session_dir)
  on.exit(unlink(session_dir, recursive = TRUE))

  expect_null(load_annotation("L99", session_dir))
})

test_that("two sessions use separate dirs and do not overwrite each other", {
  dir1 <- tempfile("sess1_")
  dir2 <- tempfile("sess2_")
  dir.create(dir1)
  dir.create(dir2)
  on.exit({ unlink(dir1, recursive = TRUE); unlink(dir2, recursive = TRUE) })

  save_annotation("L1", "session 1 note", "Accept", dir1)
  save_annotation("L1", "session 2 note", "Reject", dir2)

  ann1 <- load_annotation("L1", dir1)
  ann2 <- load_annotation("L1", dir2)

  expect_equal(ann1$status, "Accept")
  expect_equal(ann2$status, "Reject")
  expect_equal(ann1$comment, "session 1 note")
  expect_equal(ann2$comment, "session 2 note")
})

test_that("load_all_annotations returns data.frame with all saved loci", {
  session_dir <- tempfile("session_")
  dir.create(session_dir)
  on.exit(unlink(session_dir, recursive = TRUE))

  save_annotation("L1", "ok",  "Accept", session_dir)
  save_annotation("L2", "bad", "Reject", session_dir)

  all_ann <- load_all_annotations(session_dir)

  expect_s3_class(all_ann, "data.frame")
  expect_true(all(c("locus", "comment", "status") %in% names(all_ann)))
  expect_setequal(all_ann$locus, c("L1", "L2"))
})

test_that("load_all_annotations returns empty data.frame when no annotations saved", {
  session_dir <- tempfile("session_")
  dir.create(session_dir)
  on.exit(unlink(session_dir, recursive = TRUE))

  all_ann <- load_all_annotations(session_dir)

  expect_s3_class(all_ann, "data.frame")
  expect_equal(nrow(all_ann), 0L)
})
