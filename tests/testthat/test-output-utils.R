library(testthat)
source(here::here("app/R/output_utils.R"))

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

# After default filter (min_rd=10, min_ar=0.1, n_alleles=2):
# i1/L1: rank1=AC(100, 0.67), rank2=GT(50, 0.33)   — both pass
# i2/L1: rank1=AC(80, 0.94)                         — TT fails min_rd and min_ar
# i3/L1: rank1=CC(90, 0.97)                         — GG fails both
# i3/L2: rank1=AA(70, 1.0)
make_filtered_data <- function() {
  make_haplo_data()[c(1, 2, 3, 5, 7), ]
}

# ---- Cycle 1: make_filename ---------------------------------------------------

test_that("make_filename produces <label>_raw.csv for raw type", {
  expect_equal(make_filename("sebastes", "raw"), "sebastes_raw.csv")
})

test_that("make_filename produces <label>_filtered.csv for filtered type", {
  expect_equal(make_filename("sebastes", "filtered"), "sebastes_filtered.csv")
})

test_that("make_filename handles run labels with spaces by replacing with underscores", {
  expect_equal(make_filename("my run", "raw"), "my_run_raw.csv")
})

# ---- Cycle 2: select_fields --------------------------------------------------

test_that("select_fields keeps only specified columns", {
  df <- make_haplo_data()
  result <- select_fields(df, c("id", "locus", "haplo"))
  expect_equal(names(result), c("id", "locus", "haplo"))
})

test_that("select_fields preserves row count", {
  df <- make_haplo_data()
  result <- select_fields(df, c("id", "locus"))
  expect_equal(nrow(result), nrow(df))
})

test_that("select_fields returns all columns when fields is NULL", {
  df <- make_haplo_data()
  result <- select_fields(df, NULL)
  expect_equal(names(result), names(df))
})

test_that("select_fields returns all columns when fields is empty character", {
  df <- make_haplo_data()
  result <- select_fields(df, character(0))
  expect_equal(names(result), names(df))
})

# ---- Cycle 3: pivot_diploid — basic structure --------------------------------

test_that("pivot_diploid returns a data.frame with required diploid columns", {
  filtered <- make_filtered_data()
  result <- pivot_diploid(filtered)

  expect_s3_class(result, "data.frame")
  expect_true(all(c("group", "id", "locus",
                     "haplotype.1", "read.depth.1",
                     "haplotype.2", "read.depth.2",
                     "ar") %in% names(result)))
})

test_that("pivot_diploid returns one row per (id, locus)", {
  filtered <- make_filtered_data()
  result <- pivot_diploid(filtered)

  keys <- paste(result$id, result$locus)
  expect_equal(length(keys), length(unique(keys)))
})

# ---- Cycle 4: pivot_diploid — correct values ---------------------------------

test_that("pivot_diploid maps rank 1 to haplotype.1 and rank 2 to haplotype.2", {
  filtered <- make_filtered_data()
  result <- pivot_diploid(filtered)

  i1_L1 <- result[result$id == "i1" & result$locus == "L1", ]
  expect_equal(i1_L1$haplotype.1, "AC")
  expect_equal(i1_L1$haplotype.2, "GT")
  expect_equal(i1_L1$read.depth.1, 100L)
  expect_equal(i1_L1$read.depth.2, 50L)
})

test_that("pivot_diploid sets ar from rank-2 allele.balance", {
  filtered <- make_filtered_data()
  result <- pivot_diploid(filtered)

  i1_L1 <- result[result$id == "i1" & result$locus == "L1", ]
  expect_equal(i1_L1$ar, 0.33)
})

# ---- Cycle 5: pivot_diploid — missing rank 2 (homozygous / single haplotype) --

test_that("pivot_diploid fills NA for haplotype.2 when only rank 1 exists", {
  filtered <- make_filtered_data()
  result <- pivot_diploid(filtered)

  # i2/L1 has only rank 1 after filtering
  i2_L1 <- result[result$id == "i2" & result$locus == "L1", ]
  expect_true(is.na(i2_L1$haplotype.2))
  expect_true(is.na(i2_L1$read.depth.2))
  expect_true(is.na(i2_L1$ar))
})

test_that("pivot_diploid haplotype.1 is always non-NA when row exists", {
  filtered <- make_filtered_data()
  result <- pivot_diploid(filtered)
  expect_true(all(!is.na(result$haplotype.1)))
  expect_true(all(!is.na(result$read.depth.1)))
})
