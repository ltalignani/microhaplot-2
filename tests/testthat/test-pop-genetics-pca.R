library(testthat)

# ---- fixture -----------------------------------------------------------------

make_onehot <- function() {
  set.seed(42)
  m <- matrix(sample(0:2, 8 * 6, replace = TRUE), nrow = 8, ncol = 6)
  rownames(m) <- paste0("i", 1:8)
  colnames(m) <- paste0("L", rep(1:3, each = 2), "__", c("A", "B"))
  storage.mode(m) <- "double"
  m
}

# ---- Cycle 1: run_pca — scores dimensions ------------------------------------

test_that("run_pca returns scores with n_individuals x K dimensions", {
  m <- make_onehot()
  res <- run_pca(m, K = 3)

  expect_equal(dim(res$scores), c(8L, 3L))
  expect_equal(rownames(res$scores), rownames(m))
})

# ---- Cycle 2: run_pca — pct_var sums to 100 ----------------------------------

test_that("run_pca pct_var sums to 100% when K covers all components", {
  m <- make_onehot()
  res <- run_pca(m, K = ncol(m))

  expect_equal(sum(res$pct_var), 100, tolerance = 1e-6)
})

# ---- Cycle 3: project_onto_pca — reference = all recovers joint scores ------

test_that("project_onto_pca with reference = all individuals recovers joint scores", {
  m <- make_onehot()
  res <- run_pca(m, K = 3)

  projected <- project_onto_pca(res, m)

  expect_equal(unname(projected), unname(res$scores), tolerance = 1e-6)
})

# ---- Cycle 4: project_onto_pca — drops absent columns with warning ----------

test_that("project_onto_pca drops columns absent in reference and warns", {
  m <- make_onehot()
  res <- run_pca(m, K = 3)

  query <- m[1:2, , drop = FALSE]
  query <- cbind(query, L4__C = c(1, 0))

  expect_warning(
    projected <- project_onto_pca(res, query),
    "L4__C"
  )
  expect_equal(dim(projected), c(2L, 3L))
})

# ---- Cycle 5: align_query_to_reference — column alignment (#19) -------------

test_that("align_query_to_reference drops query-only columns and keeps reference columns", {
  ref <- make_onehot()
  query <- ref[1:2, 1:4, drop = FALSE]
  query <- cbind(query, extra__X = c(1, 0))

  aligned <- align_query_to_reference(query, ref)

  expect_equal(colnames(aligned), colnames(ref))
  expect_false("extra__X" %in% colnames(aligned))
})

test_that("align_query_to_reference imputes reference-only columns with reference column means", {
  ref <- make_onehot()
  query <- ref[1:2, 1:4, drop = FALSE]

  aligned <- align_query_to_reference(query, ref)

  missing_cols <- setdiff(colnames(ref), colnames(query))
  ref_means <- colMeans(ref)
  for (col in missing_cols) {
    expect_true(all(aligned[, col] == ref_means[[col]]))
  }
})

test_that("align_query_to_reference preserves shared column values unchanged", {
  ref <- make_onehot()
  query <- ref[1:2, 1:4, drop = FALSE]

  aligned <- align_query_to_reference(query, ref)

  expect_equal(unname(aligned[, colnames(query)]), unname(query))
})
