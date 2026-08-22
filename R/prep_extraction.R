#' Translate a validated metadata TSV into prepHaplotFiles()'s label file format
#'
#' \code{prepHaplotFiles()} expects a tab-separated, headerless label file
#' with 3 columns: alignment file name, individual ID, group. The field
#' prep app's user-facing TSV has a header row and a 4th (\code{color})
#' column that \code{prepHaplotFiles()} doesn't use — this writes the
#' internal format from the validated TSV, preserving row order.
#'
#' @param tsv data.frame. Validated metadata TSV with columns
#'   \code{bam_file}, \code{individual_id}, \code{group}. Required.
#' @param path string. Destination path for the generated label file. Required.
#' @return \code{path}, invisibly.
#' @export
build_prep_label_file <- function(tsv, path) {
  utils::write.table(
    tsv[, c("bam_file", "individual_id", "group")],
    file = path, sep = "\t", row.names = FALSE, col.names = FALSE, quote = FALSE
  )
  invisible(path)
}
