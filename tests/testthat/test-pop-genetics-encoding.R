library(testthat)

# ---- fixture -----------------------------------------------------------------

# Three individuals, two loci.
make_hierfstat_data <- function() {
  data.frame(
    group = c("A","A","A","A","A","A"),
    id    = c("i1","i1","i2","i3","i1","i2"),
    locus = c("L1","L1","L1","L1","L2","L2"),
    haplo = c("AC","GT","AC","GT","TT","TT"),
    depth = 100,
    allele.balance = 1.0,
    rank  = c(1,2,1,1,1,1),
    stringsAsFactors = FALSE
  )
}

# Multi-allelic locus with 3 distinct haplotypes across 3 individuals.
make_multiallelic_data <- function() {
  data.frame(
    group = "A",
    id    = c("i1","i1","i2","i3"),
    locus = "L1",
    haplo = c("AC","GT","TT","TT"),
    depth = 100,
    allele.balance = 1.0,
    rank  = c(1,2,1,1),
    stringsAsFactors = FALSE
  )
}

# Individual absent at L2 entirely (i3 has no L2 rows).
make_missing_individual_data <- function() {
  data.frame(
    group = "A",
    id    = c("i1","i2","i3","i1","i2"),
    locus = c("L1","L1","L1","L2","L2"),
    haplo = c("AC","AC","GT","TT","TT"),
    depth = 100,
    allele.balance = 1.0,
    rank  = 1,
    stringsAsFactors = FALSE
  )
}

# ---- Cycle 1: encode_hierfstat — structure ----------------------------------

test_that("encode_hierfstat returns a list with $matrix and $allele_codes", {
  res <- encode_hierfstat(make_hierfstat_data())

  expect_type(res, "list")
  expect_true(all(c("matrix", "allele_codes") %in% names(res)))
  expect_equal(dim(res$matrix), c(3L, 2L))
  expect_equal(rownames(res$matrix), c("i1", "i2", "i3"))
  expect_equal(colnames(res$matrix), c("L1", "L2"))
})

# ---- Cycle 2: encode_hierfstat — homozygous diplotype -----------------------

test_that("encode_hierfstat produces two identical allele codes for a homozygous individual", {
  res <- encode_hierfstat(make_hierfstat_data())

  # i2 is AC/AC at L1 -> both codes identical
  ac_code <- res$allele_codes$L1[["AC"]]
  expected_cell <- ac_code * 100L + ac_code
  expect_equal(res$matrix["i2", "L1"], expected_cell)
})

# ---- Cycle 3: encode_hierfstat — multi-allelic locus ------------------------

test_that("encode_hierfstat assigns distinct integer codes to 3+ haplotypes at a locus", {
  res <- encode_hierfstat(make_multiallelic_data())

  codes <- res$allele_codes$L1
  expect_equal(length(codes), 3L)
  expect_equal(sort(unname(codes)), 1:3)

  # i1 is AC/GT (het)
  expect_equal(res$matrix["i1", "L1"], codes[["AC"]] * 100L + codes[["GT"]])
})

# ---- Cycle 4: encode_hierfstat — missing individual at a locus -------------

test_that("encode_hierfstat produces NA for individuals absent at a locus", {
  res <- encode_hierfstat(make_missing_individual_data())

  expect_true(is.na(res$matrix["i3", "L2"]))
  expect_false(is.na(res$matrix["i1", "L2"]))
})

# ---- Cycle 5: encode_onehot — structure and value domain -------------------

test_that("encode_onehot returns a numeric matrix with values in {0,1,2}", {
  m <- encode_onehot(make_hierfstat_data())

  expect_true(is.matrix(m))
  expect_true(is.numeric(m))
  expect_true(all(m %in% c(0, 1, 2)))
  expect_equal(rownames(m), c("i1", "i2", "i3"))
})

# ---- Cycle 6: encode_onehot — column naming convention ---------------------

test_that("encode_onehot column names follow the locus__haplo convention", {
  m <- encode_onehot(make_hierfstat_data())

  expect_true(all(c("L1__AC", "L1__GT", "L2__TT") %in% colnames(m)))
})

# ---- Cycle 7: encode_onehot — single-haplotype locus produces one column ---

test_that("encode_onehot produces a single column for a locus with one haplotype", {
  m <- encode_onehot(make_hierfstat_data())

  l2_cols <- grep("^L2__", colnames(m), value = TRUE)
  expect_equal(l2_cols, "L2__TT")
})

# ---- Cycle 8: encode_onehot — row sums to 2 * n_loci before imputation -----

test_that("encode_onehot row sums equal 2 * number of loci when no data is missing", {
  m <- encode_onehot(make_hierfstat_data())

  expect_equal(unname(rowSums(m)), rep(2 * 2, 3))
})

# ---- Cycle 9: encode_onehot — dosage correctness ---------------------------

test_that("encode_onehot dosage reflects diplotype copy count", {
  m <- encode_onehot(make_hierfstat_data())

  # i1 is AC/GT at L1 -> 1 copy each
  expect_equal(unname(m["i1", "L1__AC"]), 1)
  expect_equal(unname(m["i1", "L1__GT"]), 1)
  # i2 is AC/AC at L1 -> 2 copies of AC, 0 of GT
  expect_equal(unname(m["i2", "L1__AC"]), 2)
  expect_equal(unname(m["i2", "L1__GT"]), 0)
})

# ---- Cycle 10: encode_onehot — column-mean imputation for missing rows -----

test_that("encode_onehot imputes NA cells with the column mean", {
  m <- encode_onehot(make_missing_individual_data())

  # i3 is absent at L2 -> NA before imputation, filled with mean of i1/i2 (both 2)
  expect_false(anyNA(m))
  expect_equal(unname(m["i3", "L2__TT"]), 2)
})

# ---- Cycle 11: encode_onehot — 100%-missing locus dropped with a warning ---

test_that("encode_onehot drops a locus with 100% missing data and warns", {
  # L2 has a row for every individual but every genotype call failed (NA haplo)
  # -> no valid haplotype is ever observed at L2, so it is 100% missing.
  d2 <- data.frame(
    group = "A",
    id    = c("i1","i2","i3","i1","i2","i3"),
    locus = c("L1","L1","L1","L2","L2","L2"),
    haplo = c("AC","AC","GT", NA_character_, NA_character_, NA_character_),
    depth = 100,
    allele.balance = 1.0,
    rank  = 1,
    stringsAsFactors = FALSE
  )

  expect_warning(m <- encode_onehot(d2), "100%|missing")
  expect_false(any(grepl("^L2__", colnames(m))))
})
