HEX_COLOR_RE <- "^#[0-9A-Fa-f]{6}$"

#' Validate inputs for the field genotyping prep app
#'
#' Runs the upfront batch validation described in the field-prep-app spec:
#' TSV schema rules, BAM existence, BAM integrity (\code{microhaplot-extract
#' validate}, since the cutover in wayfinder ticket #36), and VCF/BAM
#' chromosome-name agreement. Pure function, no Shiny dependency.
#'
#' @param folder string. Path to the directory containing the BAM files. Required.
#' @param tsv data.frame. Parsed metadata TSV with columns \code{bam_file},
#'   \code{individual_id}, \code{group}, \code{color}. Required.
#' @param vcf_path string. Path to the VCF file. Required.
#' @return A list with elements \code{ok} (logical), \code{errors}
#'   (character vector of blocking problems), \code{warnings} (character
#'   vector of non-blocking notices), and \code{passes} (character vector
#'   of human-readable confirmations).
#' @export
validate_prep_inputs <- function(folder, tsv, vcf_path) {
  errors <- character()
  warnings <- character()
  passes <- character()

  schema <- .validate_tsv_schema(tsv)
  errors <- c(errors, schema$errors)

  if (length(schema$errors) == 0) {
    bam_files <- tsv$bam_file
    bam_paths <- file.path(folder, bam_files)
    missing <- bam_files[!file.exists(bam_paths)]

    if (length(missing) > 0) {
      errors <- c(errors, sprintf(
        "%d of %d BAM file(s) referenced in the metadata were not found in the selected folder: %s",
        length(missing), length(bam_files), paste(missing, collapse = ", ")
      ))
    } else {
      passes <- c(passes, sprintf(
        "%d of %d BAM files referenced in the metadata were found", length(bam_files), length(bam_files)
      ))
    }

    existing_paths <- bam_paths[file.exists(bam_paths)]

    if (length(existing_paths) > 0) {
      bin <- tryCatch(resolve_microhaplot_extract_bin(), error = function(e) NA_character_)
      if (is.na(bin)) {
        errors <- c(errors, "microhaplot-extract binary not found; it is required to validate BAM files.")
      } else {
        # One pass over the BAM files: microhaplot-extract validate checks
        # each for truncation, and (only for files that pass) collects its
        # @SQ reference names in the same call — no separate second pass
        # over the file list.
        integrity <- check_bam_integrity_rust(existing_paths, bin.path = bin)
        errors <- c(errors, integrity$errors)
        if (length(integrity$errors) == 0) {
          passes <- c(passes, "No truncated BAM files detected (microhaplot-extract validate)")
        }

        n_intact <- length(existing_paths) - length(integrity$errors)
        chrom <- .compare_chromosomes(vcf_path, integrity$bam_refs, n_intact)
        errors <- c(errors, chrom$errors)
        if (length(chrom$errors) == 0 && length(integrity$bam_refs) > 0) {
          passes <- c(passes, "VCF chromosome names match the BAM reference names")
        }
      }
    }
  }

  list(
    ok = length(errors) == 0,
    errors = errors,
    warnings = warnings,
    passes = passes
  )
}

# Required non-empty bam_file/individual_id, unique individual_id,
# group optionally empty/"NA", color optionally empty or #RRGGBB.
.validate_tsv_schema <- function(tsv) {
  errors <- character()

  if (any(is.na(tsv$bam_file) | tsv$bam_file == "")) {
    errors <- c(errors, "'bam_file' must not be empty for any row.")
  }
  if (any(is.na(tsv$individual_id) | tsv$individual_id == "")) {
    errors <- c(errors, "'individual_id' must not be empty for any row.")
  }
  dupes <- unique(tsv$individual_id[duplicated(tsv$individual_id)])
  if (length(dupes) > 0) {
    errors <- c(errors, sprintf(
      "'individual_id' must be unique; duplicate value(s): %s", paste(dupes, collapse = ", ")
    ))
  }
  if ("color" %in% names(tsv)) {
    bad_color <- tsv$color[!is.na(tsv$color) & tsv$color != "" & !grepl(HEX_COLOR_RE, tsv$color)]
    if (length(bad_color) > 0) {
      errors <- c(errors, sprintf(
        "'color' must be empty or a valid hex value (#RRGGBB); invalid value(s): %s",
        paste(unique(bad_color), collapse = ", ")
      ))
    }
  }

  list(errors = errors)
}

# Pure comparison, no file I/O: which VCF CHROM values are absent from the
# union of BAM reference names already collected by check_bam_integrity_rust()
# (R/run_microhaplot_extract.R).
.compare_chromosomes <- function(vcf_path, bam_refs, n_bam_files) {
  vcf_chroms <- unique(as.character(utils::read.table(vcf_path, stringsAsFactors = FALSE)[[1]]))
  missing_chroms <- setdiff(vcf_chroms, bam_refs)

  errors <- character()
  if (length(missing_chroms) > 0) {
    errors <- c(errors, sprintf(
      "%d VCF chromosome(s) not found in any of the %d BAM file(s)' reference sequences (wrong reference/panel?): %s",
      length(missing_chroms), n_bam_files, paste(missing_chroms, collapse = ", ")
    ))
  }
  list(errors = errors)
}
