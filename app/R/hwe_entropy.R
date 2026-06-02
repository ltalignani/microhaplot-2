library(dplyr)
library(tidyr)
library(ggplot2)

# Shannon haplotype diversity index (bits) per locus.
# H = -sum(p_i * log2(p_i)) over diploid allele frequencies.
# Homozygous individuals (rank-1 only) contribute two copies of their allele;
# heterozygous contribute one copy each of rank-1 and rank-2.
# Reference: Shannon (1948) Bell System Tech. J.; used in microhaplotype
# literature as a per-locus allelic diversity metric (e.g. Kidd et al. 2014).
# Returns data.frame: locus, entropy.
shannon_entropy_per_locus <- function(haplo_data) {
  r1 <- haplo_data[haplo_data$rank == 1L, c("locus","id","haplo")]
  names(r1)[names(r1) == "haplo"] <- "hap1"

  r2 <- haplo_data[haplo_data$rank == 2L, c("locus","id","haplo")]
  names(r2)[names(r2) == "haplo"] <- "hap2"

  diploid <- merge(r1, r2, by = c("locus","id"), all.x = TRUE)
  diploid$hap2[is.na(diploid$hap2)] <- diploid$hap1[is.na(diploid$hap2)]

  diploid |>
    tidyr::pivot_longer(cols = c(hap1, hap2),
                        names_to  = "which",
                        values_to = "hap") |>
    dplyr::group_by(locus, hap) |>
    dplyr::summarise(n = dplyr::n(), .groups = "drop") |>
    dplyr::group_by(locus) |>
    dplyr::mutate(p = n / sum(n)) |>
    dplyr::summarise(entropy = -sum(p * log2(p)), .groups = "drop") |>
    as.data.frame()
}

# Observed and HWE-expected diplotype frequencies per locus.
# Uses pivot_longer() instead of deprecated gather().
# For each individual: rank-1 row = haplotype.1; rank-2 row = haplotype.2
# (homozygous individuals have no rank-2 row; treated as hap2 = hap1).
# Canonical form: haplotype.1 <= haplotype.2 (alphabetical).
# Returns data.frame: locus, haplotype.1, haplotype.2, obs.freq, expected.freq.
haplo_freq_tbl <- function(haplo_data) {
  r1 <- haplo_data[haplo_data$rank == 1L, c("locus","id","haplo")]
  names(r1)[names(r1) == "haplo"] <- "hap1"

  r2 <- haplo_data[haplo_data$rank == 2L, c("locus","id","haplo")]
  names(r2)[names(r2) == "haplo"] <- "hap2"

  diploid <- merge(r1, r2, by = c("locus","id"), all.x = TRUE)
  diploid$hap2[is.na(diploid$hap2)] <- diploid$hap1[is.na(diploid$hap2)]

  # Canonical ordering: haplotype.1 <= haplotype.2
  diploid$haplotype.1 <- pmin(diploid$hap1, diploid$hap2)
  diploid$haplotype.2 <- pmax(diploid$hap1, diploid$hap2)

  # Observed diplotype frequencies
  obs <- diploid |>
    dplyr::group_by(locus, haplotype.1, haplotype.2) |>
    dplyr::summarise(n_obs = dplyr::n(), .groups = "drop") |>
    dplyr::group_by(locus) |>
    dplyr::mutate(obs.freq = n_obs / sum(n_obs)) |>
    dplyr::select(-n_obs) |>
    dplyr::ungroup()

  # Allele frequencies from diploid pairs (count each allele in each diploid)
  allele_freq <- diploid |>
    tidyr::pivot_longer(cols = c(hap1, hap2),
                        names_to  = "which",
                        values_to = "hap") |>
    dplyr::group_by(locus, hap) |>
    dplyr::summarise(n = dplyr::n(), .groups = "drop") |>
    dplyr::group_by(locus) |>
    dplyr::mutate(p = n / sum(n)) |>
    dplyr::select(locus, hap, p) |>
    dplyr::ungroup()

  # Expected HWE frequencies for all canonical diplotype pairs
  # Filter hap1 <= hap2 to enumerate each unordered pair exactly once.
  expected <- allele_freq |>
    dplyr::rename(hap1 = hap, p1 = p) |>
    dplyr::inner_join(
      allele_freq |> dplyr::rename(hap2 = hap, p2 = p),
      by = "locus",
      relationship = "many-to-many"
    ) |>
    dplyr::filter(hap1 <= hap2) |>
    dplyr::mutate(
      haplotype.1   = hap1,
      haplotype.2   = hap2,
      expected.freq = ifelse(hap1 == hap2, p1 * p2, 2 * p1 * p2)
    ) |>
    dplyr::select(locus, haplotype.1, haplotype.2, expected.freq)

  # Full join: include all diplotypes (observed and/or expected under HWE)
  dplyr::full_join(obs, expected,
                   by = c("locus","haplotype.1","haplotype.2")) |>
    dplyr::mutate(obs.freq = ifelse(is.na(obs.freq), 0, obs.freq)) |>
    as.data.frame()
}

# Dot plot: Shannon entropy per locus (by-locus panel, 5th column).
# Returns a ggplot object.
plot_entropy_by_locus <- function(entropy_tbl, loci_subset = NULL) {
  tbl <- entropy_tbl
  if (!is.null(loci_subset)) tbl <- tbl[tbl$locus %in% loci_subset, ]

  ggplot2::ggplot(tbl, ggplot2::aes(x = entropy, y = locus)) +
    ggplot2::geom_point(colour = "steelblue") +
    ggplot2::geom_text(ggplot2::aes(label = round(entropy, 2)),
                       nudge_x = 0.05, size = 3, hjust = 0) +
    ggplot2::xlab("Shannon entropy (bits)") +
    ggplot2::ylab("") +
    ggplot2::scale_x_continuous(limits = c(0, NA), expand = ggplot2::expansion(mult = c(0, 0.2))) +
    ggplot2::theme_bw() +
    ggplot2::theme(
      axis.text.y   = ggplot2::element_blank(),
      axis.ticks.y  = ggplot2::element_blank(),
      panel.spacing = ggplot2::unit(0, "mm"),
      panel.border  = ggplot2::element_rect(linewidth = 0, colour = "white"),
      plot.margin   = ggplot2::unit(c(0, 3, 0, 0), "mm")
    )
}
