Type: grilling
Status: open

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
