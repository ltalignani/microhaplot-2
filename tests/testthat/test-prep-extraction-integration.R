extract_bin_available <- {
  bin <- find_microhaplot_extract_bin()
  !is.na(bin) && nzchar(bin) && file.exists(bin)
}

test_that("run_microhaplot_extract() matches the golden fixtures on the sebastes BAM set", {
  skip_if_not(extract_bin_available, "microhaplot-extract binary not built")
  bin <- find_microhaplot_extract_bin()

  # testthat::test_path(), not system.file(package = "microhaplot") --
  # this test also runs in CI (wayfinder ticket #35) via a lightweight
  # harness that sources these R files directly rather than installing the
  # package, so "microhaplot" isn't a registered package there. test_path()
  # resolves correctly regardless (relative to this file's own directory,
  # tests/testthat/, both under devtools::test() and a bare test_file()
  # call -- testthat::test_file() changes the working directory to the
  # test file's own directory for the duration of the run).
  work_dir <- withr::local_tempdir()
  utils::untar(
    testthat::test_path("..", "..", "inst", "extdata", "sebastes_bam.tar.gz"),
    exdir = work_dir
  )

  metadata <- utils::read.table(
    file.path(work_dir, "sebastes_metadata.tsv"),
    header = TRUE, sep = "\t", stringsAsFactors = FALSE
  )
  label_path <- file.path(work_dir, "label.txt")
  build_prep_label_file(metadata, label_path)

  out_dir <- file.path(work_dir, "intermed")

  # The R-side helper from ticket #30 -- not prepHaplotFiles(), which still
  # drives the Perl pipeline until the cutover ticket (#36) switches its
  # default path.
  result <- run_microhaplot_extract(
    label.path = label_path,
    sam.path = work_dir,
    vcf.path = file.path(work_dir, "sebastes.vcf"),
    out.path = out_dir,
    n.jobs = 4,
    bin.path = bin
  )

  expect_s3_class(result, "tbl_df")
  expect_named(
    result,
    c("group", "id", "locus", "haplo", "depth", "sum.Phred.C", "max.Phred.C")
  )
  expect_equal(length(unique(result$id)), 20)

  # The independent oracle this test exists for: hapture.pl's own recorded
  # output (tests/testthat/fixtures/hapture-golden/, captured in ticket
  # #19), canonicalized (sorted) the same way capture-golden-fixtures.sh
  # does -- not a round-trip check against whatever this run just wrote to
  # disk (see that fixture directory's own README.md for why row order
  # isn't part of the pinned behavior).
  actual_lines <- sort(do.call(paste, c(lapply(result, as.character), sep = "\t")))
  golden_path <- testthat::test_path("fixtures", "hapture-golden", "sebastes-all.summary")
  expected_lines <- sort(readLines(golden_path))

  expect_equal(actual_lines, expected_lines)

  # One completion marker per sample, alongside the combined output --
  # the shape the field prep wizard's file-counting progress poller
  # expects (inst/shiny/microhaplot-prep/server.R), unchanged by this test.
  markers <- list.files(out_dir, pattern = "\\.summary$")
  markers <- setdiff(markers, "all.summary")
  expect_equal(length(markers), 20)
})
