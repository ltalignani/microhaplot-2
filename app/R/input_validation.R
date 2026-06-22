REQUIRED_COLUMNS <- c("bam_file", "individual_id", "group")

# Return an empty data.frame with the required CSV metadata columns.
csv_template <- function() {
  data.frame(
    bam_file      = character(),
    individual_id = character(),
    group         = character(),
    stringsAsFactors = FALSE
  )
}

# Validate a metadata data.frame for required columns and unique individual IDs.
# Returns list(ok = logical, errors = character()).
validate_metadata_csv <- function(df) {
  errors <- character()

  missing_cols <- setdiff(REQUIRED_COLUMNS, names(df))
  if (length(missing_cols) > 0L) {
    errors <- c(errors, paste0(
      "Colonne(s) manquante(s) dans le CSV : ", paste(missing_cols, collapse = ", ")
    ))
  }

  if ("individual_id" %in% names(df)) {
    dups <- df$individual_id[duplicated(df$individual_id)]
    if (length(dups) > 0L) {
      errors <- c(errors, paste0(
        "individual_id en double : ", paste(unique(dups), collapse = ", ")
      ))
    }
  }

  list(ok = length(errors) == 0L, errors = errors)
}

# Check that all BAM files (and their .bai indexes) referenced in metadata exist
# in data_dir. Falls back to the MICROHAPLOT_DATA_DIR env var, then /data/lovelace.
# Returns list(ok = logical, errors = character()).
resolve_bam_paths <- function(metadata, data_dir = NULL) {
  if (is.null(data_dir)) {
    data_dir <- Sys.getenv("MICROHAPLOT_DATA_DIR", unset = "/data/lovelace")
  }

  errors <- character()

  for (bam_file in metadata$bam_file) {
    bam_path  <- file.path(data_dir, bam_file)
    bai_path1 <- paste0(bam_path, ".bai")
    bai_path2 <- sub("\\.bam$", ".bai", bam_path, ignore.case = TRUE)

    if (!file.exists(bam_path)) {
      errors <- c(errors, paste0("Fichier BAM introuvable : ", bam_file))
    } else if (!file.exists(bai_path1) && !file.exists(bai_path2)) {
      errors <- c(errors, paste0(
        "Index BAI manquant pour : ", bam_file,
        " — créez-le avec : samtools index ", bam_file
      ))
    }
  }

  list(ok = length(errors) == 0L, errors = errors)
}
