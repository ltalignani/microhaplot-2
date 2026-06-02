# #9 — Placeholder 'Analyse inférentielle' (module en développement)

## What to build

Add an 'Analyse inférentielle' tab as a visible placeholder signalling that Bayesian haplotype phasing is planned for a future version. No MCMC computation is implemented in this slice.

End-to-end: the user sees an 'Analyse inférentielle' tab in the navigation. Clicking it shows a clearly styled 'Fonctionnalité en développement' message with a brief description of what the feature will do (Gibbs sampler for diploid haplotype phasing).

Key elements:
- `inferentialModule`: a Shiny module rendering a `bslib` card with an informational banner.
- Message content (in French): description of the planned Bayesian phasing approach and an invitation to contact the development team.
- Remove all legacy MCMC reactive values (`srhapPg`, `gibbIter`, `fracBurn`, `randomSeed`, `selectPrior`, `Run.SrMicrohap()`) — this dead code is not carried forward.

## Acceptance criteria

- [ ] 'Analyse inférentielle' tab is visible in the app navigation
- [ ] Tab content shows a styled 'en développement' banner with descriptive text
- [ ] No legacy MCMC reactive values or functions remain in the codebase
- [ ] `R/runMicroHap.R` and `R/microhaplot.R` MCMC code removed or clearly flagged as out-of-scope

## Blocked by

- Issue #2
