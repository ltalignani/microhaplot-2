extract_bin_available <- {
  bin <- find_microhaplot_extract_bin()
  !is.na(bin) && nzchar(bin) && file.exists(bin)
}

test_that("run_microhaplot_extract() errors clearly when the binary can't be found", {
  label_path <- withr::local_tempfile()
  writeLines("s6.bam\ts6\tgr", label_path)
  sam_dir <- withr::local_tempdir()
  vcf_path <- withr::local_tempfile()
  writeLines("#CHROM\tPOS\tID\tREF\tALT", vcf_path)
  out_dir <- withr::local_tempdir()

  expect_error(
    run_microhaplot_extract(
      label_path, sam_dir, vcf_path, out_dir,
      bin.path = file.path(withr::local_tempdir(), "no-such-binary")
    ),
    "microhaplot-extract binary not found"
  )
})

test_that("run_microhaplot_extract() validates its path arguments", {
  skip_if_not(extract_bin_available, "microhaplot-extract binary not built")
  bin <- find_microhaplot_extract_bin()

  expect_error(
    run_microhaplot_extract("/no/such/label.txt", ".", ".", withr::local_tempdir(), bin.path = bin),
    "label.path"
  )
})

test_that("run_microhaplot_extract() surfaces the binary's own error on bad input", {
  skip_if_not(extract_bin_available, "microhaplot-extract binary not built")
  bin <- find_microhaplot_extract_bin()

  # A label file naming a sample that doesn't exist in sam.path -- passes
  # every R-side path check (label.path/sam.path/vcf.path all exist), so
  # this exercises the real binary's own per-sample failure and non-zero
  # exit status, not just R's upfront argument validation.
  label_path <- withr::local_tempfile()
  writeLines("does-not-exist.bam\tghost\tgr", label_path)
  sam_dir <- withr::local_tempdir()
  vcf_path <- withr::local_tempfile()
  writeLines(
    c("#CHROM\tPOS\tID\tREF\tALT", "locusA\t1\t.\tA\tT"),
    vcf_path
  )
  out_dir <- withr::local_tempdir()

  expect_error(
    run_microhaplot_extract(label_path, sam_dir, vcf_path, out_dir, bin.path = bin),
    "ghost"
  )

  # A run that didn't fully succeed must not leave a combined output behind
  # that looks complete.
  expect_false(file.exists(file.path(out_dir, "all.summary")))
})

test_that("run_microhaplot_extract() matches the golden combined fixture on the sebastes BAM set", {
  skip_if_not(extract_bin_available, "microhaplot-extract binary not built")
  bin <- find_microhaplot_extract_bin()

  work_dir <- withr::local_tempdir()
  utils::untar(
    system.file("extdata", "sebastes_bam.tar.gz", package = "microhaplot"),
    exdir = work_dir
  )

  metadata <- utils::read.table(
    file.path(work_dir, "sebastes_metadata.tsv"),
    header = TRUE, sep = "\t", stringsAsFactors = FALSE
  )
  label_path <- file.path(work_dir, "label.txt")
  build_prep_label_file(metadata, label_path)

  out_dir <- file.path(work_dir, "intermed")

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
  expect_equal(nrow(result), 616)
  expect_equal(length(unique(result$id)), 20)

  # Canonicalize (sort) both sides the same way capture-golden-fixtures.sh
  # does, and compare as whole rows -- row order isn't part of the pinned
  # behavior (see tests/testthat/fixtures/hapture-golden/README.md).
  actual_lines <- sort(do.call(paste, c(lapply(result, as.character), sep = "\t")))

  golden_path <- testthat::test_path(
    "fixtures", "hapture-golden", "sebastes-all.summary"
  )
  expected_lines <- sort(readLines(golden_path))

  expect_equal(actual_lines, expected_lines)

  # One completion marker per sample, alongside the combined output.
  markers <- list.files(out_dir, pattern = "\\.summary$")
  markers <- setdiff(markers, "all.summary")
  expect_equal(length(markers), 20)
})
