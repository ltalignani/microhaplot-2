library(ggplot2)
library(dplyr)

# Per-locus bubble chart data: for each locus, distribution of unique-haplotype
# counts across individuals. Returns columns: locus, tot_hapl, ct, frac.
haplo_density_tbl <- function(haplo_data) {
  per_indiv <- haplo_data |>
    dplyr::group_by(locus, id) |>
    dplyr::summarise(tot_hapl = dplyr::n(), tot_depth = sum(depth),
                     .groups = "drop")

  per_indiv |>
    dplyr::group_by(locus, tot_hapl) |>
    dplyr::summarise(ct = dplyr::n(), .groups = "drop") |>
    dplyr::group_by(locus) |>
    dplyr::mutate(frac = ct / sum(ct)) |>
    dplyr::ungroup() |>
    as.data.frame()
}

# Number of unique haplotypes per locus across all individuals.
# Returns columns: locus, n_uniq_haplo.
uniq_haplo_per_locus <- function(haplo_data) {
  haplo_data |>
    dplyr::group_by(locus) |>
    dplyr::summarise(n_uniq_haplo = dplyr::n_distinct(haplo), .groups = "drop") |>
    as.data.frame()
}

# Fraction of individuals with callable haplotype at each locus.
# n_indiv: total number of individuals (denominator).
# Returns columns: locus, n_callable, frac.
frac_callable_by_locus <- function(haplo_data, n_indiv) {
  haplo_data |>
    dplyr::group_by(locus) |>
    dplyr::summarise(n_callable = dplyr::n_distinct(id), .groups = "drop") |>
    dplyr::mutate(frac = n_callable / n_indiv) |>
    as.data.frame()
}

# Total read depth per individual per locus (for violin plot).
# Returns columns: locus, id, group, tot_depth.
read_depth_by_locus <- function(haplo_data) {
  haplo_data |>
    dplyr::group_by(locus, id, group) |>
    dplyr::summarise(tot_depth = sum(depth), .groups = "drop") |>
    as.data.frame()
}

# Allele balance values per read per individual (for scatter plot).
# min_ar: minimum allele balance ratio to keep (default 0 = keep all).
# Returns columns: id, group, locus, allele.balance, depth.
allele_balance_by_indiv <- function(haplo_data, min_ar = 0) {
  haplo_data |>
    dplyr::filter(allele.balance >= min_ar) |>
    dplyr::select(id, group, locus, allele.balance, depth) |>
    as.data.frame()
}

# Haplotype count distribution per individual.
# For each individual: how many loci have 1 haplo, 2 haplos, etc.
# Returns columns: id, n_hap_locus, n_locus.
haplo_counts_by_indiv <- function(haplo_data) {
  haplo_data |>
    dplyr::group_by(id, locus) |>
    dplyr::summarise(n_hap_locus = dplyr::n(), .groups = "drop") |>
    dplyr::group_by(id, n_hap_locus) |>
    dplyr::summarise(n_locus = dplyr::n(), .groups = "drop") |>
    as.data.frame()
}

# Fraction of callable loci per individual.
# n_loci: total number of loci (denominator).
# Returns columns: id, group, n_callable_loci, frac_callable.
frac_callable_by_indiv <- function(haplo_data, n_loci) {
  grp <- haplo_data |>
    dplyr::select(id, group) |>
    dplyr::distinct()

  haplo_data |>
    dplyr::group_by(id) |>
    dplyr::summarise(n_callable_loci = dplyr::n_distinct(locus), .groups = "drop") |>
    dplyr::left_join(grp, by = "id") |>
    dplyr::mutate(frac_callable = n_callable_loci / n_loci) |>
    dplyr::select(id, group, n_callable_loci, frac_callable) |>
    as.data.frame()
}

# ---- Plot functions ----------------------------------------------------------
# All plots use guide = "none" (not deprecated guide = FALSE).
# element_rect uses linewidth= (not deprecated size=).

# Bubble plot: haplotype density per locus (by-locus panel, plot 1).
plot_haplo_density <- function(density_tbl, loci_subset = NULL) {
  tbl <- density_tbl
  if (!is.null(loci_subset)) tbl <- tbl[tbl$locus %in% loci_subset, ]
  max_haplo <- if (nrow(tbl) > 0L) max(tbl$tot_hapl) else 1L

  ggplot2::ggplot(tbl, ggplot2::aes(x = tot_hapl, y = locus,
                                    size = frac, colour = frac)) +
    ggplot2::geom_point() +
    ggplot2::xlab("num of uniq. haplotypes\n(per indiv)") +
    ggplot2::ylab("Locus ID") +
    ggplot2::scale_colour_continuous(guide = "none") +
    ggplot2::scale_size_continuous(guide = "none") +
    ggplot2::scale_x_continuous(limits = c(0, max_haplo + 1),
                                breaks = round(seq(1, max_haplo, length.out = 4))) +
    ggplot2::theme_bw() +
    ggplot2::theme(
      panel.spacing  = ggplot2::unit(0, "mm"),
      panel.border   = ggplot2::element_rect(linewidth = 0, colour = "white"),
      axis.line.y    = ggplot2::element_line(colour = "grey", linewidth = 0.5),
      plot.margin    = ggplot2::unit(c(0, 3, 0, 0), "mm")
    )
}

# Dot plot: number of unique haplotypes per locus (by-locus panel, plot 2).
plot_uniq_haplo_per_locus <- function(uniq_tbl, loci_subset = NULL) {
  tbl <- uniq_tbl
  if (!is.null(loci_subset)) tbl <- tbl[tbl$locus %in% loci_subset, ]
  max_haplo <- if (nrow(tbl) > 0L) max(tbl$n_uniq_haplo) else 1L

  ggplot2::ggplot(tbl, ggplot2::aes(x = n_uniq_haplo, y = locus)) +
    ggplot2::geom_point() +
    ggplot2::xlab("num of unique haplotypes\n(total indiv)") +
    ggplot2::ylab("") +
    ggplot2::scale_size_continuous(guide = "none") +
    ggplot2::scale_x_continuous(limits = c(0, max_haplo + 1),
                                breaks = round(seq(1, max_haplo, length.out = 4))) +
    ggplot2::theme_bw() +
    ggplot2::theme(
      axis.text.y   = ggplot2::element_blank(),
      axis.ticks.y  = ggplot2::element_blank(),
      panel.spacing = ggplot2::unit(0, "mm"),
      panel.border  = ggplot2::element_rect(linewidth = 0, colour = "white"),
      plot.margin   = ggplot2::unit(c(0, 2, 0, 0), "mm")
    )
}

# Dot plot: fraction of individuals with callable haplotype per locus
# (by-locus panel, plot 3).
plot_frac_callable_indiv <- function(frac_tbl, loci_subset = NULL) {
  tbl <- frac_tbl
  if (!is.null(loci_subset)) tbl <- tbl[tbl$locus %in% loci_subset, ]
  tbl$label_x <- ifelse(tbl$frac > 0.5, tbl$frac - 0.3, tbl$frac + 0.3)

  ggplot2::ggplot(tbl, ggplot2::aes(x = frac, y = locus, colour = frac)) +
    ggplot2::geom_point() +
    ggplot2::geom_text(ggplot2::aes(x = label_x, label = round(frac, 2)),
                       colour = "black") +
    ggplot2::xlab("fraction of indiv with\ncalleable haplotype") +
    ggplot2::ylab("") +
    ggplot2::scale_colour_continuous(guide = "none") +
    ggplot2::scale_x_continuous(limits = c(0, 1), breaks = seq(0, 1, 0.2)) +
    ggplot2::theme_bw() +
    ggplot2::theme(
      axis.text.y   = ggplot2::element_blank(),
      axis.ticks.y  = ggplot2::element_blank(),
      panel.spacing = ggplot2::unit(0, "mm"),
      panel.border  = ggplot2::element_rect(linewidth = 0, colour = "white"),
      plot.margin   = ggplot2::unit(c(0, 3, 0, 0), "mm")
    )
}

# Violin + mean point: read depth per locus (by-locus panel, plot 4).
plot_read_depth_violin <- function(depth_tbl, loci_subset = NULL) {
  tbl <- depth_tbl
  if (!is.null(loci_subset)) tbl <- tbl[tbl$locus %in% loci_subset, ]
  tbl <- tbl |>
    dplyr::group_by(locus) |>
    dplyr::mutate(mean_depth = mean(tot_depth)) |>
    dplyr::ungroup()

  g <- ggplot2::ggplot(tbl, ggplot2::aes(x = locus, y = tot_depth)) +
    ggplot2::xlab("") +
    ggplot2::ylab("tot read depth\n(per indiv)")

  if (nrow(tbl) > 5L) g <- g + ggplot2::geom_violin(na.rm = TRUE)

  g +
    ggplot2::geom_point(ggplot2::aes(y = mean_depth), cex = 3, pch = 3) +
    ggplot2::scale_y_log10() +
    ggplot2::coord_flip() +
    ggplot2::theme_bw() +
    ggplot2::theme(
      axis.text.y   = ggplot2::element_blank(),
      axis.ticks.y  = ggplot2::element_blank(),
      panel.spacing = ggplot2::unit(0, "mm"),
      panel.border  = ggplot2::element_rect(linewidth = 0, colour = "white"),
      plot.margin   = ggplot2::unit(c(0, 0, 0, 0), "mm")
    )
}

# Scatter: allele balance ratio per individual (by-individual panel, plot 1).
plot_allele_balance_by_indiv <- function(ab_tbl, indiv_subset = NULL,
                                         min_ar = 0.5) {
  tbl <- ab_tbl
  if (!is.null(indiv_subset)) tbl <- tbl[tbl$id %in% indiv_subset, ]

  ggplot2::ggplot(tbl, ggplot2::aes(x = allele.balance, y = id,
                                    colour = group,
                                    size   = log(depth + 1, 10))) +
    ggplot2::geom_point(alpha = 0.4) +
    ggplot2::scale_size_continuous(guide = "none") +
    ggplot2::scale_colour_discrete(guide = "none") +
    ggplot2::geom_vline(xintercept = min_ar, linetype = "dashed",
                        colour = "red") +
    ggplot2::xlim(c(0, 1)) +
    ggplot2::xlab("allelic balance\nratio") +
    ggplot2::ylab("Individual ID") +
    ggplot2::theme_bw() +
    ggplot2::theme(
      panel.spacing  = ggplot2::unit(0, "mm"),
      panel.border   = ggplot2::element_rect(linewidth = 0, colour = "white"),
      axis.line.y    = ggplot2::element_line(colour = "grey", linewidth = 0.5),
      plot.margin    = ggplot2::unit(c(0, 2, 0, 0), "mm"),
      axis.title.x   = ggplot2::element_text(size = 16),
      axis.title.y   = ggplot2::element_text(size = 20)
    )
}

# Bubble plot: num haplotypes per locus per individual (by-individual panel, plot 2).
plot_uniq_haplo_by_indiv <- function(hc_tbl, indiv_subset = NULL) {
  tbl <- hc_tbl
  if (!is.null(indiv_subset)) tbl <- tbl[tbl$id %in% indiv_subset, ]
  max_locus <- if (nrow(tbl) > 0L) max(tbl$n_hap_locus) else 1L

  ggplot2::ggplot(tbl, ggplot2::aes(x = n_hap_locus, y = id,
                                    size = n_locus)) +
    ggplot2::geom_point() +
    ggplot2::xlab("num of haplotype\n(per locus)") +
    ggplot2::ylab("") +
    ggplot2::scale_size_continuous(guide = "none") +
    ggplot2::scale_x_continuous(limits = c(0, max_locus + 1),
                                breaks = round(seq(1, max_locus, length.out = 4))) +
    ggplot2::theme_bw() +
    ggplot2::theme(
      axis.text.y   = ggplot2::element_blank(),
      axis.ticks.y  = ggplot2::element_blank(),
      panel.spacing = ggplot2::unit(0, "mm"),
      panel.border  = ggplot2::element_rect(linewidth = 0, colour = "white"),
      plot.margin   = ggplot2::unit(c(0, 3, 0, 0), "mm"),
      axis.title.x  = ggplot2::element_text(size = 16)
    )
}

# Dot plot: fraction of callable loci per individual (by-individual panel, plot 3).
plot_frac_callable_loci_by_indiv <- function(frac_tbl, indiv_subset = NULL) {
  tbl <- frac_tbl
  if (!is.null(indiv_subset)) tbl <- tbl[tbl$id %in% indiv_subset, ]

  ggplot2::ggplot(tbl, ggplot2::aes(x = frac_callable, y = id,
                                    colour = group)) +
    ggplot2::geom_point() +
    ggplot2::scale_colour_discrete(guide = "none") +
    ggplot2::scale_x_continuous(limits = c(0, 1), breaks = seq(0, 1, 0.2)) +
    ggplot2::xlab("fraction of callable loci") +
    ggplot2::ylab("") +
    ggplot2::theme_bw() +
    ggplot2::theme(
      axis.text.y   = ggplot2::element_blank(),
      axis.ticks.y  = ggplot2::element_blank(),
      panel.spacing = ggplot2::unit(0, "mm"),
      panel.border  = ggplot2::element_rect(linewidth = 0, colour = "white"),
      plot.margin   = ggplot2::unit(c(0, 3, 0, 0), "mm")
    )
}
