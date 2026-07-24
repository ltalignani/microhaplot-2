Type: prototype
Status: resolved

## Question

Design a UI wireframe for the full flow: folder picker (mechanism decided
in [folder-picker mechanism](11-folder-picker-mechanism.md)) → TSV/VCF
upload → upfront batch validation results (including chromosome-mismatch
reporting per
[chromosome-comparison mechanism](14-chromosome-comparison-mechanism.md))
→ extraction with a live progress bar (reflecting the async architecture
decided in [async execution architecture](12-async-execution-architecture.md))
→ success message with next-step info. English UI, no run history, no
`n.jobs` control exposed — per the decisions already recorded on the map.
Use `/prototype` to raise the fidelity of this discussion with the user
before it's considered resolved.

## Answer

**Variant A — linear, step-gated wizard.** Three structurally different
variants were built as a throwaway runnable Shiny app (folder → files →
validate → extract → done, one step visible at a time; vs. a single-scroll
page with everything visible upfront; vs. a persistent sidebar with a
contextual main pane) and reviewed interactively. The wizard won: lowest
per-screen cognitive load, judged the better fit for a non-technical,
one-shot field task where the user shouldn't have to judge what to look at
next.

Reference implementation kept (not production code, not wired to the real
backend) at
[.scratch/field-prep-app/prototype/app.R](prototype/app.R) — a 5-step
wizard (Select folder → Upload files → Validate → Extract → Done) with a
step indicator, forward/back navigation, and a faked progress bar, for
whoever implements the real app to start from structurally.
