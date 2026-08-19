extract_bin_available <- {
  bin <- find_microhaplot_extract_bin()
  !is.na(bin) && nzchar(bin) && file.exists(bin)
}

setup_sebastes_bam <- function() {
  work_dir <- withr::local_tempdir(.local_envir = parent.frame())
  utils::untar(
    system.file("extdata", "sebastes_bam.tar.gz", package = "microhaplot"),
    exdir = work_dir
  )
  work_dir
}

test_that("check_bam_integrity_rust() errors clearly when the binary can't be found", {
  expect_error(
    check_bam_integrity_rust(
      "/no/such.bam",
      bin.path = file.path(withr::local_tempdir(), "no-such-binary")
    ),
    "microhaplot-extract binary not found"
  )
})

test_that("check_bam_integrity_rust() passes a known-good BAM and lists its @SQ names", {
  skip_if_not(extract_bin_available, "microhaplot-extract binary not built")
  bin <- find_microhaplot_extract_bin()
  work_dir <- setup_sebastes_bam()

  res <- check_bam_integrity_rust(file.path(work_dir, "s11.bam"), bin.path = bin)

  expect_length(res$errors, 0)
  expect_true(length(res$bam_refs) > 0)
  expect_true("tag_id_2301" %in% res$bam_refs)
})

test_that("check_bam_integrity_rust() reports a truncated BAM as an error", {
  skip_if_not(extract_bin_available, "microhaplot-extract binary not built")
  bin <- find_microhaplot_extract_bin()
  work_dir <- setup_sebastes_bam()

  bam_path <- file.path(work_dir, "s11.bam")
  raw <- readBin(bam_path, "raw", n = file.size(bam_path))
  writeBin(raw[seq_len(200)], bam_path)

  res <- check_bam_integrity_rust(bam_path, bin.path = bin)

  expect_length(res$errors, 1)
  expect_true(grepl("s11.bam", res$errors))
  expect_true(grepl("truncat|corrupt", res$errors, ignore.case = TRUE))
  expect_length(res$bam_refs, 0)
})

test_that("check_bam_integrity_rust() unions @SQ names across multiple intact BAMs", {
  skip_if_not(extract_bin_available, "microhaplot-extract binary not built")
  bin <- find_microhaplot_extract_bin()
  work_dir <- setup_sebastes_bam()

  res <- check_bam_integrity_rust(
    file.path(work_dir, c("s11.bam", "s13.bam")),
    bin.path = bin
  )

  expect_length(res$errors, 0)
  expect_true(length(res$bam_refs) > 0)
})

test_that("check_bam_integrity_rust() agrees with samtools on the same fixtures", {
  skip_if_not(extract_bin_available, "microhaplot-extract binary not built")
  skip_if_not(nzchar(Sys.which("samtools")), "samtools not available")
  bin <- find_microhaplot_extract_bin()
  work_dir <- setup_sebastes_bam()
  bam_path <- file.path(work_dir, "s11.bam")

  rust_res <- check_bam_integrity_rust(bam_path, bin.path = bin)

  quickcheck_status <- system2("samtools", c("quickcheck", shQuote(bam_path)))
  header <- system2("samtools", c("view", "-H", shQuote(bam_path)), stdout = TRUE)
  sq_lines <- grep("^@SQ", header, value = TRUE)
  sn_fields <- vapply(
    strsplit(sq_lines, "\t"),
    function(f) sub("^SN:", "", f[startsWith(f, "SN:")][1]),
    character(1)
  )

  expect_equal(quickcheck_status, 0L)
  expect_length(rust_res$errors, 0)
  expect_equal(sort(rust_res$bam_refs), sort(sn_fields))
})
