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

# The full-fixture golden-comparison test (sebastes BAM set vs.
# tests/testthat/fixtures/hapture-golden/sebastes-all.summary) lives in
# test-prep-extraction-integration.R instead of here -- that's the file
# wayfinder ticket #35 wires into CI as the independent regression oracle,
# so it's the one canonical copy of this specific assertion rather than a
# duplicate maintained in two places.
