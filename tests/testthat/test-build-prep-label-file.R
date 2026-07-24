test_that("build_prep_label_file writes a headerless, tab-separated 3-column file in row order", {
  tsv <- data.frame(
    bam_file = c("s6.bam", "s11.bam", "s13.bam"),
    individual_id = c("s6", "s11", "s13"),
    group = c("gr", "cu", ""),
    color = c("#FF0000", "", ""),
    stringsAsFactors = FALSE
  )

  out_path <- withr::local_tempfile()
  build_prep_label_file(tsv, out_path)

  written <- read.table(out_path, sep = "\t", stringsAsFactors = FALSE)

  expect_equal(ncol(written), 3)
  expect_equal(written$V1, tsv$bam_file)
  expect_equal(written$V2, tsv$individual_id)
  expect_equal(written$V3, c("gr", "cu", ""))
})

test_that("build_prep_label_file preserves an empty group as an empty field, not NA text", {
  tsv <- data.frame(
    bam_file = "s6.bam", individual_id = "s6", group = "", color = "",
    stringsAsFactors = FALSE
  )
  out_path <- withr::local_tempfile()
  build_prep_label_file(tsv, out_path)

  lines <- readLines(out_path)
  expect_equal(lines, "s6.bam\ts6\t")
})
