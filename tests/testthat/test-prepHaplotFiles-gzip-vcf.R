test_that("prepHaplotFiles accepts a gzipped VCF and produces the same result as the plain VCF", {
  skip_if_not(nzchar(Sys.which("gunzip")), "gunzip not available")

  sam.dir <- withr::local_tempdir()
  utils::untar(
    system.file("extdata", "sebastes_sam.tar.gz", package = "microhaplot"),
    exdir = sam.dir
  )
  vcf.path <- file.path(sam.dir, "sebastes.vcf")
  vcf.gz.path <- paste0(vcf.path, ".gz")
  system2("gzip", c("-k", vcf.path))

  app.dir <- withr::local_tempdir()
  mvShinyHaplot(app.dir)
  app.path <- file.path(app.dir, "microhaplot")
  label.path <- file.path(sam.dir, "label.txt")

  res.plain <- prepHaplotFiles(
    run.label = "plain_vcf", sam.path = sam.dir, label.path = label.path,
    vcf.path = vcf.path, out.path = withr::local_tempdir(), app.path = app.path
  )
  res.gz <- prepHaplotFiles(
    run.label = "gz_vcf", sam.path = sam.dir, label.path = label.path,
    vcf.path = vcf.gz.path, out.path = withr::local_tempdir(), app.path = app.path
  )

  cols <- c("group", "id", "locus", "haplo", "depth", "sum.Phred.C", "max.Phred.C", "allele.balance")
  expect_equal(
    as.data.frame(res.plain[order(res.plain$id, res.plain$locus, res.plain$haplo), cols]),
    as.data.frame(res.gz[order(res.gz$id, res.gz$locus, res.gz$haplo), cols]),
    ignore_attr = TRUE
  )
})

