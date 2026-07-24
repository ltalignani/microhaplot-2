test_that("the full TSV -> label file -> prepHaplotFiles() flow produces the expected .rds", {
  samtools_available <- nzchar(Sys.which("samtools"))
  skip_if_not(samtools_available, "samtools not available")

  sam.dir <- withr::local_tempdir()
  utils::untar(
    system.file("extdata", "sebastes_sam.tar.gz", package = "microhaplot"),
    exdir = sam.dir
  )
  samples <- c("s6", "s11", "s13")

  tsv <- data.frame(
    bam_file = paste0(samples, ".sam"),
    individual_id = samples,
    group = "g1",
    color = "",
    stringsAsFactors = FALSE
  )

  label_path <- withr::local_tempfile()
  build_prep_label_file(tsv, label_path)

  app.dir <- withr::local_tempdir()
  mvShinyHaplot(app.dir)
  app.path <- file.path(app.dir, "microhaplot")

  out.path <- withr::local_tempdir()
  run.label <- "prep_integration_test"

  res <- prepHaplotFiles(
    run.label = run.label,
    sam.path = sam.dir,
    label.path = label_path,
    vcf.path = file.path(sam.dir, "sebastes.vcf"),
    out.path = out.path,
    app.path = app.path,
    n.jobs = max(1, parallel::detectCores() - 1)
  )

  rds_path <- file.path(app.path, paste0(run.label, ".rds"))
  posinfo_path <- file.path(app.path, paste0(run.label, "_posinfo.rds"))

  expect_true(file.exists(rds_path))
  expect_true(file.exists(posinfo_path))
  expect_setequal(unique(res$id), samples)
  expect_equal(readRDS(rds_path), res)
})
