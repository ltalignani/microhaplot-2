extract_bin_available <- {
  bin <- find_microhaplot_extract_bin()
  !is.na(bin) && nzchar(bin) && file.exists(bin)
}

test_that("prepHaplotFiles() matches the golden fixtures (sebastes BAM)", {
  skip_if_not(extract_bin_available, "microhaplot-extract binary not built")

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

  out_dir <- withr::local_tempdir()
  # prepHaplotFiles() only needs app.path to already exist -- the Shiny app
  # content mvShinyHaplot() would normally copy there is irrelevant to its
  # own extraction/post-processing logic, and mvShinyHaplot() itself needs
  # the package registered via system.file(), which this lightweight
  # harness deliberately avoids (see the comment above).
  app_dir <- withr::local_tempdir()

  # The real public entry point (wayfinder ticket #36's cutover): no
  # Perl, no samtools -- prepHaplotFiles() calls microhaplot-extract
  # directly via run_microhaplot_extract().
  result <- prepHaplotFiles(
    run.label = "sebastes_integration",
    sam.path = work_dir,
    label.path = label_path,
    vcf.path = file.path(work_dir, "sebastes.vcf"),
    out.path = out_dir,
    app.path = app_dir,
    n.jobs = 4
  )

  raw_cols <- c("group", "id", "locus", "haplo", "depth",
                "sum.Phred.C", "max.Phred.C")

  expect_s3_class(result, "tbl_df")
  expect_true(all(raw_cols %in% names(result)))
  expect_equal(length(unique(result$id)), 20)

  # The independent oracle this test exists for: hapture.pl's own recorded
  # output (tests/testthat/fixtures/hapture-golden/, captured in ticket
  # #19), canonicalized (sorted) the same way capture-golden-fixtures.sh
  # does -- not a round-trip check against whatever this run just wrote to
  # disk (see that fixture directory's own README.md for why row order
  # isn't part of the pinned behavior). Only the raw extraction columns are
  # compared -- allele.balance/rank are prepHaplotFiles()'s own downstream
  # dplyr post-processing, unchanged by this ticket and not part of the
  # golden fixture's own schema.
  actual_lines <- sort(do.call(
    paste, c(lapply(result[raw_cols], as.character), sep = "\t")
  ))
  golden_path <- testthat::test_path(
    "fixtures", "hapture-golden", "sebastes-all.summary"
  )
  expected_lines <- sort(readLines(golden_path))

  expect_equal(actual_lines, expected_lines)

  # One completion marker per sample, alongside the combined output --
  # the shape the field prep wizard's file-counting progress poller
  # expects (inst/shiny/microhaplot-prep/server.R), unchanged by this test.
  intermed_dir <- file.path(out_dir, "intermed")
  markers <- list.files(intermed_dir, pattern = "\\.summary$")
  markers <- setdiff(markers, "all.summary")
  expect_equal(length(markers), 20)
})
