Type: research
Status: resolved

## Question

Confirm `hierfstat` and `pcadapt` are safe additions to v1's `Imports`
given v1 targets CRAN submission (CRAN badge in README, `cran-comments.md`
present in the repo). Check: are both currently on CRAN (not
archived/orphaned), what are their licenses (compatible with v1's GPL-3),
do they have any system-level dependencies (compiled code, external
libraries) that could complicate a CRAN check, and do their current CRAN
versions match or exceed what microhaplot2 pinned (`hierfstat`, `pcadapt`
in `/Users/loictalignani/research/project/microhaplot-2/DESCRIPTION`)?
Report findings as a short summary.

## Answer

Both are safe additions to `Imports`.

- **hierfstat** — on CRAN, actively maintained (last updated May 2026),
  version 0.5-11, license `GPL (>= 2)` (compatible with v1's GPL-3),
  `NeedsCompilation: no` (pure R). Its own transitive Imports are
  `ade4`, `adegenet`, `gaston`, `gtools`, `methods` — all on CRAN;
  `gaston` has compiled code but that's routine for a CRAN-hosted
  transitive dependency, not a submission blocker.
- **pcadapt** — on CRAN, actively maintained (last updated May 2026),
  license `GPL (>= 2) | GPL-3` (compatible), `NeedsCompilation: yes`
  (uses Rcpp/`LinkingTo: mmapcharr, Rcpp, rmio`). CRAN provides
  prebuilt binaries for the major platforms, so this doesn't burden
  end users; it's a normal transitive-compiled-dependency situation,
  not unusual among CRAN packages.
- microhaplot2's `DESCRIPTION` pins neither package to a specific
  version (bare `hierfstat`, `pcadapt`); locally installed versions
  are hierfstat 0.5.11 and pcadapt 4.4.1, both current. No version
  floor is needed beyond what CRAN currently serves.

No CRAN-readiness concerns found for adding both as hard `Imports`.
