Type: grilling
Status: resolved

## Question

Should `hierfstat` and `pcadapt` be added as hard dependencies (`Imports`),
or as optional dependencies (`Suggests`, with a runtime check and clear
error message if missing) — given v1 targets CRAN submission (CRAN badge
in README)?

## Answer

`Imports`. Both packages are on CRAN and actively maintained; consistent
with the precedent set by `shinyFiles`/`future`/`promises` for the
field-prep-app effort. A `Suggests`-based runtime-check pattern would add
complexity for a tab that structurally needs both to function once
enabled — see
[hierfstat/pcadapt CRAN-readiness check](04-dependency-cran-readiness.md)
for confirming this doesn't create a CRAN-submission problem.
