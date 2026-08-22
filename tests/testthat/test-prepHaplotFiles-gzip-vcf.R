test_that("prepHaplotFiles accepts a gzipped VCF and produces the same result as the plain VCF", {
  skip_if_not(nzchar(Sys.which("gunzip")), "gunzip not available")

  bam.dir <- withr::local_tempdir()
  utils::untar(
    system.file("extdata", "sebastes_bam.tar.gz", package = "microhaplot"),
    exdir = bam.dir
  )
  vcf.path <- file.path(bam.dir, "sebastes.vcf")
  vcf.gz.path <- paste0(vcf.path, ".gz")
  system2("gzip", c("-k", vcf.path))

  app.dir <- withr::local_tempdir()
  mvShinyHaplot(app.dir)
  app.path <- file.path(app.dir, "microhaplot")

  metadata <- utils::read.table(
    file.path(bam.dir, "sebastes_metadata.tsv"),
    header = TRUE, sep = "\t", stringsAsFactors = FALSE
  )
  label.path <- file.path(bam.dir, "label.txt")
  build_prep_label_file(metadata, label.path)

  res.plain <- prepHaplotFiles(
    run.label = "plain_vcf", sam.path = bam.dir, label.path = label.path,
    vcf.path = vcf.path, out.path = withr::local_tempdir(), app.path = app.path
  )
  res.gz <- prepHaplotFiles(
    run.label = "gz_vcf", sam.path = bam.dir, label.path = label.path,
    vcf.path = vcf.gz.path, out.path = withr::local_tempdir(), app.path = app.path
  )

  cols <- c("group", "id", "locus", "haplo", "depth", "sum.Phred.C", "max.Phred.C", "allele.balance")
  expect_equal(
    as.data.frame(res.plain[order(res.plain$id, res.plain$locus, res.plain$haplo), cols]),
    as.data.frame(res.gz[order(res.gz$id, res.gz$locus, res.gz$haplo), cols]),
    ignore_attr = TRUE
  )
})
