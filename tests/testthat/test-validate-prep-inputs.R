samtools_available <- nzchar(Sys.which("samtools"))

setup_bam_fixture <- function(samples = c("s6", "s11", "s13"), drop_locus_from_sizes = NULL) {
  sam.dir <- withr::local_tempdir(.local_envir = parent.frame())
  utils::untar(
    system.file("extdata", "sebastes_sam.tar.gz", package = "microhaplot"),
    exdir = sam.dir
  )

  loci <- character(0)
  for (s in samples) {
    lines <- readLines(file.path(sam.dir, paste0(s, ".sam")))
    rnames <- vapply(strsplit(lines, "\t"), `[`, character(1), 3)
    loci <- union(loci, rnames)
  }
  if (!is.null(drop_locus_from_sizes)) loci <- setdiff(loci, drop_locus_from_sizes)
  sizes.path <- file.path(sam.dir, "ref_sizes.txt")
  writeLines(paste(loci, 1000000, sep = "\t"), sizes.path)

  for (s in samples) {
    system2("samtools", c(
      "view", "-bt", sizes.path, "-o",
      file.path(sam.dir, paste0(s, ".bam")),
      file.path(sam.dir, paste0(s, ".sam"))
    ))
  }

  list(dir = sam.dir, vcf = file.path(sam.dir, "sebastes.vcf"), samples = samples)
}

make_tsv <- function(samples, bam_files = paste0(samples, ".bam")) {
  data.frame(
    bam_file = bam_files,
    individual_id = samples,
    group = "g1",
    color = "",
    stringsAsFactors = FALSE
  )
}

test_that("happy path: valid inputs pass with no errors", {
  skip_if_not(samtools_available, "samtools not available")
  fx <- setup_bam_fixture()
  res <- validate_prep_inputs(fx$dir, make_tsv(fx$samples), fx$vcf)

  expect_true(res$ok)
  expect_length(res$errors, 0)
  expect_gt(length(res$passes), 0)
})

test_that("a gzipped VCF passes validation the same as the plain VCF", {
  skip_if_not(samtools_available, "samtools not available")
  skip_if_not(nzchar(Sys.which("gunzip")), "gunzip not available")
  fx <- setup_bam_fixture()
  vcf_gz <- paste0(fx$vcf, ".gz")
  system2("gzip", c("-k", fx$vcf))

  res <- validate_prep_inputs(fx$dir, make_tsv(fx$samples), vcf_gz)

  expect_true(res$ok)
  expect_length(res$errors, 0)
})

test_that("missing BAM file referenced in TSV is reported as an error", {
  skip_if_not(samtools_available, "samtools not available")
  fx <- setup_bam_fixture()
  tsv <- make_tsv(fx$samples)
  tsv$bam_file[1] <- "does_not_exist.bam"

  res <- validate_prep_inputs(fx$dir, tsv, fx$vcf)

  expect_false(res$ok)
  expect_true(any(grepl("does_not_exist.bam", res$errors)))
})

test_that("truncated BAM file is reported as an error", {
  skip_if_not(samtools_available, "samtools not available")
  fx <- setup_bam_fixture()
  bam_path <- file.path(fx$dir, "s6.bam")
  raw <- readBin(bam_path, "raw", n = file.size(bam_path))
  writeBin(raw[seq_len(200)], bam_path)

  res <- validate_prep_inputs(fx$dir, make_tsv(fx$samples), fx$vcf)

  expect_false(res$ok)
  expect_true(any(grepl("s6.bam", res$errors) & grepl("truncat|corrupt|quickcheck", res$errors, ignore.case = TRUE)))
})

test_that("VCF chromosome missing from BAM references is reported with affected BAM count", {
  skip_if_not(samtools_available, "samtools not available")
  fx <- setup_bam_fixture()
  # drop one real VCF locus from every BAM's reference set so it becomes a mismatch
  vcf_loci <- unique(read.table(fx$vcf, stringsAsFactors = FALSE)[[1]])
  fx2 <- setup_bam_fixture(drop_locus_from_sizes = vcf_loci[1])

  res <- validate_prep_inputs(fx2$dir, make_tsv(fx2$samples), fx2$vcf)

  expect_false(res$ok)
  expect_true(any(grepl(vcf_loci[1], res$errors, fixed = TRUE)))
})

test_that("TSV schema violations are reported: empty required fields, duplicate id, bad color", {
  fx_dir <- withr::local_tempdir()
  vcf_path <- file.path(fx_dir, "fake.vcf")
  writeLines("Loc_1\t10\tA\tC", vcf_path)

  tsv <- data.frame(
    bam_file = c("", "b.bam", "b.bam"),
    individual_id = c("id1", "id2", "id2"),
    group = c("g1", "g1", "g1"),
    color = c("", "not-a-color", ""),
    stringsAsFactors = FALSE
  )

  res <- validate_prep_inputs(fx_dir, tsv, vcf_path)

  expect_false(res$ok)
  expect_true(any(grepl("bam_file", res$errors, ignore.case = TRUE)))
  expect_true(any(grepl("individual_id", res$errors, ignore.case = TRUE) & grepl("unique|duplicate", res$errors, ignore.case = TRUE)))
  expect_true(any(grepl("color", res$errors, ignore.case = TRUE)))
})
