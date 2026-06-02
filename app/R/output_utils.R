library(dplyr)
library(tidyr)

# Build a download filename: "<run_label>_<type>.csv" (spaces → underscores).
make_filename <- function(run_label, type) {
  label <- gsub(" ", "_", run_label)
  paste0(label, "_", type, ".csv")
}

# Select columns from df. Returns df unchanged when fields is NULL or empty.
select_fields <- function(df, fields) {
  if (is.null(fields) || length(fields) == 0L) return(df)
  df[, fields, drop = FALSE]
}

# Pivot filtered haplo_data (one row per id+locus+rank) into diploid wide format.
# rank 1 → haplotype.1 / read.depth.1
# rank 2 → haplotype.2 / read.depth.2 / ar (allele.balance of rank 2)
# Missing rank 2 → NA for haplotype.2, read.depth.2, ar.
pivot_diploid <- function(filtered_data) {
  r1 <- filtered_data[filtered_data$rank == 1L, ]
  r2 <- filtered_data[filtered_data$rank == 2L, ]

  result <- r1[, c("group", "id", "locus"), drop = FALSE]
  result$haplotype.1  <- r1$haplo
  result$read.depth.1 <- r1$depth

  idx2 <- match(paste(r1$id, r1$locus), paste(r2$id, r2$locus))
  result$haplotype.2  <- r2$haplo[idx2]
  result$read.depth.2 <- r2$depth[idx2]
  result$ar           <- r2$allele.balance[idx2]

  rownames(result) <- NULL
  result
}
