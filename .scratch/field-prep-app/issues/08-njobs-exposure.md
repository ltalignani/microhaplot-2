Type: grilling
Status: resolved

## Question

Should `prepHaplotFiles()`'s `n.jobs` (parallel thread count) be exposed
as a user-adjustable setting, or hidden with an automatic default?

## Answer

Hidden, auto-detected via `parallel::detectCores()` (with a safety margin,
e.g. cores − 1). A non-bioinformatician technician has no basis to judge
the right value; exposing it would just add a confusing setting.
