samtools_available <- nzchar(Sys.which("samtools"))

setup_sam_bam_fixture <- function(samples = c("s6", "s11", "s13")) {
  sam.dir <- withr::local_tempdir(.local_envir = parent.frame())
  utils::untar(
    system.file("extdata", "sebastes_sam.tar.gz", package = "microhaplot"),
    exdir = sam.dir
  )

  # The bundled SAM fixtures have no header (no @SQ lines), which hapture.pl
  # doesn't need but `samtools view -bS` does to build a valid BAM. Supply
  # reference lengths out-of-band via `-t` instead of fabricating a header.
  loci <- character(0)
  for (s in samples) {
    lines <- readLines(file.path(sam.dir, paste0(s, ".sam")))
    rnames <- vapply(strsplit(lines, "\t"), `[`, character(1), 3)
    loci <- union(loci, rnames)
  }
  sizes.path <- file.path(sam.dir, "ref_sizes.txt")
  writeLines(paste(loci, 1000000, sep = "\t"), sizes.path)

  for (s in samples) {
    sam.file <- file.path(sam.dir, paste0(s, ".sam"))
    bam.file <- file.path(sam.dir, paste0(s, ".bam"))
    system2("samtools", c("view", "-bt", sizes.path, "-o", bam.file, sam.file))
  }

  full.label <- read.table(file.path(sam.dir, "label.txt"), sep = "\t", stringsAsFactors = FALSE)
  sub.label <- full.label[full.label$V2 %in% samples, ]

  sam.label <- sub.label
  sam.label$V1 <- paste0(sam.label$V2, ".sam")
  bam.label <- sub.label
  bam.label$V1 <- paste0(bam.label$V2, ".bam")

  sam.label.path <- file.path(sam.dir, "label_sam_subset.txt")
  bam.label.path <- file.path(sam.dir, "label_bam_subset.txt")
  write.table(sam.label, sam.label.path, sep = "\t", row.names = FALSE, col.names = FALSE, quote = FALSE)
  write.table(bam.label, bam.label.path, sep = "\t", row.names = FALSE, col.names = FALSE, quote = FALSE)

  app.dir <- withr::local_tempdir(.local_envir = parent.frame())
  mvShinyHaplot(app.dir)

  list(
    sam.dir = sam.dir,
    vcf.path = file.path(sam.dir, "sebastes.vcf"),
    sam.label.path = sam.label.path,
    bam.label.path = bam.label.path,
    app.path = file.path(app.dir, "microhaplot")
  )
}

sort_haplo_tbl <- function(tbl) {
  tbl[order(tbl$id, tbl$locus, tbl$haplo), ]
}

test_that("prepHaplotFiles produces identical output for BAM and SAM input", {
  skip_if_not(samtools_available, "samtools not available")

  fx <- setup_sam_bam_fixture()

  res.sam <- prepHaplotFiles(
    run.label = "sam_run",
    sam.path = fx$sam.dir,
    label.path = fx$sam.label.path,
    vcf.path = fx$vcf.path,
    out.path = withr::local_tempdir(),
    app.path = fx$app.path
  )

  res.bam <- prepHaplotFiles(
    run.label = "bam_run",
    sam.path = fx$sam.dir,
    label.path = fx$bam.label.path,
    vcf.path = fx$vcf.path,
    out.path = withr::local_tempdir(),
    app.path = fx$app.path
  )

  # "rank" is derived by breaking ties among equal-depth haplotypes in
  # whatever order the intermediate .summary files happened to be
  # concatenated in (not a stable sort), so it isn't guaranteed identical
  # across two otherwise-equivalent runs even from the same SAM input twice.
  # depth/allele.balance already carry the full, order-independent signal.
  cols <- c("group", "id", "locus", "haplo", "depth",
            "sum.Phred.C", "max.Phred.C", "allele.balance")
  expect_equal(
    sort_haplo_tbl(as.data.frame(res.sam[, cols])),
    sort_haplo_tbl(as.data.frame(res.bam[, cols])),
    ignore_attr = TRUE
  )
})

test_that("prepHaplotFiles handles a label file mixing SAM and BAM rows", {
  skip_if_not(samtools_available, "samtools not available")

  fx <- setup_sam_bam_fixture()

  sam.label <- read.table(fx$sam.label.path, sep = "\t", stringsAsFactors = FALSE)
  bam.label <- read.table(fx$bam.label.path, sep = "\t", stringsAsFactors = FALSE)
  mixed.label <- rbind(sam.label[1, , drop = FALSE], bam.label[-1, , drop = FALSE])
  mixed.label.path <- file.path(fx$sam.dir, "label_mixed.txt")
  write.table(mixed.label, mixed.label.path, sep = "\t", row.names = FALSE, col.names = FALSE, quote = FALSE)

  res.mixed <- prepHaplotFiles(
    run.label = "mixed_run",
    sam.path = fx$sam.dir,
    label.path = mixed.label.path,
    vcf.path = fx$vcf.path,
    out.path = withr::local_tempdir(),
    app.path = fx$app.path
  )

  expect_setequal(unique(res.mixed$id), unique(mixed.label$V2))
  expect_gt(nrow(res.mixed), 0)
})

test_that("prepHaplotFiles errors clearly when BAM rows are present but samtools is missing", {
  fx <- setup_sam_bam_fixture(samples = "s6")

  withr::with_envvar(c(PATH = dirname(Sys.which("perl"))), {
    expect_error(
      prepHaplotFiles(
        run.label = "no_samtools_run",
        sam.path = fx$sam.dir,
        label.path = fx$bam.label.path,
        vcf.path = fx$vcf.path,
        out.path = withr::local_tempdir(),
        app.path = fx$app.path
      ),
      regexp = "samtools"
    )
  })
})
