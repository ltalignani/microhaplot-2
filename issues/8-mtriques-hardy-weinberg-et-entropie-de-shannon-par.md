# #8 — Métriques Hardy-Weinberg et entropie de Shannon par locus

## What to build

Add Hardy-Weinberg equilibrium frequency tables and Shannon entropy per locus to the summary visualisations.

End-to-end: after filtering, for each locus the app displays observed vs expected genotype frequencies under HWE, and an average Shannon entropy value used as a diversity index.

Key elements:
- `haplo_freq_tbl()`: compute observed diplotype frequencies and expected HWE frequencies from the filtered diplotype summary. Uses `pivot_longer()` (replaces deprecated `gather()`).
- Shannon entropy per locus: verify the exact formula used in the legacy `Update.ave.entropy()` against the microhaplotype literature before reimplementing.
- Display observed vs expected frequency table per locus (DT datatable).
- Display average entropy as a scalar annotation on the locus summary plot.

## Acceptance criteria

- [ ] Observed + expected HWE frequencies sum to 1.0 per locus
- [ ] Shannon entropy value matches manual calculation on the `sebastes` dataset
- [ ] No `gather()` or `spread()` calls remain (replaced by `pivot_longer()` / `pivot_wider()`)
- [ ] Entropy formula is documented with a literature reference in the code

## Blocked by

- Issue #6
