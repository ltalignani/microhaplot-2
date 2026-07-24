Type: grilling
Status: resolved

## Question

`prepHaplotFiles()` currently runs its extraction via a blocking `system()`
call from within the calling R process. If called directly from a Shiny
reactive, this would freeze the entire app — including the progress bar
from [progress feedback](06-progress-feedback.md), which needs to keep
polling `intermed/*.summary` while extraction runs.

How should this app invoke `prepHaplotFiles()` (or the underlying
extraction) so the UI stays responsive and the progress bar can actually
update during a long-running extraction? Consider options such as the
`future`/`promises` packages, `callr`, or running the extraction as a
genuinely separate background process polled from the main Shiny session,
and decide which fits this app (bearing in mind it must stay simple enough
for a non-bioinformatician's local machine, no server infrastructure).

## Answer

Wrap the entire `prepHaplotFiles()` call in a `future` (`future`/`promises`
packages, `future::plan(multisession)`), treating it as an opaque
long-running call — no changes needed inside `prepHaplotFiles()` itself.
This runs it in a background R worker process on the same machine (no
server infrastructure), while the main Shiny session stays free to poll
`intermed/*.summary` for the progress bar (filesystem polling is
independent of whichever process is blocked on `system()`). This is the
pattern documented by RStudio/Posit for long-running Shiny tasks, and
integrates cleanly with Shiny's reactive model via `promises::then()`,
unlike a lower-level `callr`-based approach which would need more manual
polling wiring.

Cancellation and extraction-failure error UX remain open — see the map's
"Not yet specified".
