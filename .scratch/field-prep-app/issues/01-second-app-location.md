Type: grilling
Status: resolved

## Question

Should this new field-prep app live in the same repo as microhaplot v1
(a second Shiny app under `inst/shiny/`), or in a separate repo?

## Answer

Same repo as v1 (`ltalignani/microhaplot-2`), as a second Shiny app
installed via the same R package. This lets it call the already-tested
`prepHaplotFiles()` directly instead of duplicating extraction logic, and
keeps a single install step for the field user.
