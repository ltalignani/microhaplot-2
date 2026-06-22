library(Rsamtools)
library(dplyr)

# Parse a VCF file and return a data.frame of SNP positions only.
# Reads in chunks to avoid loading multi-GB files entirely into RAM.
# Detects gzip by magic bytes — Shiny strips extensions from temp file paths.
parse_vcf_loci <- function(vcf_path) {
  magic <- tryCatch(readBin(vcf_path, what = "raw", n = 2L), error = function(e) raw(0))
  is_gz <- length(magic) >= 2L && magic[1L] == as.raw(0x1f) && magic[2L] == as.raw(0x8b)
  con   <- if (is_gz) gzcon(file(vcf_path, "rb")) else file(vcf_path, "r")
  on.exit(close(con))

  empty <- data.frame(locus = character(), pos = integer(),
                      ref = character(), alt = character(),
                      stringsAsFactors = FALSE)
  chunks    <- list()
  CHUNK     <- 50000L

  repeat {
    lines <- readLines(con, n = CHUNK, warn = FALSE)
    if (length(lines) == 0L) break

    data_lines <- lines[!startsWith(lines, "#")]
    if (length(data_lines) == 0L) next

    mat <- strsplit(data_lines, "\t", fixed = TRUE)
    mat <- mat[lengths(mat) >= 5L]
    if (length(mat) == 0L) next
    mat <- do.call(rbind, mat)

    ref  <- mat[, 4L]
    alt  <- sub(",.*", "", mat[, 5L])
    keep <- nchar(ref) == 1L & nchar(alt) == 1L
    if (!any(keep)) next

    chunks[[length(chunks) + 1L]] <- data.frame(
      locus = mat[keep, 1L],
      pos   = as.integer(mat[keep, 2L]),
      ref   = ref[keep],
      alt   = alt[keep],
      stringsAsFactors = FALSE
    )
  }

  if (length(chunks) == 0L) empty else do.call(rbind, chunks)
}

# Variant of extract_haplotypes that accepts pre-parsed VCF loci (data.frame)
# instead of a file path — avoids re-reading the VCF for every BAM.
extract_haplotypes_from_loci <- function(bam_dir, vcf_loci, metadata) {
  empty <- data.frame(
    group = character(), id = character(), locus = character(),
    haplo = character(), depth = integer(),
    allele.balance = numeric(), rank = integer(),
    stringsAsFactors = FALSE
  )
  if (is.null(vcf_loci) || nrow(vcf_loci) == 0L) return(empty)

  rows <- lapply(seq_len(nrow(metadata)), function(i) {
    bam_path <- file.path(bam_dir, metadata$bam_file[i])
    .extract_one_bam(bam_path, vcf_loci, id = metadata$id[i], group = metadata$group[i])
  })

  counts <- do.call(rbind, Filter(Negate(is.null), rows))
  if (is.null(counts) || nrow(counts) == 0L) return(empty)

  result <- add_allele_balance(counts)
  result <- result[, c("group", "id", "locus", "haplo", "depth", "allele.balance", "rank")]
  result$depth <- as.integer(result$depth)
  result$rank  <- as.integer(result$rank)
  result
}

# Map a single reference position to the 1-based query position for a read.
# Returns NA_integer_ for deletions (D/N ops), -1L if outside the aligned region.
.ref_to_query_pos <- function(aln_start, cigar_str, ref_pos) {
  ops <- regmatches(cigar_str, gregexpr("[0-9]+[MIDNSHPX=]", cigar_str))[[1L]]
  lengths <- as.integer(sub("[MIDNSHPX=]", "", ops))
  types   <- sub("[0-9]+", "", ops)

  target <- ref_pos - aln_start  # 0-based offset from alignment start
  if (target < 0L) return(-1L)

  ref_off   <- 0L
  query_off <- 0L

  for (i in seq_along(types)) {
    op  <- types[i]
    len <- lengths[i]

    if (op %in% c("M", "X", "=")) {
      if (ref_off + len > target) {
        local <- target - ref_off
        return(query_off + local + 1L)
      }
      ref_off   <- ref_off   + len
      query_off <- query_off + len
    } else if (op %in% c("D", "N")) {
      if (ref_off + len > target) return(NA_integer_)
      ref_off <- ref_off + len
    } else if (op == "I") {
      query_off <- query_off + len
    } else if (op == "S") {
      query_off <- query_off + len
    }
    # H and P consume neither
  }
  -1L  # past end of alignment
}

# Extract a haplotype string from a single read.
# Returns one character per ref_position: the base, "X" (deletion), or "N" (out of range).
extract_read_haplotype <- function(seq_str, aln_start, cigar, ref_positions) {
  bases <- strsplit(seq_str, "")[[1L]]
  result <- character(length(ref_positions))
  for (j in seq_along(ref_positions)) {
    qpos <- .ref_to_query_pos(aln_start, cigar, ref_positions[j])
    if (is.na(qpos)) {
      result[j] <- "X"
    } else if (qpos < 1L || qpos > length(bases)) {
      result[j] <- "N"
    } else {
      result[j] <- bases[qpos]
    }
  }
  paste(result, collapse = "")
}

# Add allele.balance and rank to a haplotype count table.
# Input data.frame must have columns: locus, id, haplo, depth.
add_allele_balance <- function(haplo_counts) {
  haplo_counts |>
    arrange(locus, id, desc(depth)) |>
    group_by(locus, id) |>
    mutate(
      allele.balance = depth / depth[1L],
      rank           = row_number()
    ) |>
    ungroup() |>
    as.data.frame()
}

# Extract haplotypes for all BAM files described in metadata.
#
# bam_dir  : directory containing BAM (and .bai) files
# vcf_path : path to VCF file
# metadata : data.frame with columns bam_file, id, group
#
# Returns a data.frame with columns:
#   group, id, locus, haplo, depth, allele.balance, rank
extract_haplotypes <- function(bam_dir, vcf_path, metadata) {
  empty <- data.frame(
    group = character(), id = character(), locus = character(),
    haplo = character(), depth = integer(),
    allele.balance = numeric(), rank = integer(),
    stringsAsFactors = FALSE
  )

  vcf_loci <- parse_vcf_loci(vcf_path)
  if (nrow(vcf_loci) == 0L) return(empty)

  rows <- lapply(seq_len(nrow(metadata)), function(i) {
    bam_path <- file.path(bam_dir, metadata$bam_file[i])
    ind_id   <- metadata$id[i]
    grp      <- metadata$group[i]
    .extract_one_bam(bam_path, vcf_loci, id = ind_id, group = grp)
  })

  counts <- do.call(rbind, rows)
  if (is.null(counts) || nrow(counts) == 0L) return(empty)

  result <- add_allele_balance(counts)
  result <- result[, c("group", "id", "locus", "haplo", "depth", "allele.balance", "rank")]
  result$depth <- as.integer(result$depth)
  result$rank  <- as.integer(result$rank)
  result
}

# Internal: extract haplotypes from a single BAM for one individual.
.extract_one_bam <- function(bam_path, vcf_loci, id, group) {
  locus_names <- unique(vcf_loci$locus)

  rows <- lapply(locus_names, function(loc) {
    snp_pos <- vcf_loci$pos[vcf_loci$locus == loc]

    # Fetch only reads overlapping this locus region
    region <- GRanges(loc, IRanges(min(snp_pos), max(snp_pos)))
    param  <- ScanBamParam(
      which = region,
      what  = c("pos", "cigar", "seq", "flag"),
      flag  = scanBamFlag(isSecondaryAlignment = FALSE, isSupplementaryAlignment = FALSE)
    )

    bam_list <- tryCatch(
      scanBam(bam_path, param = param)[[1L]],
      error = function(e) NULL
    )

    if (is.null(bam_list) || length(bam_list$pos) == 0L) return(NULL)

    # Filter out unmapped and secondary (flag >= 256)
    keep <- !is.na(bam_list$pos) &
            !is.na(bam_list$cigar) &
            (bam_list$flag < 256L) &
            bam_list$cigar != "*"
    if (!any(keep)) return(NULL)

    seqs   <- as.character(bam_list$seq[keep])
    cigars <- bam_list$cigar[keep]
    starts <- bam_list$pos[keep]

    haplos <- mapply(extract_read_haplotype,
                     seq_str       = seqs,
                     aln_start     = starts,
                     cigar         = cigars,
                     MoreArgs      = list(ref_positions = snp_pos),
                     SIMPLIFY      = TRUE)

    counts <- table(haplos)
    if (length(counts) == 0L) return(NULL)

    data.frame(
      group = group,
      id    = id,
      locus = loc,
      haplo = names(counts),
      depth = as.integer(counts),
      stringsAsFactors = FALSE
    )
  })

  do.call(rbind, Filter(Negate(is.null), rows))
}
