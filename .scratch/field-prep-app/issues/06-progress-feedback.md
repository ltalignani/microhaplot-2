Type: grilling
Status: resolved

## Question

`prepHaplotFiles()` runs a background bash script via a blocking `system()`
call, with no incremental progress reported back to R while it runs. For
thousands of BAM files this could take a long time with no visible
feedback. Should this map decide a progress mechanism, or is a static
"processing..." spinner enough for now?

## Answer

A real progress bar, based on polling: each processed SAM/BAM file
produces exactly one `.summary` file in `prepHaplotFiles()`'s `intermed/`
directory as it completes. The app can poll that directory's file count at
a regular interval and use it as a progress indicator — no change needed
to `prepHaplotFiles()` itself.

Note: this only reports progress; it does not by itself solve UI
responsiveness while the blocking `system()` call runs — see
[async execution architecture](12-async-execution-architecture.md), which
this depends on to actually be visible while extraction runs.
