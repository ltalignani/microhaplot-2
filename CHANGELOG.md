# Changelog

All notable changes to this project are documented here, in the style of
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/). This file targets
a general, GitHub-browsing audience; R users installing the package see the
same history rendered from [`NEWS.md`](NEWS.md) (e.g. via `news(package =
"microhaplot")` or the pkgdown site's "Changelog" tab).

## [2.1.0] (unreleased)

### Removed

- **Perl and `samtools` are gone entirely.** `hapture.pl`, the fatpacked
  `hapture` binary, its bundled Perl dependency tree, and the `perl`/
  `samtools` system dependencies are all removed from the Dockerfile,
  the R package, and the install instructions. Nothing to install beyond
  the package itself (or nothing at all, under Docker).

### Changed

- **`prepHaplotFiles()` and the field prep wizard's BAM validation now run
  on `microhaplot-extract`, a companion binary written in Rust**, instead
  of shelling out to `hapture.pl` and `samtools`. This is the headline
  change in this release: a full cutover, not an optional fast path — see
  [ticket #36](https://github.com/ltalignani/microhaplot-2/issues/36) for
  the acceptance criteria and real-world validation that gated it.
  - **Extraction only accepts BAM input now.** Convert SAM files to BAM
    first (e.g. `samtools view -b`) — `prepHaplotFiles()`'s SAM/BAM-mixing
    support is gone along with the Perl pipeline that implemented it.
  - **Performance**: on a real, production-scale amplicon panel (9 real
    samples, a ~36,000-variant VCF across 190 contigs — not the bundled
    toy fixture), the Rust pipeline ran **roughly 12-13x faster** than the
    Perl pipeline it replaced, with byte-for-byte identical output. See
    [`research/microhaplot-extract-benchmark.md`](research/microhaplot-extract-benchmark.md)
    for the full methodology, hardware, and reproduction steps.
  - Everything else about `prepHaplotFiles()`'s public interface
    (arguments, return value, `.rds` output) is unchanged.
- The Rust crate's own version now travels in lockstep with the R
  package's `DESCRIPTION` version, and `prepHaplotFiles()`/the field prep
  wizard verify it against the resolved `microhaplot-extract` binary at
  runtime, failing clearly on a mismatch instead of a confusing downstream
  error.

## [2.0.1]

### Fixed

- **Population Genetics reported wrong statistics on real panels,
  silently.** hierfstat takes a diploid genotype as one integer with both
  alleles packed into it, and infers a single allele width for the whole
  matrix from its largest value. `encode_hierfstat()` numbered every
  haplotype ever seen at a locus, including the long tail of low-rank
  sequencing noise, although only ranks 1 and 2 can enter a genotype. On a
  190-locus amplicon panel that gave 134 loci with more than 99 alleles
  and encoded values reaching 300935, so every genotype was split at the
  wrong digit boundary. Only called alleles are numbered now, and more
  than 99 at a locus raises an error instead of overflowing.

### Changed

- **The raw data source is gone from Population Genetics.** It was the
  default, and on unfiltered data an individual's two top-ranked
  haplotypes differ by construction — observed heterozygosity came out at
  1 almost everywhere and Fis around -0.4. The four tabs now always use
  called genotypes and state the criteria that produce them.
- F-statistics and allelic diversity share one computation instead of
  each recomputing it.

## [2.0.0]

First release under the microhaplot 2 name. The version jumps from 1.0.x
because this is no longer a patch series on the original package: it adds
whole capabilities and a second application, and the 1.0.x numbering
suggested otherwise.

### Added

- **Population Genetics** module, with four views: F-statistics (per-locus
  Ho/He/Fis/Fst/Fit, pairwise Fst, BetaS), rarefied allelic diversity, PCA
  / Projection, and an outlier scan built on `pcadapt`. Each offers a
  choice between raw and filtered genotypes, and exports to CSV.
- **Field Genotyping Prep** app (`runShinyHaplotPrep()`), a five-step
  wizard around `prepHaplotFiles()` for people who would rather not use
  the R console. It validates everything up front — BAM presence and
  integrity, metadata schema, VCF/BAM chromosome agreement — and reports
  every problem at once rather than stopping at the first.
- **BAM input** for `prepHaplotFiles()`. BAM and SAM files could be mixed
  freely in one label file; BAMs were streamed through `samtools` rather
  than converted on disk, and needed no `.bai` index. Gzipped VCFs are
  accepted the same way. (BAM-only, natively decoded, since 2.1.0 above.)
- **Docker distribution.** One image serves both apps, orchestrated by
  `docker-compose.yml`, published multi-arch (amd64 and arm64) to
  `ghcr.io/ltalignani/microhaplot-2`. No R, Perl or samtools installation
  is required, and BAM input works on Windows this way, which it does not
  natively. `MICROHAPLOT_INPUT_DIR` mounts a folder of alignments from
  anywhere on the host, read-only.
- **Documentation.** A vignette covering extraction under Docker end to
  end, a Population Genetics section in the walkthrough, and a
  documentation site built and published by CI.

### Fixed

- The main viewer attached the `tidyverse` meta-package, which is not a
  declared dependency and is therefore missing from any clean
  installation. Every session died on startup and the Data Set dropdown
  stayed empty.
- The Docker entrypoint installed the Shiny app into the shared volume
  only on first start, so pulling a newer image left existing users
  running the app version that first created their data folder.
- The prep wizard's progress bar never reached the browser: the
  extraction promise was created in the same Shiny flush cycle as the
  screen meant to report on it, so that screen was withheld until the
  work had finished.
- Uploads were capped at Shiny's 5 MB default, which rejects any
  realistic VCF. The ceiling is now 2 GB, and `MICROHAPLOT_MAX_UPLOAD_MB`
  raises it further.

## [1.0.0]

- Added a new parameter for `prepHaplotFiles`: `n.jobs`. For any
  non-Windows OS, you can specify the number of SAM files to process in
  parallel. We recommend two times the number of processors/cores.
- Introduced 3 main functions: `prepHaplotFiles`, `runShinyHaplot`,
  `mvShinyHaplot`.

[2.1.0]: https://github.com/ltalignani/microhaplot-2/compare/v2.0.1...master
[2.0.1]: https://github.com/ltalignani/microhaplot-2/compare/v2.0.0...v2.0.1
[2.0.0]: https://github.com/ltalignani/microhaplot-2/compare/v1.0.0...v2.0.0
[1.0.0]: https://github.com/ltalignani/microhaplot-2/releases/tag/v1.0.0
