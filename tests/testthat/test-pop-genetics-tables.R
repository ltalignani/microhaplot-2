library(testthat)

make_two_group_data <- function() {
  ids_a <- paste0("a", 1:5)
  ids_b <- paste0("b", 1:5)
  data.frame(
    group = c(rep("popA", 10), rep("popB", 10)),
    id    = c(rep(ids_a, each = 2), rep(ids_b, each = 2)),
    locus = rep(c("L1", "L2"), times = 10),
    haplo = c(
      "AC", "TT", "AC", "TT", "GT", "TT", "GT", "TT", "AC", "GG",
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

make_fstats <- function() {
  d <- make_two_group_data()
  enc <- encode_hierfstat(d)
  compute_fstats(enc, make_groups_vector(d))
}

test_that("fstats_perloc_table has locus, Ho, He, Fis, Fst, Fit and a Global row", {
  tbl <- fstats_perloc_table(make_fstats())

  expect_equal(names(tbl), c("locus", "Ho", "He", "Fis", "Fst", "Fit"))
  expect_true(all(c("L1", "L2", "Global") %in% tbl$locus))
  expect_equal(nrow(tbl), 3L)
})

test_that("pairwise_fst_long is long-format with NA on matching group pairs", {
  df <- pairwise_fst_long(make_fstats())

  expect_equal(names(df), c("group1", "group2", "fst"))
  expect_equal(nrow(df), 4L) # 2 groups x 2 groups
  same_group <- df[df$group1 == df$group2, ]
  expect_true(all(is.na(same_group$fst)))
  diff_group <- df[df$group1 != df$group2, ]
  expect_true(all(!is.na(diff_group$fst)))
})

test_that("betas_table has locus, betaW and a Global row", {
  tbl <- betas_table(make_fstats())

  expect_equal(names(tbl), c("locus", "betaW"))
  expect_true(all(c("L1", "L2", "Global") %in% tbl$locus))
  expect_equal(nrow(tbl), 3L)
})

test_that("allelic_richness_table is long-format with locus, group, richness", {
  df <- allelic_richness_table(make_fstats())

  expect_equal(names(df), c("locus", "group", "richness"))
  expect_equal(nrow(df), 4L) # 2 loci x 2 groups
  expect_true(all(c("popA", "popB") %in% df$group))
  expect_true(all(c("L1", "L2") %in% df$locus))
})
