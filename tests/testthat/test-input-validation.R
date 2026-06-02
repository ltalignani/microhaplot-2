library(testthat)
source(here::here("app/R/input_validation.R"))

# ---- helpers ----------------------------------------------------------------

make_valid_meta <- function() {
  data.frame(
    bam_file      = c("s1.bam", "s2.bam"),
    individual_id = c("ind1", "ind2"),
    group         = c("pop_A", "pop_A"),
    stringsAsFactors = FALSE
  )
}

# ---- Cycle 1: csv_template --------------------------------------------------

test_that("csv_template returns a 0-row data.frame with required columns", {
  tpl <- csv_template()

  expect_s3_class(tpl, "data.frame")
  expect_equal(nrow(tpl), 0L)
  expect_named(tpl, c("bam_file", "individual_id", "group"))
})

# ---- Cycle 2: validate_metadata_csv — valid input ---------------------------

test_that("validate_metadata_csv accepts a valid metadata data.frame", {
  result <- validate_metadata_csv(make_valid_meta())

  expect_true(result$ok)
  expect_length(result$errors, 0L)
})

# ---- Cycle 3: validate_metadata_csv — missing column -----------------------

test_that("validate_metadata_csv reports missing bam_file column by name", {
  bad <- make_valid_meta()[, c("individual_id", "group")]
  result <- validate_metadata_csv(bad)

  expect_false(result$ok)
  expect_true(any(grepl("bam_file", result$errors)))
})

test_that("validate_metadata_csv reports missing individual_id column by name", {
  bad <- make_valid_meta()[, c("bam_file", "group")]
  result <- validate_metadata_csv(bad)

  expect_false(result$ok)
  expect_true(any(grepl("individual_id", result$errors)))
})

test_that("validate_metadata_csv reports missing group column by name", {
  bad <- make_valid_meta()[, c("bam_file", "individual_id")]
  result <- validate_metadata_csv(bad)

  expect_false(result$ok)
  expect_true(any(grepl("group", result$errors)))
})

# ---- Cycle 4: validate_metadata_csv — duplicate individual_id --------------

test_that("validate_metadata_csv rejects duplicate individual_id values", {
  dup <- make_valid_meta()
  dup$individual_id <- c("ind1", "ind1")
  result <- validate_metadata_csv(dup)

  expect_false(result$ok)
  expect_true(any(grepl("ind1", result$errors)))
})

# ---- helpers ----------------------------------------------------------------

make_bam_dir <- function(...) {
  dir <- tempfile("bam_dir_")
  dir.create(dir)
  for (f in c(...)) file.create(file.path(dir, f))
  dir
}

# ---- Cycle 5: resolve_bam_paths — all files present ------------------------

test_that("resolve_bam_paths succeeds when BAM and BAI files exist", {
  dir <- make_bam_dir("s1.bam", "s1.bam.bai", "s2.bam", "s2.bam.bai")

  result <- resolve_bam_paths(make_valid_meta(), data_dir = dir)

  expect_true(result$ok)
  expect_length(result$errors, 0L)
})

# ---- Cycle 6: resolve_bam_paths — missing BAM ------------------------------

test_that("resolve_bam_paths reports missing BAM file by name", {
  dir <- make_bam_dir("s1.bam", "s1.bam.bai")
  # s2.bam intentionally absent

  result <- resolve_bam_paths(make_valid_meta(), data_dir = dir)

  expect_false(result$ok)
  expect_true(any(grepl("s2.bam", result$errors)))
})

# ---- Cycle 7: resolve_bam_paths — missing BAI index ------------------------

test_that("resolve_bam_paths reports missing BAI index file by name", {
  dir <- make_bam_dir("s1.bam", "s1.bam.bai", "s2.bam")
  # s2.bam.bai intentionally absent

  result <- resolve_bam_paths(make_valid_meta(), data_dir = dir)

  expect_false(result$ok)
  expect_true(any(grepl("s2.bam.bai", result$errors)))
})

# ---- Cycle 8: MICROHAPLOT_DATA_DIR env var ----------------------------------

test_that("resolve_bam_paths uses MICROHAPLOT_DATA_DIR when data_dir is NULL", {
  dir <- make_bam_dir("s1.bam", "s1.bam.bai", "s2.bam", "s2.bam.bai")

  withr::with_envvar(c(MICROHAPLOT_DATA_DIR = dir), {
    result <- resolve_bam_paths(make_valid_meta(), data_dir = NULL)
  })

  expect_true(result$ok)
})

test_that("resolve_bam_paths defaults to /data/lovelace when env var unset and data_dir NULL", {
  withr::with_envvar(c(MICROHAPLOT_DATA_DIR = NA), {
    result <- resolve_bam_paths(make_valid_meta(), data_dir = NULL)
  })

  # /data/lovelace won't exist in test env — files are missing, not an error in resolve logic
  expect_false(result$ok)
  expect_true(any(grepl("s1.bam", result$errors)))
})
