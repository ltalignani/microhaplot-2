#' Run microhaplot-extract over a batch of samples
#'
#' Internal wrapper around the \code{microhaplot-extract} binary (wayfinder
#' ticket #30): one invocation processes every sample listed in
#' \code{label.path} against \code{vcf.path}, in parallel, and returns the
#' combined output in the same shape \code{prepHaplotFiles()}'s existing
#' post-concatenation code expects. Not yet wired into
#' \code{prepHaplotFiles()} -- callable and testable on its own.
#'
#' @param label.path string. Path to the 3-column, headerless label file
#'   (see \code{build_prep_label_file()}). Required.
#' @param sam.path string. Directory containing the alignment (BAM) files
#'   named in the label file's first column. Required.
#' @param vcf.path string. Path to the VCF file. Required.
#' @param out.path string. Directory to write \code{all.summary} and the
#'   per-sample completion markers into (typically an \code{intermed/}
#'   directory). Created if it doesn't already exist. Required.
#' @param n.jobs positive integer. Number of samples to process
#'   concurrently. Default 1.
#' @param bin.path string. Optional. Explicit path to the
#'   \code{microhaplot-extract} binary, bypassing auto-detection.
#' @return A tibble with columns \code{group}, \code{id}, \code{locus},
#'   \code{haplo}, \code{depth}, \code{sum.Phred.C}, \code{max.Phred.C} --
#'   the same schema \code{prepHaplotFiles()} reads from today's
#'   Perl-produced \code{all.summary}.
#' @keywords internal
#' @noRd
run_microhaplot_extract <- function(label.path, sam.path, vcf.path, out.path,
                                     n.jobs = 1, bin.path = NULL) {
  bin <- resolve_bin_or_stop(bin.path)

  if (!file.exists(label.path)) {
    stop("the path for 'label.path' - ", label.path, " does not exist")
  }
  if (!file.exists(sam.path)) {
    stop("the path for 'sam.path' - ", sam.path, " does not exist")
  }
  if (!file.exists(vcf.path)) {
    stop("the path for 'vcf.path' - ", vcf.path, " does not exist")
  }
  if (!dir.exists(out.path)) dir.create(out.path, recursive = TRUE)

  if (!is.numeric(n.jobs)) {
    stop("the n.jobs specified is expected to be numeric")
  }
  n.jobs <- round(n.jobs)
  if (n.jobs <= 0) stop("the n.jobs is expected to be positive integer")

  # A non-zero exit is an expected, explicitly-handled outcome here (checked
  # right below), not a warning-worthy surprise -- suppresses system2()'s own
  # "had status N" warning so callers only see the stop() this function
  # raises with the binary's actual message.
  result <- withCallingHandlers(
    system2(
      bin,
      args = c(
        "extract",
        "--label-file", shQuote(label.path),
        "--sample-dir", shQuote(sam.path),
        "--vcf", shQuote(vcf.path),
        "--output-dir", shQuote(out.path),
        "--threads", as.character(n.jobs)
      ),
      stdout = TRUE, stderr = TRUE
    ),
    warning = function(w) invokeRestart("muffleWarning")
  )

  status <- attr(result, "status")
  if (!is.null(status) && status != 0) {
    stop(
      "microhaplot-extract failed (exit status ", status, "):\n",
      paste(result, collapse = "\n")
    )
  }

  summary.path <- file.path(out.path, "all.summary")
  if (!file.exists(summary.path)) {
    stop("microhaplot-extract did not produce the expected output at ", summary.path)
  }

  col_names <- c("group", "id", "locus", "haplo", "depth", "sum.Phred.C", "max.Phred.C")

  if (file.info(summary.path)$size == 0) {
    empty <- stats::setNames(
      data.frame(matrix(ncol = length(col_names), nrow = 0)), col_names
    )
    return(dplyr::as_tibble(empty))
  }

  haplo.sum <- utils::read.table(summary.path, sep = "\t", stringsAsFactors = FALSE) %>%
    dplyr::as_tibble()
  colnames(haplo.sum) <- col_names
  haplo.sum
}

#' Validate BAM files via microhaplot-extract's validate subcommand
#'
#' Internal wrapper (wayfinder ticket #31) around \code{microhaplot-extract
#' validate}, which replaces the field prep wizard's \code{samtools
#' quickcheck} + \code{samtools view -H} shell-outs with one call per file
#' to the already-built binary. Returns results in the same shape
#' \code{.check_bam_integrity()} (\code{R/prep_validation.R}) already
#' produces looping over multiple paths with two \code{samtools} calls per
#' file, so swapping the implementation later is a small, localized change.
#' Not yet wired into \code{prep_validation.R} -- callable and testable on
#' its own.
#'
#' @param bam.paths character vector. Paths to the BAM files to check. Required.
#' @param bin.path string. Optional. Explicit path to the
#'   \code{microhaplot-extract} binary, bypassing auto-detection.
#' @return A list with elements \code{errors} (character vector, one
#'   message per truncated/corrupted file, naming the file) and
#'   \code{bam_refs} (character vector, the union of \code{@SQ} reference
#'   names across every file that passed).
#' @keywords internal
#' @noRd
check_bam_integrity_rust <- function(bam.paths, bin.path = NULL) {
  bin <- resolve_bin_or_stop(bin.path)

  errors <- character()
  bam_refs <- character()

  for (path in bam.paths) {
    result <- withCallingHandlers(
      system2(
        bin, args = c("validate", "--bam", shQuote(path)),
        stdout = TRUE, stderr = TRUE
      ),
      warning = function(w) invokeRestart("muffleWarning")
    )

    status <- attr(result, "status")
    if (!is.null(status) && status != 0) {
      errors <- c(errors, sprintf(
        "%s appears truncated or corrupted (microhaplot-extract validate failed).",
        basename(path)
      ))
    } else {
      bam_refs <- union(bam_refs, result)
    }
  }

  list(errors = errors, bam_refs = bam_refs)
}
